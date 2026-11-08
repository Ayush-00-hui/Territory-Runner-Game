package notify_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/notify"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type mockNotifier struct {
	sentAlerts   []landWeakAlertCall
	failNextSend bool
}

type landWeakAlertCall struct {
	UserID      string
	TerritoryID string
	Strength    float64
}

func (m *mockNotifier) SendTerritoryAlert(ctx context.Context, deviceToken, territoryID, rivalName string, areaLost float64) error {
	return nil
}

func (m *mockNotifier) SendTerritoryAlertToUser(ctx context.Context, userID, territoryID, rivalName string, areaLost float64) error {
	return nil
}

func (m *mockNotifier) SendLandWeakAlert(ctx context.Context, deviceToken, territoryID string, currentStrength float64) error {
	return nil
}

func (m *mockNotifier) SendLandWeakAlertToUser(ctx context.Context, userID, territoryID string, currentStrength float64) error {
	if m.failNextSend {
		return errors.New("fcm network connection failed")
	}
	m.sentAlerts = append(m.sentAlerts, landWeakAlertCall{
		UserID:      userID,
		TerritoryID: territoryID,
		Strength:    currentStrength,
	})
	return nil
}

func TestDecayReminderEngine_ThresholdsAndWeakestSelection(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()
	mockNotif := &mockNotifier{}
	engine := notify.NewDecayReminderEngine(memStore, mockNotif, nil)

	ownerID := "runner_alpha"
	// Setup user with land reminders enabled and UTC timezone
	err := memStore.UpdateUserSettings(ctx, ownerID, &store.UserSettings{
		LiveVisibility: "off",
		Timezone:       "UTC",
		LandReminders:  true,
	})
	require.NoError(t, err)

	now := time.Date(2026, 11, 8, 12, 0, 0, 0, time.UTC) // 12:00 UTC (within 09:00 - 20:00)

	// Add 3 territories for runner_alpha:
	// t1: 80% strength (healthy, should not trigger)
	// t2: 45% strength (crosses 50%)
	// t3: 25% strength (crosses 30% - weakest!)
	memStore.AddTerritoryForTest(&store.Territory{
		ID:             "t_healthy",
		OwnerID:        ownerID,
		AreaSqm:        1000.0,
		Strength:       80.0,
		LastDefendedAt: now,
		LastDecayedAt:  now,
	})

	memStore.AddTerritoryForTest(&store.Territory{
		ID:             "t_mid_weak",
		OwnerID:        ownerID,
		AreaSqm:        2500.0,
		Strength:       45.0,
		LastDefendedAt: now,
		LastDecayedAt:  now,
	})

	memStore.AddTerritoryForTest(&store.Territory{
		ID:             "t_crit_weak",
		OwnerID:        ownerID,
		AreaSqm:        5000.0,
		Strength:       25.0,
		LastDefendedAt: now,
		LastDecayedAt:  now,
	})

	// Execute decay alerts evaluation
	sent, err := engine.ProcessDecayAlerts(ctx, now)
	require.NoError(t, err)
	assert.Equal(t, 1, sent, "must send exactly 1 alert per owner per evaluation")

	require.Len(t, mockNotif.sentAlerts, 1)
	assert.Equal(t, ownerID, mockNotif.sentAlerts[0].UserID)
	assert.Equal(t, "t_crit_weak", mockNotif.sentAlerts[0].TerritoryID, "must pick the weakest territory (25.0 strength)")
	assert.InDelta(t, 25.0, mockNotif.sentAlerts[0].Strength, 0.1)
}

func TestDecayReminderEngine_Deduplication(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()
	mockNotif := &mockNotifier{}
	engine := notify.NewDecayReminderEngine(memStore, mockNotif, nil)

	ownerID := "runner_beta"
	err := memStore.UpdateUserSettings(ctx, ownerID, &store.UserSettings{
		Timezone:      "UTC",
		LandReminders: true,
	})
	require.NoError(t, err)

	now := time.Date(2026, 11, 8, 14, 0, 0, 0, time.UTC)

	memStore.AddTerritoryForTest(&store.Territory{
		ID:             "t_beta_1",
		OwnerID:        ownerID,
		AreaSqm:        1500.0,
		Strength:       40.0,
		LastDefendedAt: now,
		LastDecayedAt:  now,
	})

	// First run sends 1 alert
	sent, err := engine.ProcessDecayAlerts(ctx, now)
	require.NoError(t, err)
	assert.Equal(t, 1, sent)

	// Immediate second run must send 0 (deduplicated by 24h daily cap and territory threshold dedup)
	sent2, err := engine.ProcessDecayAlerts(ctx, now.Add(1*time.Hour))
	require.NoError(t, err)
	assert.Equal(t, 0, sent2, "must not send duplicate push within 24h")
	assert.Len(t, mockNotif.sentAlerts, 1)
}

