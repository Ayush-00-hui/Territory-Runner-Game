package notify

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store"
)

// DecayReminderConfig sets thresholds and rate limits for territory decay notifications.
type DecayReminderConfig struct {
	QuietHoursStart int // 9 (09:00 local time)
	QuietHoursEnd   int // 20 (20:00 local time)
	DailyLimit      int // 1 per owner per 24 hours
	WeeklyLimit     int // 3 per owner per 7 days
}

// DefaultDecayReminderConfig returns standard production defaults.
func DefaultDecayReminderConfig() DecayReminderConfig {
	return DecayReminderConfig{
		QuietHoursStart: 9,
		QuietHoursEnd:   20,
		DailyLimit:      1,
		WeeklyLimit:     3,
	}
}

// DecayReminderEngine processes decaying territories after hourly decay jobs
// and dispatches deduplicated, quiet-hours-compliant push notifications.
type DecayReminderEngine struct {
	store    store.Store
	notifier Notifier
	logger   *slog.Logger
	config   DecayReminderConfig
}

// NewDecayReminderEngine creates an engine instance for processing decay alerts.
func NewDecayReminderEngine(dataStore store.Store, notifier Notifier, logger *slog.Logger, cfg ...DecayReminderConfig) *DecayReminderEngine {
	if logger == nil {
		logger = slog.Default()
	}
	config := DefaultDecayReminderConfig()
	if len(cfg) > 0 {
		config = cfg[0]
	}
	return &DecayReminderEngine{
		store:    dataStore,
		notifier: notifier,
		logger:   logger,
		config:   config,
	}
}

// ProcessDecayAlerts inspects all territories for strength drops crossing 50% or 30%,
// enforces advisory lock concurrency, rate limits, quiet hours, and dedup.
// Returns the count of successfully delivered push notifications.
func (e *DecayReminderEngine) ProcessDecayAlerts(ctx context.Context, now time.Time) (int, error) {
	if now.IsZero() {
		now = time.Now().UTC()
	}

	// 1. Guard execution with cluster-wide advisory lock
	acquired, unlock, err := e.store.TryAcquireDecayLock(ctx)
	if err != nil {
		return 0, fmt.Errorf("failed to acquire decay advisory lock: %w", err)
	}
	if !acquired {
		e.logger.Info("decay reminder job skipped: another instance holds advisory lock")
		return 0, nil
	}
	defer unlock()

	// 2. Fetch all territories
	territories, err := e.store.GetAllTerritories(ctx)
	if err != nil {
		return 0, fmt.Errorf("failed to get territories for decay reminders: %w", err)
	}

	// Group territories by owner
	byOwner := make(map[string][]store.Territory)
	for _, t := range territories {
		if t.OwnerID != "" {
			byOwner[t.OwnerID] = append(byOwner[t.OwnerID], t)
		}
	}

	sentCount := 0

	for ownerID, ownerTerritories := range byOwner {
		// 3. User settings check (Opt-in and Timezone)
		settings, err := e.store.GetUserSettings(ctx, ownerID)
		if err != nil {
			e.logger.Warn("failed to fetch user settings for decay check", "owner_id", ownerID, "error", err)
			continue
		}

		// Opt-out check: user disabled Land reminders
		if !settings.LandReminders {
			e.logger.Debug("skipping decay reminders: user opted out", "owner_id", ownerID)
			continue
		}

		// 4. Quiet hours check in user's local timezone (09:00 - 20:00)
		loc := time.UTC
		if settings.Timezone != "" {
			if l, err := time.LoadLocation(settings.Timezone); err == nil {
				loc = l
			}
		}
		localHour := now.In(loc).Hour()
		if localHour < e.config.QuietHoursStart || localHour >= e.config.QuietHoursEnd {
			e.logger.Debug("skipping decay reminder: outside quiet hours", "owner_id", ownerID, "local_hour", localHour)
			continue
		}

		// 5. Frequency & rate limits check (1 per 24 hours, max 3 per week)
		oneWeekAgo := now.Add(-7 * 24 * time.Hour)
		recentNotifs, err := e.store.GetRecentDecayNotifications(ctx, ownerID, oneWeekAgo)
		if err != nil {
			e.logger.Warn("failed to query recent decay notifications", "owner_id", ownerID, "error", err)
			continue
		}

		// Weekly cap check (<= 3 in 7 days)
		if len(recentNotifs) >= e.config.WeeklyLimit {
			e.logger.Debug("skipping decay reminder: weekly cap reached", "owner_id", ownerID, "recent_count", len(recentNotifs))
			continue
		}

		// Daily cap check (1 per 24 hours)
		twentyFourHoursAgo := now.Add(-24 * time.Hour)
		hasRecentDaily := false
		for _, n := range recentNotifs {
			if n.SentAt.After(twentyFourHoursAgo) {
				hasRecentDaily = true
				break
			}
		}
		if hasRecentDaily {
			e.logger.Debug("skipping decay reminder: 24h daily cap active", "owner_id", ownerID)
			continue
		}

		// 6. Find eligible candidate territories crossing 50% or 30%
		var bestTerritory store.Territory
		hasCandidate := false
		candidateThreshold := 0
		candidateLowestStrength := 101.0

		for _, t := range ownerTerritories {
			effStrength := t.EffectiveStrength(now)
			threshold := 0
			if effStrength <= 30.0 {
				threshold = 30
			} else if effStrength <= 50.0 {
				threshold = 50
			}
			if threshold == 0 {
				continue // Territory is fortified (> 50% strength)
			}

			// Deduplication: has this threshold already been notified since the territory's last defense?
			refTime := t.LastDefendedAt
			if refTime.IsZero() {
				refTime = t.UpdatedAt
			}
			alreadySent, err := e.store.HasDecayNotificationBeenSent(ctx, t.ID, threshold, refTime)
			if err != nil || alreadySent {
				continue
			}

			// Pick the weakest territory for this owner
			if effStrength < candidateLowestStrength {
				candidateLowestStrength = effStrength
				bestTerritory = t
				hasCandidate = true
				candidateThreshold = threshold
			}
		}

		// 7. Dispatch push notification to weakest territory if eligible
		if hasCandidate {
			sendErr := e.notifier.SendLandWeakAlertToUser(ctx, ownerID, bestTerritory.ID, candidateLowestStrength)
			if sendErr != nil {
				e.logger.Warn("failed to send land weak push", "owner_id", ownerID, "territory_id", bestTerritory.ID, "error", sendErr)
				continue
			}

			if recErr := e.store.RecordDecayNotification(ctx, ownerID, bestTerritory.ID, candidateThreshold, now); recErr != nil {
				e.logger.Error("failed to record decay notification dedup", "owner_id", ownerID, "territory_id", bestTerritory.ID, "error", recErr)
			}
			sentCount++
		}
	}

	return sentCount, nil
}
