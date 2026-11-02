package store_test

import (
	"context"
	"testing"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestXP_ProportionalScalingAndAntiFarmingFloor(t *testing.T) {
	ctx := context.Background()

	testCases := []struct {
		name         string
		areaSqm      float64
		expectedXP   int
		expectClaim  bool
	}{
		{
			name:        "Below 25 sqm floor awards zero XP",
			areaSqm:     24.5,
			expectedXP:  0,
			expectClaim: false,
		},
		{
			name:        "Minimum valid loop (25 sqm) awards 5 XP floor",
			areaSqm:     25.0,
			expectedXP:  5,
			expectClaim: true,
		},
		{
			name:        "40 sqm loop awards 5 XP floor (40/20 = 2 -> floor 5)",
			areaSqm:     40.0,
			expectedXP:  5,
			expectClaim: true,
		},
		{
			name:        "100 sqm loop awards 5 XP (100/20 = 5)",
			areaSqm:     100.0,
			expectedXP:  5,
			expectClaim: true,
		},
		{
			name:        "500 sqm park loop awards 25 XP (500/20 = 25)",
			areaSqm:     500.0,
			expectedXP:  25,
			expectClaim: true,
		},
		{
			name:        "2,000 sqm neighbourhood loop awards 100 XP (2000/20 = 100)",
			areaSqm:     2000.0,
			expectedXP:  100,
			expectClaim: true,
		},
		{
			name:        "10,000 sqm large loop awards 500 XP (10000/20 = 500)",
			areaSqm:     10000.0,
			expectedXP:  500,
			expectClaim: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			memStore := store.NewMemoryStore()
			userID := "athlete_xp_" + tc.name
			runID := "run_" + tc.name

			loop := geo.EnclosedLoop{
				Polygon: []geo.LatLng{
					{Latitude: 51.500, Longitude: -0.120},
					{Latitude: 51.501, Longitude: -0.120},
					{Latitude: 51.501, Longitude: -0.121},
					{Latitude: 51.500, Longitude: -0.121},
					{Latitude: 51.500, Longitude: -0.120},
				},
				AreaSqMeters:       tc.areaSqm,
				LoopDistanceMeters: 400.0,
				ClosedAt:           time.Now().UTC(),
			}

			run := &store.Run{
				ID:             runID,
				UserID:         userID,
				IdempotencyKey: "idem_" + runID,
				DistanceMeters: 500.0,
			}

			result, err := memStore.CaptureRunAndMutateTerritories(ctx, run, []geo.EnclosedLoop{loop}, nil)
			require.NoError(t, err)
			assert.Equal(t, tc.expectedXP, result.XpAwarded)

			if tc.expectClaim {
				assert.Equal(t, tc.areaSqm, result.AreaClaimedSqm)
			} else {
				assert.Equal(t, 0.0, result.AreaClaimedSqm)
			}

			user, err := memStore.GetUser(ctx, userID)
			require.NoError(t, err)
			assert.Equal(t, int64(tc.expectedXP), user.XP)

			// Verify idempotency does not double-award or change XP
			replayResult, err := memStore.CaptureRunAndMutateTerritories(ctx, run, []geo.EnclosedLoop{loop}, nil)
			require.NoError(t, err)
			assert.Equal(t, tc.expectedXP, replayResult.XpAwarded)

			userReplay, err := memStore.GetUser(ctx, userID)
			require.NoError(t, err)
			assert.Equal(t, int64(tc.expectedXP), userReplay.XP, "Replay must not increment XP")
		})
	}
}