func TestDecayReminderEngine_QuietHoursAndTimezone(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()
	mockNotif := &mockNotifier{}
	engine := notify.NewDecayReminderEngine(memStore, mockNotif, nil)

	ownerID := "runner_ny"
	// User in America/New_York (UTC-5 in winter)
	err := memStore.UpdateUserSettings(ctx, ownerID, &store.UserSettings{
		Timezone:      "America/New_York",
		LandReminders: true,
	})
	require.NoError(t, err)

	// 12:00 UTC corresponds to 07:00 in New York (OUTSIDE 09:00 - 20:00 quiet hours)
	morningUTC := time.Date(2026, 11, 8, 12, 0, 0, 0, time.UTC)

	memStore.AddTerritoryForTest(&store.Territory{
		ID:             "t_ny_weak",
		OwnerID:        ownerID,
		AreaSqm:        2000.0,
		Strength:       35.0,
		LastDefendedAt: morningUTC,
		LastDecayedAt:  morningUTC,
	})

	// Should be skipped due to quiet hours (07:00 local time)
	sentMorning, err := engine.ProcessDecayAlerts(ctx, morningUTC)
	require.NoError(t, err)
	assert.Equal(t, 0, sentMorning, "must skip delivery during quiet hours (< 09:00 local)")
	assert.Empty(t, mockNotif.sentAlerts)

	// 15:00 UTC corresponds to 10:00 in New York (INSIDE 09:00 - 20:00 allowed hours)
	daytimeUTC := time.Date(2026, 11, 8, 15, 0, 0, 0, time.UTC)
	sentDaytime, err := engine.ProcessDecayAlerts(ctx, daytimeUTC)
	require.NoError(t, err)
	assert.Equal(t, 1, sentDaytime, "must send alert when inside user's local 09:00 - 20:00 window")
	assert.Len(t, mockNotif.sentAlerts, 1)

	// 02:00 UTC next day corresponds to 21:00 in New York (OUTSIDE quiet hours >= 20:00 local)
	nightUTC := time.Date(2026, 11, 9, 2, 0, 0, 0, time.UTC)
	sentNight, err := engine.ProcessDecayAlerts(ctx, nightUTC)
	require.NoError(t, err)
	assert.Equal(t, 0, sentNight, "must skip delivery at night (>= 20:00 local)")
}

func TestDecayReminderEngine_WeeklyCap(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()
	mockNotif := &mockNotifier{}
	engine := notify.NewDecayReminderEngine(memStore, mockNotif, nil)

	ownerID := "runner_weekly"
	err := memStore.UpdateUserSettings(ctx, ownerID, &store.UserSettings{
		Timezone:      "UTC",
		LandReminders: true,
	})
	require.NoError(t, err)

	baseTime := time.Date(2026, 11, 1, 12, 0, 0, 0, time.UTC)

	// Simulate 3 alerts already sent across the last 3 days
	err = memStore.RecordDecayNotification(ctx, ownerID, "t_w1", 50, baseTime.Add(24*time.Hour))
	require.NoError(t, err)
	err = memStore.RecordDecayNotification(ctx, ownerID, "t_w2", 50, baseTime.Add(48*time.Hour))
	require.NoError(t, err)
	err = memStore.RecordDecayNotification(ctx, ownerID, "t_w3", 50, baseTime.Add(72*time.Hour))
	require.NoError(t, err)

	// Day 4: territory is weak, 24h has elapsed since last alert, but weekly count is already 3
	day4 := baseTime.Add(97 * time.Hour)
	memStore.AddTerritoryForTest(&store.Territory{
		ID:             "t_w4",
		OwnerID:        ownerID,
		AreaSqm:        1000.0,
		Strength:       20.0,
		LastDefendedAt: day4,
		LastDecayedAt:  day4,
	})

	sent, err := engine.ProcessDecayAlerts(ctx, day4)
	require.NoError(t, err)
	assert.Equal(t, 0, sent, "must not send more than 3 alerts per owner in a 7-day rolling window")
}

