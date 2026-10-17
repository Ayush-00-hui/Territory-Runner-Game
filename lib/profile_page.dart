import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/gameplay/territory_service.dart';
import 'features/profile/widgets/auth_modal.dart';
import 'features/profile/widgets/challenges_shelf.dart';
import 'features/profile/widgets/faction_leaderboard.dart';
import 'features/profile/widgets/profile_dialogs.dart';
import 'features/profile/widgets/profile_hero.dart';
import 'features/profile/widgets/settings_list.dart';
import 'features/profile/widgets/stat_grid.dart';
import 'features/profile/widgets/weekly_league_view.dart';
import 'features/social/widgets/social_hub_sheet.dart';
import 'models/runner_profile.dart';
import 'models/territory.dart';
import 'services/firebase_service.dart';
import 'ui/ui.dart';

enum ProfileTab { athlete, turfWar, league, squad }

class ProfilePage extends StatefulWidget {
  final RunnerProfile? initialProfile;
  final List<Territory>? initialTerritories;

  const ProfilePage({
    super.key,
    this.initialProfile,
    this.initialTerritories,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late final AnimationController _pageController;
  late final Animation<double> _fadeAnimation;
  ProfileTab _activeTab = ProfileTab.athlete;

  final TerritoryService _territoryService = TerritoryService();
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _pageController,
      curve: Curves.easeOut,
    );
    _pageController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openAuthDialog() {
    showProfileAuthModal(
      context,
      firebaseService: _firebaseService,
      territoryService: _territoryService,
      onProfileUpdated: () => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        title: Text(
          'ATHLETE HUB',
          style: AppText.headingSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.sports_kabaddi_rounded, color: AppColors.secondary),
            onPressed: () => showSocialHubSheet(context),
            tooltip: 'Social Syndicate & Duels',
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync_outlined, color: AppColors.accent),
            onPressed: _openAuthDialog,
            tooltip: 'Cloud Sync',
          ),
        ],
      ),
      body: widget.initialProfile != null
          ? _buildProfileContent(
              widget.initialProfile!,
              widget.initialTerritories ?? [],
            )
          : ValueListenableBuilder(
              valueListenable: Hive.box<RunnerProfile>('profile').listenable(),
              builder: (context, Box<RunnerProfile> profileBox, _) {
                final profile = _territoryService.getProfile();

                return ValueListenableBuilder(
                  valueListenable: Hive.box<Territory>('territories_v3').listenable(),
                  builder: (context, Box<Territory> territoryBox, _) {
                    final territories = _territoryService.getCapturedTerritoryObjects();
                    return _buildProfileContent(profile, territories);
                  },
                );
              },
            ),
    );
  }

  Widget _buildProfileContent(RunnerProfile profile, List<Territory> territories) {
    final double totalAreaM2 = territories.fold(0.0, (sum, t) => sum + t.areaSqMeters);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s8,
          AppSpacing.s16,
          AppSpacing.s32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- TOP SEGMENTED TAB SELECTOR ---
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppSpacing.brFull,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSegmentButton(
                      tab: ProfileTab.athlete,
                      label: 'ATHLETE',
                      icon: Icons.person_rounded,
                    ),
                  ),
                  Expanded(
                    child: _buildSegmentButton(
                      tab: ProfileTab.turfWar,
                      label: 'TURF WAR',
                      icon: Icons.shield_rounded,
                    ),
                  ),
                  Expanded(
                    child: _buildSegmentButton(
                      tab: ProfileTab.league,
                      label: 'LEAGUE',
                      icon: Icons.leaderboard_rounded,
                    ),
                  ),
                  Expanded(
                    child: _buildSegmentButton(
                      tab: ProfileTab.squad,
                      label: 'SQUAD',
                      icon: Icons.groups_rounded,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.s20),

            if (_activeTab == ProfileTab.athlete) ...[
              // --- HERO ATHLETE CARD ---
              ProfileHeroCard(
                profile: profile,
                onEditCallsign: () {
                  showEditCallsignDialog(
                    context,
                    profile,
                    _territoryService,
                    () => setState(() {}),
                  );
                },
                onSelectFaction: () {
                  showFactionSelectionDialog(
                    context,
                    profile,
                    _territoryService,
                    () => setState(() {}),
                  );
                },
              ),

              const SizedBox(height: AppSpacing.s24),

              // --- METRIC OVERVIEW GRID ---
              Text(
                'PERFORMANCE TELEMETRY',
                style: AppText.label.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),

              ProfileStatGrid(
                profile: profile,
                territoryService: _territoryService,
              ),

              const SizedBox(height: AppSpacing.s24),

              // --- CHALLENGES & BADGES SHELF ---
              ChallengesShelf(
                profile: profile,
                territoriesCount: territories.length,
                totalAreaSqMeters: totalAreaM2,
              ),

              const SizedBox(height: AppSpacing.s24),

              // --- SETTINGS & CONTROLS ---
              Text(
                'SETTINGS & PLATFORM',
                style: AppText.label.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),

              ProfileSettingsList(
                firebaseService: _firebaseService,
                territoryService: _territoryService,
                onOpenAuth: _openAuthDialog,
              ),
            ] else if (_activeTab == ProfileTab.turfWar) ...[
              // --- FACTION LEADERBOARD & TURF WAR DOMINANCE ---
              FactionLeaderboard(
                profile: profile,
                territories: territories,
              ),
            ] else if (_activeTab == ProfileTab.league) ...[
              // --- WEEKLY LEAGUE STANDINGS & CUTOFFS ---
              const WeeklyLeagueView(),
            ] else ...[
              // --- SQUAD & DUELS HUB ---
              const SizedBox(
                height: 600,
                child: SocialHubView(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required ProfileTab tab,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _activeTab == tab;

    return GestureDetector(
      onTap: () {
        if (_activeTab != tab) {
          AppMotion.lightTick();
          setState(() => _activeTab = tab);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: AppSpacing.brFull,
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppText.label.copyWith(
                color: isSelected ? AppColors.accent : AppColors.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}