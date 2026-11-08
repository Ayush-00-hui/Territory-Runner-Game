package api_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/api"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/config"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestGetCurrentSeasonEndpoint(t *testing.T) {
	// 1. Unauthorized request with Firebase auth mode
	memStore := store.NewMemoryStore()
	cfg := &config.Config{AuthMode: "firebase", FirebaseProjectID: "test-project"}
	authenticator := auth.NewAuthenticator(cfg)
	apiHandler := api.NewAPI(memStore, nil, api.WithAuthenticator(authenticator))
	firebaseRouter := api.SetupRouter(apiHandler, authenticator)

	req := httptest.NewRequest(http.MethodGet, "/v1/seasons/current", nil)
	rec := httptest.NewRecorder()
	firebaseRouter.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusUnauthorized, rec.Code)

	// 2. Authorized request
	router, _ := setupTestServer()
	req = httptest.NewRequest(http.MethodGet, "/v1/seasons/current", nil)
	req.Header.Set("X-Dev-User", "runner_season_1")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	var resp store.CurrentSeasonResponse
	err := json.Unmarshal(rec.Body.Bytes(), &resp)
	require.NoError(t, err)

	assert.NotEmpty(t, resp.Season.ID)
	assert.NotEmpty(t, resp.Season.Name)
	assert.Greater(t, resp.TimeRemainingSeconds, int64(0))
	assert.NotNil(t, resp.FactionStandings)
}

