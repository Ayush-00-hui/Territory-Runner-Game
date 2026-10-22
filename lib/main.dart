import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/onboarding/onboarding_screen.dart';
import 'features/auth/auth_screen.dart';
import 'profile_page.dart';
import 'features/map/map_screen.dart';
import 'models/territory.dart';
import 'models/runner_profile.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';

import 'package:flutter/foundation.dart';

import 'features/home/home_screen.dart';
import 'ui/ui.dart';
export 'ui/ui.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Configure edge-to-edge system UI styling for Android 15/16 and modern devices
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );

      // 1. Intercept Flutter framework rendering and layout errors
      FlutterError.onError = (FlutterErrorDetails details) {
        AppLogger.error(
          'FlutterError: ${details.exceptionAsString()}',
          tag: 'FlutterError',
          error: details.exception,
          stackTrace: details.stack,
        );
        if (kDebugMode) {
          FlutterError.dumpErrorToConsole(details);
        }
      };

      // 2. Present calm, non-red fallback screen
      ErrorWidget.builder = (FlutterErrorDetails details) {
        return CalmErrorScreen(details: details);
      };

      // 3. Intercept uncaught platform and asynchronous dispatcher errors
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        AppLogger.error(
          'PlatformDispatcher unhandled error: $error',
          tag: 'PlatformDispatcher',
          error: error,
          stackTrace: stack,
        );
        return true; // Marked as handled
      };

      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(TerritoryAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(RunnerProfileAdapter());
      }
      await Hive.openBox<Territory>('territories_v3');
      await Hive.openBox<RunnerProfile>('profile');
      await Hive.openBox<String>('active_run_recovery');

      // Load package metadata
      unawaited(AppVersion.init());

      // Immediately render UI — zero splash screen blocking!
      runApp(const TerritoryApp());

      // Initialize Firebase and push notifications asynchronously in background
      _initServicesAsync();
    },
    (Object error, StackTrace stack) {
      AppLogger.error(
        'Zone-level unhandled exception: $error',
        tag: 'ZoneGuard',
        error: error,
        stackTrace: stack,
      );
    },
  );
}

void _initServicesAsync() async {
  try {
    await FirebaseService().initialize().timeout(const Duration(seconds: 3));
    // Enable Crashlytics in production when Firebase is initialized
    AppLogger.setCrashlyticsEnabled(true);
  } catch (e, st) {
    AppLogger.warning(
      'Firebase init skipped/timed out: $e',
      tag: 'main',
      error: e,
      stackTrace: st,
    );
  }
  try {
    await NotificationService().initialize().timeout(
      const Duration(seconds: 3),
    );
  } catch (e, st) {
    AppLogger.warning(
      'NotificationService init skipped/timed out: $e',
      tag: 'main',
      error: e,
      stackTrace: st,
    );
  }
}

/// Deprecated in U1 for instant, zero-delay run start.
/// Tapping start tracking activates the HUD in one frame (<100ms) with quiet inline status.
@Deprecated('Use instant inline HUD activation instead (U1)')
void showRunStartAnimation(BuildContext context) {}

class TerritoryApp extends StatefulWidget {
  const TerritoryApp({super.key});

  @override
  State<TerritoryApp> createState() => _TerritoryAppState();
}

class _TerritoryAppState extends State<TerritoryApp> {
  bool _isAuthenticated = false;
  bool _hasCompletedOnboarding = true;

