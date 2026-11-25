"""
Territory Runner: Economy and Balance Simulation
Simulates Casual, Daily, and Power users over 4 weeks under the NEW Net Accounting Mechanics.
"""

import math

def simulate_athlete(
    name: str,
    runs_per_week: int,
    distance_km_per_run: float,
    loops_per_run: int,
    raw_loop_area_sqm: float,
    self_overlap_ratio: float, # fraction overlapping own existing land
    rival_overlap_sqm: float,  # area stolen from rivals per run
    rival_is_weak: bool,       # whether stolen land is from weak rival (<30% strength)
    rival_stolen_back_sqm_per_week: float, # land rivals reclaim from this athlete
    daily_xp_cap: int = 10000,
    weeks: int = 4
):
    print(f"\n{'='*70}")
    print(f"PROFILE: {name.upper()}")
    print(f"Schedule: {runs_per_week} runs/week, {distance_km_per_run} km/run, {loops_per_run} loops/run")
    print(f"Raw Loop Area: {raw_loop_area_sqm:,.0f} m^2, Self-overlap: {self_overlap_ratio*100:.0f}%")
    print(f"{'='*70}")

    total_owned_area = 0.0
    territory_strength = 0.0 # 0 to 100
    cumulative_xp = 0
    weekly_stats = []

    # Simulation runs day by day for `weeks * 7` days
    days = weeks * 7
    run_days = set()
    # Spread runs evenly across each 7-day week
    if runs_per_week == 2:
        # Tuesday, Saturday
        run_days = {w * 7 + d for w in range(weeks) for d in [1, 5]}
    elif runs_per_week == 5:
        # Mon, Tue, Wed, Fri, Sat
        run_days = {w * 7 + d for w in range(weeks) for d in [0, 1, 2, 4, 5]}
    elif runs_per_week == 7:
        run_days = {d for d in range(days)}

    for week in range(weeks):
        week_net_new = 0.0
        week_stolen = 0.0
        week_gained = 0.0
        week_xp = 0
        week_raw_area = 0.0

        for day_of_week in range(7):
            current_day = week * 7 + day_of_week
            
            # 1. Daily lazy strength decay (15.0 points per 24 hours)
            decay = 15.0
            territory_strength = max(0.0, territory_strength - decay)

            # 2. Daily rival conquest deduction (spread over week)
            daily_loss = rival_stolen_back_sqm_per_week / 7.0
            total_owned_area = max(0.0, total_owned_area - daily_loss)

            # 3. Check if today is a run day
            if current_day in run_days:
                day_xp = 0
                for loop in range(loops_per_run):
                    week_raw_area += raw_loop_area_sqm

                    # Net accounting:
                    # Self overlap produces 0 net new area for that portion
                    # If user already owns land, loop overlapping own land is defended
                    defended_overlap = min(total_owned_area, raw_loop_area_sqm * self_overlap_ratio) if total_owned_area > 0 else 0.0
                    net_new = max(0.0, raw_loop_area_sqm - defended_overlap)
                    stolen = rival_overlap_sqm / loops_per_run

                    gained = net_new + stolen

                    # Floor check: < 25 m^2 produces 0 XP and 0 mutation
                    if gained < 25.0:
                        continue

                    # Weak rival bonus (+50% of overlapped weak rival area)
                    weak_bonus = (stolen * 0.5) if rival_is_weak else 0.0
                    effective_xp_area = gained + weak_bonus

                    loop_xp = max(5, round(effective_xp_area / 20.0))

                    # Apply daily cap
                    if day_xp + loop_xp > daily_xp_cap:
                        awarded_xp = max(0, daily_xp_cap - day_xp)
                    else:
                        awarded_xp = loop_xp

                    day_xp += awarded_xp
                    week_net_new += net_new
                    week_stolen += stolen
                    week_gained += gained

                    # Area-weighted strength update
                    # new_strength = (old_eff * undisturbed + 100 * (defended + net_new)) / new_total
                    old_eff = territory_strength
                    undisturbed = max(0.0, total_owned_area - defended_overlap)
                    new_total = total_owned_area + net_new
                    if new_total > 0:
                        territory_strength = (old_eff * undisturbed + 100.0 * (defended_overlap + net_new)) / new_total
                    else:
                        territory_strength = 100.0

                    total_owned_area = new_total

                week_xp += day_xp

        cumulative_xp += week_xp
        # Level calculation: L*(L-1)*125 <= XP
        # L = floor((1 + sqrt(1 + 4 * XP / 125)) / 2) + 1
        level = int((1.0 + math.sqrt(1.0 + (4.0 * cumulative_xp / 125.0))) / 2.0)

        stats = {
            'week': week + 1,
            'raw_area': week_raw_area,
            'net_new': week_net_new,
            'stolen': week_stolen,
            'gained': week_gained,
            'xp': week_xp,
            'cumulative_xp': cumulative_xp,
            'level': level,
            'end_owned_area': total_owned_area,
            'end_strength': territory_strength,
        }
        weekly_stats.append(stats)

        print(f"Week {week+1}:")
        print(f"  Raw Ran: {week_raw_area:,.0f} m^2 | Net New: {week_net_new:,.0f} m^2 | Stolen: {week_stolen:,.0f} m^2")
        print(f"  Weekly Gained (League): {week_gained:,.0f} m^2 | Weekly XP: {week_xp:,} | Level: {level}")
        print(f"  Current Owned Area (Leaderboard): {total_owned_area:,.0f} m^2 | Avg Strength: {territory_strength:.1f}%")

    return weekly_stats