func TestCrewsFlowAndConstraints(t *testing.T) {
	router, _ := setupTestServer()

	// 1. GET /v1/crews/my returns crew: null when runner has no crew
	req := httptest.NewRequest(http.MethodGet, "/v1/crews/my", nil)
	req.Header.Set("X-Dev-User", "runner_crew_solo")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	var myCrewResp store.MyCrewResponse
	err := json.Unmarshal(rec.Body.Bytes(), &myCrewResp)
	require.NoError(t, err)
	assert.Nil(t, myCrewResp.Crew)

	// 2. POST /v1/crews validation errors (reserved name, too short)
	badBody := bytes.NewBufferString(`{"name":"ad"}`)
	req = httptest.NewRequest(http.MethodPost, "/v1/crews", badBody)
	req.Header.Set("X-Dev-User", "runner_leader")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Contains(t, rec.Body.String(), "INVALID_CREW_NAME")

	reservedBody := bytes.NewBufferString(`{"name":"admin"}`)
	req = httptest.NewRequest(http.MethodPost, "/v1/crews", reservedBody)
	req.Header.Set("X-Dev-User", "runner_leader")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Contains(t, rec.Body.String(), "INVALID_CREW_NAME")

	// 3. POST /v1/crews successful creation
	createBody := bytes.NewBufferString(`{"name":"Trailblazers"}`)
	req = httptest.NewRequest(http.MethodPost, "/v1/crews", createBody)
	req.Header.Set("X-Dev-User", "runner_leader")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusCreated, rec.Code)
	var createdCrew store.Crew
	err = json.Unmarshal(rec.Body.Bytes(), &createdCrew)
	require.NoError(t, err)
	assert.Equal(t, "Trailblazers", createdCrew.Name)
	assert.Equal(t, "runner_leader", createdCrew.CreatorID)
	assert.True(t, len(createdCrew.JoinCode) >= 6)
	assert.Contains(t, createdCrew.JoinCode, "CRW-")

	// 4. Duplicate crew creation by same leader must fail
	dupBody := bytes.NewBufferString(`{"name":"Second Crew"}`)
	req = httptest.NewRequest(http.MethodPost, "/v1/crews", dupBody)
	req.Header.Set("X-Dev-User", "runner_leader")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Contains(t, rec.Body.String(), "USER_ALREADY_IN_CREW")

	// 5. GET /v1/crews/my for leader
	req = httptest.NewRequest(http.MethodGet, "/v1/crews/my", nil)
	req.Header.Set("X-Dev-User", "runner_leader")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	err = json.Unmarshal(rec.Body.Bytes(), &myCrewResp)
	require.NoError(t, err)
	require.NotNil(t, myCrewResp.Crew)
	assert.Equal(t, "leader", myCrewResp.Role)
	assert.Len(t, myCrewResp.Members, 1)
	assert.Equal(t, "runner_leader", myCrewResp.Members[0].UserID)

	// 6. POST /v1/crews/join with non-existent code
	joinBadBody := bytes.NewBufferString(`{"join_code":"CRW-XXXX"}`)
	req = httptest.NewRequest(http.MethodPost, "/v1/crews/join", joinBadBody)
	req.Header.Set("X-Dev-User", "runner_member_1")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusNotFound, rec.Code)
	assert.Contains(t, rec.Body.String(), "CREW_NOT_FOUND")

	// 7. POST /v1/crews/join with valid code
	joinValidBody := bytes.NewBufferString(fmt.Sprintf(`{"join_code":"%s"}`, createdCrew.JoinCode))
	req = httptest.NewRequest(http.MethodPost, "/v1/crews/join", joinValidBody)
	req.Header.Set("X-Dev-User", "runner_member_1")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)

	// 8. Re-joining or joining another crew must fail (1 crew per runner)
	req = httptest.NewRequest(http.MethodPost, "/v1/crews/join", bytes.NewBufferString(fmt.Sprintf(`{"join_code":"%s"}`, createdCrew.JoinCode)))
	req.Header.Set("X-Dev-User", "runner_member_1")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Contains(t, rec.Body.String(), "USER_ALREADY_IN_CREW")

	// 9. Enforce 10-runner cap: Add 8 more members (bringing total to 10)
	for i := 2; i <= 9; i++ {
		memberID := fmt.Sprintf("runner_member_%d", i)
		joinBody := bytes.NewBufferString(fmt.Sprintf(`{"join_code":"%s"}`, createdCrew.JoinCode))
		req = httptest.NewRequest(http.MethodPost, "/v1/crews/join", joinBody)
		req.Header.Set("X-Dev-User", memberID)
		rec = httptest.NewRecorder()
		router.ServeHTTP(rec, req)
		require.Equal(t, http.StatusOK, rec.Code, "Member %d join failed: %s", i, rec.Body.String())
	}

	// 10. 11th member must be rejected (CREW_FULL)
	req = httptest.NewRequest(http.MethodPost, "/v1/crews/join", bytes.NewBufferString(fmt.Sprintf(`{"join_code":"%s"}`, createdCrew.JoinCode)))
	req.Header.Set("X-Dev-User", "runner_member_11")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Contains(t, rec.Body.String(), "CREW_FULL")

	// 11. Goal setting: Member cannot set goal (403 FORBIDDEN)
	goalBody := bytes.NewBufferString(`{"goal_type":"distance","target_value":100000}`)
	req = httptest.NewRequest(http.MethodPost, "/v1/crews/goals", goalBody)
	req.Header.Set("X-Dev-User", "runner_member_1")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusForbidden, rec.Code)

	// 12. Goal setting: Leader sets goal (201 CREATED)
	goalLeaderBody := bytes.NewBufferString(`{"goal_type":"distance","target_value":100000}`)
	req = httptest.NewRequest(http.MethodPost, "/v1/crews/goals", goalLeaderBody)
	req.Header.Set("X-Dev-User", "runner_leader")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusCreated, rec.Code)

	var goalResp store.CrewGoal
	err = json.Unmarshal(rec.Body.Bytes(), &goalResp)
	require.NoError(t, err)
	assert.Equal(t, "distance", goalResp.GoalType)
	assert.Equal(t, float64(100000), goalResp.TargetValue)

	// 13. Verify GET /v1/crews/my reflects the active goal
	req = httptest.NewRequest(http.MethodGet, "/v1/crews/my", nil)
	req.Header.Set("X-Dev-User", "runner_member_1")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)

	err = json.Unmarshal(rec.Body.Bytes(), &myCrewResp)
	require.NoError(t, err)
	require.NotNil(t, myCrewResp.ActiveGoal)
	assert.Equal(t, "distance", myCrewResp.ActiveGoal.GoalType)
	assert.Equal(t, float64(100000), myCrewResp.ActiveGoal.TargetValue)
	assert.Equal(t, "member", myCrewResp.Role)
	assert.Len(t, myCrewResp.Members, 10)
}