  @override
  void initState() {
    super.initState();
    final firebaseService = FirebaseService();
    if (firebaseService.isSignedIn) {
      _isAuthenticated = true;
    } else {
      final profileBox = Hive.box<RunnerProfile>('profile');
      final currentUser = profileBox.get('current_user');
      if (currentUser != null &&
          currentUser.username.isNotEmpty &&
          currentUser.username != 'CyberRunner' &&
          currentUser.username != 'local_runner') {
        _isAuthenticated = true;
      }
    }

    // Check onboarding completion for unauthenticated runners
    SharedPreferences.getInstance().then((prefs) {
      final completed =
          prefs.getBool(OnboardingScreen.prefsKeyCompleted) ?? false;
      if (mounted && !completed && !_isAuthenticated) {
        setState(() {
          _hasCompletedOnboarding = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget homeWidget;
    if (_isAuthenticated) {
      homeWidget = const MainScreen();
    } else if (!_hasCompletedOnboarding) {
      homeWidget = OnboardingScreen(
        onCompleted: () {
          setState(() {
            _hasCompletedOnboarding = true;
          });
        },
      );
    } else {
      homeWidget = AuthScreen(
        onAuthenticated: () {
          setState(() {
            _isAuthenticated = true;
          });
        },
      );
    }

    return MaterialApp(
      scaffoldMessengerKey: AppToast.messengerKey,
      title: 'Territory Runner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: homeWidget,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final Set<int> _loadedTabs = {0};
  StreamSubscription<String>? _notificationSub;

  void _onTabSelected(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
        _loadedTabs.add(index);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _notificationSub = NotificationService().onAttackedTerritoryTapped.listen((
      _,
    ) {
      _onTabSelected(1);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().showPermissionPrimerIfNeeded(context);
    });
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _loadedTabs.contains(0)
              ? HomeScreen(
                  isActive: _selectedIndex == 0,
                  onStartRun: () => _onTabSelected(1),
                )
              : const SizedBox.shrink(),
          _loadedTabs.contains(1)
              ? MapScreenFeature(isActive: _selectedIndex == 1)
              : const SizedBox.shrink(),
          _loadedTabs.contains(2)
              ? const ProfilePage()
              : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: _buildPremiumBottomNav(context),
    );
  }

  Widget _buildPremiumBottomNav(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: 64.0 + bottomPad,
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s6,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Home Tab
              Expanded(
                child: _buildNavTab(
                  index: 0,
                  icon: Icons.bolt_rounded,
                  label: 'Home',
                ),
              ),

              // Prominent Centre Run Action Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                child: Semantics(
                  button: true,
                  label: 'Start Run',
                  child: _CenterRunAction(
                    isSelected: _selectedIndex == 1,
                    onTap: () {
                      AppMotion.heavyBurst();
                      _onTabSelected(1);
                    },
                  ),
                ),
              ),

              // Profile Tab
              Expanded(
                child: _buildNavTab(
                  index: 2,
                  icon: Icons.person_rounded,
                  label: 'Profile',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavTab({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool isSelected = _selectedIndex == index;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: () {
          if (_selectedIndex != index) {
            AppMotion.selectionTick();
            _onTabSelected(index);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.fast),
          curve: AppMotion.easeOut,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentContainer : Colors.transparent,
            borderRadius: AppRadius.brFull,
            border: Border.all(
              color: isSelected
                  ? AppColors.accent.withValues(alpha: 0.3)
                  : Colors.transparent,
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
              const SizedBox(width: AppSpacing.s6),
              Text(
                label,
                style: AppText.labelSmall.copyWith(
                  color: isSelected ? AppColors.accent : AppColors.textMuted,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterRunAction extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _CenterRunAction({required this.isSelected, required this.onTap});

  @override
  State<_CenterRunAction> createState() => _CenterRunActionState();
}

class _CenterRunActionState extends State<_CenterRunAction> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? AppMotion.pressScale : 1.0;

    return AnimatedScale(
      scale: scale,
      duration: AppMotion.duration(context, AppMotion.fast),
      curve: AppMotion.easeOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: AppRadius.brFull,
            border: Border.all(color: AppColors.accent, width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.directions_run_rounded,
                size: 22,
                color: AppColors.onAccent,
              ),
              const SizedBox(width: AppSpacing.s6),
              Text(
                'Run',
                style: AppText.button.copyWith(
                  color: AppColors.onAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
