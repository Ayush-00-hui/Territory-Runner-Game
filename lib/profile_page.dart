import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/gameplay/territory_service.dart';
import 'features/profile/widgets/achievements_list.dart';
import 'features/profile/widgets/auth_modal.dart';
import 'features/profile/widgets/profile_dialogs.dart';
import 'features/profile/widgets/profile_hero.dart';
import 'features/profile/widgets/settings_list.dart';
import 'features/profile/widgets/stat_grid.dart';
import 'models/runner_profile.dart';
import 'services/firebase_service.dart';
import 'ui/ui.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  late final AnimationController _pageController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _topSlideAnimation;
  late final Animation<Offset> _statsSlideAnimation;
  late final Animation<Offset> _achievementsSlideAnimation;
  late final Animation<Offset> _settingsSlideAnimation;

  final TerritoryService _territoryService = TerritoryService();
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _pageController,
      curve: Curves.easeOut,
    );

    _topSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _pageController,
        curve: const Interval(0.00, 0.35, curve: Curves.easeOutCubic),
      ),
    );

    _statsSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _pageController,
        curve: const Interval(0.20, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    _achievementsSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _pageController,
        curve: const Interval(0.40, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _settingsSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _pageController,
        curve: const Interval(0.60, 1.00, curve: Curves.easeOutCubic),
      ),
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
          style: AppText.headlineMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 17,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync_outlined, color: AppColors.accent),
            onPressed: _openAuthDialog,
            tooltip: 'Cloud Sync',
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<RunnerProfile>('profile').listenable(),
        builder: (context, Box<RunnerProfile> profileBox, _) {
          final profile = _territoryService.getProfile();
          final territoriesCount = _territoryService.getCapturedTerritories().length;

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
                  // --- HERO ATHLETE CARD ---
                  SlideTransition(
                    position: _topSlideAnimation,
                    child: ProfileHeroCard(
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
                  ),

                  const SizedBox(height: AppSpacing.s24),

                  // --- METRIC OVERVIEW GRID ---
                  Text(
                    'PERFORMANCE TELEMETRY',
                    style: AppText.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),

                  SlideTransition(
                    position: _statsSlideAnimation,
                    child: ProfileStatGrid(
                      profile: profile,
                      territoryService: _territoryService,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s24),

                  // --- TROPHY CASE & ACHIEVEMENTS ---
                  Text(
                    'TROPHY CASE & BADGES',
                    style: AppText.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),

                  SlideTransition(
                    position: _achievementsSlideAnimation,
                    child: ProfileAchievementsList(
                      profile: profile,
                      territoriesCount: territoriesCount,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s24),

                  // --- SETTINGS & DATA SYNC ---
                  Text(
                    'DATA & PLATFORM',
                    style: AppText.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),

                  SlideTransition(
                    position: _settingsSlideAnimation,
                    child: ProfileSettingsList(
                      firebaseService: _firebaseService,
                      territoryService: _territoryService,
                      onOpenAuth: _openAuthDialog,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}