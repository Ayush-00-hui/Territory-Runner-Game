import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'features/gameplay/territory_service.dart';
import 'features/profile/widgets/auth_modal.dart';
import 'features/profile/widgets/challenges_shelf.dart';
import 'features/profile/widgets/faction_leaderboard.dart';
import 'features/profile/widgets/profile_dialogs.dart';
import 'features/profile/widgets/profile_hero.dart';
import 'features/profile/widgets/runner_crew_view.dart';
import 'features/profile/widgets/settings_list.dart';
import 'features/profile/widgets/stat_grid.dart';
import 'features/profile/widgets/season_crew_view.dart';
import 'features/profile/widgets/weekly_league_view.dart';
import 'features/social/widgets/social_hub_sheet.dart';
import 'models/runner_profile.dart';
import 'models/territory.dart';
import 'services/api_client.dart';
import 'services/firebase_service.dart';
import 'ui/ui.dart';

enum ProfileTab { athlete, turfWar, league, squad }

class ProfilePage extends StatefulWidget {
  final RunnerProfile? initialProfile;
  final List<Territory>? initialTerritories;
  final ScrollController? scrollController;

  const ProfilePage({
    super.key,
    this.initialProfile,
    this.initialTerritories,
    this.scrollController,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pageController;
  late final Animation<double> _fadeAnimation;
  ProfileTab _activeTab = ProfileTab.athlete;
  int _leagueSubTab = 0;

  final TerritoryService _territoryService = TerritoryService();
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
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

  RunnerProfile? _resolveProfileForActions() {
    if (widget.initialProfile != null) return widget.initialProfile;
    try {
      return _territoryService.getProfile();
    } catch (_) {
      return null;
    }
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
    final actionProfile = _resolveProfileForActions();

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        title: Text(
          'Profile',
          style: AppText.titleMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          Center(
            child: FriendInboxActionButtons(
              compact: true,
              onOpenInbox: () => showFriendRequestsInboxSheet(
                context,
                currentCallsign: actionProfile?.username,
                currentRunnerId: actionProfile?.displayRunnerId,
              ),
              onAddFriend: () => showAddFriendDialog(
                context,
                apiClient: ApiClient(),
                currentCallsign: actionProfile?.username,
                currentRunnerId: actionProfile?.displayRunnerId,
                onAdded: () {
                  if (mounted) setState(() {});
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.cloud_sync_outlined,
              color: AppColors.accent,
            ),
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
                  valueListenable: Hive.box<Territory>('territories_v3')
                      .listenable(),
                  builder: (context, Box<Territory> territoryBox, _) {
                    final territories = _territoryService
                        .getCapturedTerritoryObjects();
                    return _buildProfileContent(profile, territories);
                  },
                );
              },
            ),
    );
  }

  Widget _buildProfileContent(
    RunnerProfile profile,
    List<Territory> territories,
  ) {
    final double totalAreaM2 = territories.fold(
      0.0,
      (sum, t) => sum + t.areaSqMeters,
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        controller: widget.scrollController,
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
                      label: 'Profile',
                      icon: Icons.person_rounded,
                    ),
                  ),
                  Expanded(
                    child: _buildSegmentButton(
                      tab: ProfileTab.turfWar,
                      label: 'Teams',
                      icon: Icons.shield_rounded,
                    ),
                  ),
                  Expanded(
                    child: _buildSegmentButton(
                      tab: ProfileTab.league,
                      label: 'League',
                      icon: Icons.leaderboard_rounded,
                    ),
                  ),
                  Expanded(
                    child: _buildSegmentButton(
                      tab: ProfileTab.squad,
                      label: 'Friends',
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
                'Stats',
                style: AppText.titleSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
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
                'Settings',
                style: AppText.titleSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),

              ProfileSettingsList(
                firebaseService: _firebaseService,
                territoryService: _territoryService,
                onOpenAuth: _openAuthDialog,
              ),
            ] else if (_activeTab == ProfileTab.turfWar) ...[
              // --- RUNNER TEAM / CREW (CREATE & JOIN TEAM) ---
              const RunnerCrewView(),
              const SizedBox(height: AppSpacing.s24),

              // --- FACTION LEADERBOARD & TURF WAR DOMINANCE ---
              FactionLeaderboard(profile: profile, territories: territories),
            ] else if (_activeTab == ProfileTab.league) ...[
              // --- LEAGUE & SEASONS SUB-TAB SELECTOR ---
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.s16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppSpacing.brFull,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Show Weekly League',
                        selected: _leagueSubTab == 0,
                        child: InkWell(
                          onTap: () => setState(() => _leagueSubTab = 0),
                          borderRadius: AppSpacing.brFull,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _leagueSubTab == 0
                                  ? AppColors.surface2
                                  : Colors.transparent,
                              borderRadius: AppSpacing.brFull,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Weekly League',
                              style: AppText.caption.copyWith(
                                color: _leagueSubTab == 0
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Show Season & Crew',
                        selected: _leagueSubTab == 1,
                        child: InkWell(
                          onTap: () => setState(() => _leagueSubTab = 1),
                          borderRadius: AppSpacing.brFull,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _leagueSubTab == 1
                                  ? AppColors.surface2
                                  : Colors.transparent,
                              borderRadius: AppSpacing.brFull,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Season & Crew',
                              style: AppText.caption.copyWith(
                                color: _leagueSubTab == 1
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_leagueSubTab == 0)
                const WeeklyLeagueView()
              else
                const SeasonCrewView(),
            ] else ...[
              // --- SQUAD & DUELS HUB ---
              const SocialHubView(isEmbedded: true),
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

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: () {
          if (_activeTab != tab) {
            setState(() => _activeTab = tab);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.fast),
          curve: AppMotion.easeOut,
          constraints: const BoxConstraints(
            minHeight: AppSpacing.touchTarget,
            minWidth: AppSpacing.touchTarget,
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentContainer : Colors.transparent,
            borderRadius: AppSpacing.brFull,
            border: Border.all(
              color: isSelected ? AppColors.accent : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.accent : AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.s4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: AppText.labelMedium.copyWith(
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.textMuted,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