if __name__ == '__main__':
    print("="*70)
    print("TERRITORY RUNNER - MATHEMATICAL BALANCE SIMULATION (NEW ACCOUNTING)")
    print("="*70)

    # 1. Casual Athlete:
    # 2 runs/week, 3.5 km each, 1 loop of 15,000 m^2 (~400m perimeter)
    # Loops around home: 35% overlap with own land
    # Minimal rival interactions: steals 500 m^2 once a week, loses 200 m^2/week
    casual = simulate_athlete(
        name="Casual Runner",
        runs_per_week=2,
        distance_km_per_run=3.5,
        loops_per_run=1,
        raw_loop_area_sqm=15000.0,
        self_overlap_ratio=0.35,
        rival_overlap_sqm=500.0,
        rival_is_weak=True,
        rival_stolen_back_sqm_per_week=200.0,
    )

    # 2. Daily Athlete:
    # 5 runs/week, 6.0 km each, 2 loops of 25,000 m^2 each (50,000 m^2 raw/run)
    # 45% overlap with own land (runs same park/streets)
    # Active local contestation: steals 3,000 m^2 per run from rivals, loses 5,000 m^2/week
    daily = simulate_athlete(
        name="Daily Runner",
        runs_per_week=5,
        distance_km_per_run=6.0,
        loops_per_run=2,
        raw_loop_area_sqm=25000.0,
        self_overlap_ratio=0.45,
        rival_overlap_sqm=3000.0,
        rival_is_weak=False,
        rival_stolen_back_sqm_per_week=5000.0,
    )

    # 3. Power User (Marathon / High Volume):
    # 7 runs/week, 12.0 km each, 3 loops of 45,000 m^2 each (135,000 m^2 raw/run)
    # 55% overlap with own expanding empire
    # High rival friction: steals 12,000 m^2 per run, loses 20,000 m^2/week
    power = simulate_athlete(
        name="Power Runner (High Volume)",
        runs_per_week=7,
        distance_km_per_run=12.0,
        loops_per_run=3,
        raw_loop_area_sqm=45000.0,
        self_overlap_ratio=0.55,
        rival_overlap_sqm=12000.0,
        rival_is_weak=True,
        rival_stolen_back_sqm_per_week=20000.0,
        daily_xp_cap=10000,
    )