func TestDecayReminderEngine_OptOut(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()
	mockNotif := &mockNotifier{}
	engine := notify.NewDecayReminderEngine(memStore, mockNotif, nil)

	ownerID := "runner_opted_out"
	// User explicitly opted out of Land reminders
	err := memStore.UpdateUserSettings(ctx, ownerID, &store.UserSettings{
		Timezone:      "UTC",
		LandReminders: false,
	})
	require.NoError(t, err)

	now := time.Date(2026, 11, 8, 14, 0, 0, 0, time.UTC)
	memStore.AddTerritoryForTest(&store.Territory{
		ID:             "t_optout_weak",
		OwnerID:        ownerID,
		AreaSqm:        3000.0,
		Strength:       20.0,
		LastDefendedAt: now,
		LastDecayedAt:  now,
	})

	sent, err := engine.ProcessDecayAlerts(ctx, now)
	require.NoError(t, err)
	assert.Equal(t, 0, sent, "must respect land_reminders = false and send 0 alerts")
	assert.Empty(t, mockNotif.sentAlerts)
}

func TestDecayReminderEngine_FCMFailureRetry(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()
	mockNotif := &mockNotifier{failNextSend: true}
	engine := notify.NewDecayReminderEngine(memStore, mockNotif, nil)

	ownerID := "runner_fail"
	err := memStore.UpdateUserSettings(ctx, ownerID, &store.UserSettings{
		Timezone:      "UTC",
		LandReminders: true,
	})
	require.NoError(t, err)

	now := time.Date(2026, 11, 8, 14, 0, 0, 0, time.UTC)
	memStore.AddTerritoryForTest(&store.Territory{
		ID:             "t_retry_weak",
		OwnerID:        ownerID,
		AreaSqm:        2000.0,
		Strength:       40.0,
		LastDefendedAt: now,
		LastDecayedAt:  now,
	})

	// First attempt fails at FCM
	sent1, err := engine.ProcessDecayAlerts(ctx, now)
	require.NoError(t, err)
	assert.Equal(t, 0, sent1, "failed FCM send must report 0 sent")

	// Ensure no dedup record was written so retry can succeed later
	recent, err := memStore.GetRecentDecayNotifications(ctx, ownerID, now.Add(-1*time.Hour))
	require.NoError(t, err)
	assert.Empty(t, recent, "dedup record must NOT be persisted on FCM failure")

	// Next attempt succeeds after recovery
	mockNotif.failNextSend = false
	sent2, err := engine.ProcessDecayAlerts(ctx, now.Add(5*time.Minute))
	require.NoError(t, err)
	assert.Equal(t, 1, sent2, "must succeed on retry after FCM recovery")
}

func TestDecayReminderEngine_AdvisoryLock(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()
	mockNotif := &mockNotifier{}
	engine := notify.NewDecayReminderEngine(memStore, mockNotif, nil)

	now := time.Date(2026, 11, 8, 14, 0, 0, 0, time.UTC)

	// Manually acquire lock as if another server instance holds it
	acquired, unlock, err := memStore.TryAcquireDecayLock(ctx)
	require.NoError(t, err)
	require.True(t, acquired)

	// Engine must skip gracefully without error
	sent, err := engine.ProcessDecayAlerts(ctx, now)
	require.NoError(t, err)
	assert.Equal(t, 0, sent, "must skip processing when advisory lock is held by another instance")

	unlock()

	// After release, engine can acquire lock
	sentAfter, err := engine.ProcessDecayAlerts(ctx, now)
	require.NoError(t, err)
	assert.Equal(t, 0, sentAfter) // 0 territories exist, but ran without lock conflict
}

func TestBuildLandWeakPayload_PrivacyZeroCoordinates(t *testing.T) {
	payload := notify.BuildLandWeakPayload("test_token_123", "poly_territory_456", 38.5)
	msg := payload.Message

	assert.Equal(t, "test_token_123", msg.Token)
	require.NotNil(t, msg.Notification)
	assert.Equal(t, "Land reminder", msg.Notification.Title)
	assert.Equal(t, "One of your areas is getting weak. A short loop through it will restore it.", msg.Notification.Body)

	// Zero GPS coordinates in payload
	assert.NotContains(t, msg.Data, "lat")
	assert.NotContains(t, msg.Data, "lng")
	assert.NotContains(t, msg.Data, "latitude")
	assert.NotContains(t, msg.Data, "longitude")
	assert.NotContains(t, msg.Data, "polygon")

	assert.Equal(t, "decay_warning", msg.Data["type"])
	assert.Equal(t, "poly_territory_456", msg.Data["territory_id"])
	assert.Equal(t, "38.5", msg.Data["current_strength"])
}
