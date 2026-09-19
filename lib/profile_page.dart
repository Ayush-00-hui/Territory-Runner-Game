import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/gameplay/territory_service.dart';
import 'models/runner_profile.dart';
import 'services/firebase_service.dart';

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
  late final Animation<Offset> _goalsSlideAnimation;
  late final Animation<Offset> _settingsSlideAnimation;

  final TerritoryService _territoryService = TerritoryService();
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
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
        curve: const Interval(0.00, 0.30, curve: Curves.easeOutCubic),
      ),
    );

    _statsSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _pageController,
        curve: const Interval(0.15, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    _achievementsSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _pageController,
        curve: const Interval(0.30, 0.60, curve: Curves.easeOutCubic),
      ),
    );

    _goalsSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _pageController,
        curve: const Interval(0.45, 0.75, curve: Curves.easeOutCubic),
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

  void _showAuthDialog() {
    final phoneController = TextEditingController();
    final otpController = TextEditingController();
    final emailController = TextEditingController();
    final passController = TextEditingController();
    final nameController = TextEditingController();

    int authMode = 0; // 0 = Phone OTP, 1 = Email
    bool isSignUp = false;
    bool codeSent = false;
    String? verificationId;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14151F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_rounded, color: Color(0xFF00F0FF), size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Runner Cloud Login',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Auth Method Selector (Phone OTP vs Email)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1D2A),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  authMode = 0;
                                  codeSent = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: authMode == 0 ? const Color(0xFF00F0FF) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '📱 Phone (SMS OTP)',
                                    style: TextStyle(
                                      color: authMode == 0 ? Colors.black : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  authMode = 1;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: authMode == 1 ? const Color(0xFF00F0FF) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '✉️ Email Login',
                                    style: TextStyle(
                                      color: authMode == 1 ? Colors.black : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (authMode == 0) ...[
                      // --- PHONE OTP MODE ---
                      if (!codeSent) ...[
                        const Text(
                          'Enter your mobile number to receive a one-time SMS verification code:',
                          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Phone Number (with country code e.g. +91...)',
                            labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                            prefixIcon: const Icon(Icons.phone, color: Color(0xFF00F0FF)),
                            filled: true,
                            fillColor: const Color(0xFF1C1D2A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00F0FF),
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: isLoading
                              ? null
                              : () async {
                                  String phone = phoneController.text.trim();
                                  if (phone.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please enter a phone number with country code (e.g. +91...)')),
                                    );
                                    return;
                                  }
                                  if (!phone.startsWith('+')) {
                                    phone = '+$phone';
                                  }
                                  setModalState(() => isLoading = true);
                                  try {
                                    await _firebaseService.verifyPhoneNumber(
                                      phoneNumber: phone,
                                      onCodeSent: (verId) {
                                        setModalState(() {
                                          verificationId = verId;
                                          codeSent = true;
                                          isLoading = false;
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('SMS OTP code sent to $phone')),
                                        );
                                      },
                                      onVerificationFailed: (e) {
                                        setModalState(() => isLoading = false);
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: const Color(0xFF14151F),
                                            title: const Text('Firebase Phone Auth Notice', style: TextStyle(color: Colors.white)),
                                            content: Text(
                                              'Firebase returned: ${e.message ?? e.code}\n\n'
                                              'To fix real SMS OTP:\n'
                                              '1. Add SHA-256 fingerprint in Firebase Console.\n'
                                              '2. Or add "$phone" under Firebase -> Authentication -> Phone numbers for testing (with OTP 123456).\n\n'
                                              'Would you like to continue with Demo Login?',
                                              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx),
                                                child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F0FF), foregroundColor: Colors.black),
                                                onPressed: () async {
                                                  Navigator.pop(ctx);
                                                  final profile = _territoryService.getProfile();
                                                  profile.username = phone;
                                                  await _territoryService.saveProfile(profile);
                                                  if (context.mounted) {
                                                    Navigator.pop(context);
                                                    setState(() {});
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('🎉 Logged in with Phone!')),
                                                    );
                                                  }
                                                },
                                                child: const Text('Demo Login'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      onVerificationCompleted: (cred) async {
                                        setModalState(() => isLoading = false);
                                      },
                                    );
                                  } catch (e) {
                                    setModalState(() => isLoading = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                },
                          child: isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('Send SMS OTP', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ] else ...[
                        Text(
                          'Enter the 6-digit OTP code sent to ${phoneController.text}:',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '••••••',
                            hintStyle: const TextStyle(color: Colors.white24),
                            filled: true,
                            fillColor: const Color(0xFF1C1D2A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00F0FF),
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: isLoading
                              ? null
                              : () async {
                                  final smsCode = otpController.text.trim();
                                  if (smsCode.length < 6 || verificationId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please enter the 6-digit code')),
                                    );
                                    return;
                                  }
                                  setModalState(() => isLoading = true);
                                  try {
                                    await _firebaseService.signInWithOtp(verificationId!, smsCode);
                                    final profile = _territoryService.getProfile();
                                    profile.username = phoneController.text.trim();
                                    await _territoryService.saveProfile(profile);

                                    if (context.mounted) {
                                      Navigator.pop(ctx);
                                      setState(() {});
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('🎉 Logged in & synced successfully!')),
                                      );
                                    }
                                  } catch (e) {
                                    setModalState(() => isLoading = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Verification error: $e')),
                                    );
                                  }
                                },
                          child: isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('Verify OTP & Enter Grid', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() => codeSent = false);
                          },
                          child: const Center(
                            child: Text('Change Phone Number', style: TextStyle(color: Color(0xFF00F0FF))),
                          ),
                        ),
                      ],
                    ] else ...[
                      // --- EMAIL MODE ---
                      if (isSignUp) ...[
                        TextField(
                          controller: nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Runner Nickname',
                            labelStyle: const TextStyle(color: Colors.white60),
                            filled: true,
                            fillColor: const Color(0xFF1C1D2A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      TextField(
                        controller: emailController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: const TextStyle(color: Colors.white60),
                          filled: true,
                          fillColor: const Color(0xFF1C1D2A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: passController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(color: Colors.white60),
                          filled: true,
                          fillColor: const Color(0xFF1C1D2A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00F0FF),
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          try {
                            if (isSignUp) {
                              await _firebaseService.signUpWithEmail(
                                emailController.text.trim(),
                                passController.text.trim(),
                                nameController.text.trim().isEmpty ? 'CyberRunner' : nameController.text.trim(),
                              );
                            } else {
                              await _firebaseService.signInWithEmail(
                                emailController.text.trim(),
                                passController.text.trim(),
                              );
                            }
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('🎉 Logged in & synced successfully!')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Auth error: $e')),
                              );
                            }
                          }
                        },
                        child: Text(
                          isSignUp ? 'Create Cloud Account' : 'Log In with Email',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            isSignUp = !isSignUp;
                          });
                        },
                        child: Center(
                          child: Text(
                            isSignUp ? 'Already have an account? Sign In' : 'New runner? Create Account',
                            style: const TextStyle(color: Color(0xFF00F0FF)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bg = Color(0xFF090A0F);
    const Color card = Color(0xFF14151F);
    const Color softCard = Color(0xFF1C1D2A);
    const Color accent = Color(0xFF00F0FF);
    const Color accent2 = Color(0xFF8A2BE2);
    const Color textPrimary = Color(0xFFF8FAFC);
    const Color textSecondary = Color(0xFFA0AEC0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text(
          'Runner Profile',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync, color: accent),
            onPressed: _showAuthDialog,
            tooltip: 'Cloud Sync / Auth',
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<RunnerProfile>('profile').listenable(),
        builder: (context, Box<RunnerProfile> profileBox, _) {
          final profile = _territoryService.getProfile();
          final int nextLevelXp = profile.level * 250;
          final double xpProgress = (profile.xp / nextLevelXp).clamp(0.0, 1.0);
          final territoriesCount = _territoryService.getCapturedTerritories().length;

          return FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SlideTransition(
                    position: _topSlideAnimation,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1D2440), Color(0xFF11182B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                height: 72,
                                width: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [accent, accent2],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withValues(alpha: 0.35),
                                      blurRadius: 20,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    profile.username.isNotEmpty ? profile.username[0].toUpperCase() : 'C',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile.username,
                                      style: const TextStyle(
                                        color: textPrimary,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Territory Runner • Level ${profile.level}',
                                      style: const TextStyle(
                                        color: textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${profile.totalHexesClaimed} Hexagons Claimed',
                                      style: const TextStyle(
                                        color: textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.local_fire_department,
                                      color: Colors.orange,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${profile.currentStreak}',
                                      style: const TextStyle(
                                        color: textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'XP Progress',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${profile.xp} / $nextLevelXp XP',
                                    style: const TextStyle(
                                      color: textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: LinearProgressIndicator(
                                  value: xpProgress,
                                  minHeight: 10,
                                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Overview',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  SlideTransition(
                    position: _statsSlideAnimation,
                    child: GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.45,
                      children: [
                        _StatCard(
                          icon: Icons.route,
                          title: 'Total Distance',
                          value: '${profile.totalDistanceKm.toStringAsFixed(1)} km',
                          delay: 0,
                        ),
                        _StatCard(
                          icon: Icons.bolt,
                          title: 'Current Streak',
                          value: '${profile.currentStreak} Days',
                          delay: 100,
                        ),
                        _StatCard(
                          icon: Icons.map,
                          title: 'Territories',
                          value: '$territoriesCount Hexes',
                          delay: 200,
                        ),
                        _StatCard(
                          icon: Icons.military_tech,
                          title: 'Level & Tier',
                          value: 'Lvl ${profile.level}',
                          delay: 300,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Achievements & Badges',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  SlideTransition(
                    position: _achievementsSlideAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        children: [
                          _AchievementTile(
                            icon: Icons.emoji_events,
                            title: 'First Conquest',
                            subtitle: 'Claim your first hexagonal sector',
                            unlocked: profile.badges.contains('First Conquest'),
                          ),
                          const SizedBox(height: 10),
                          _AchievementTile(
                            icon: Icons.local_fire_department,
                            title: 'Sector Commander',
                            subtitle: 'Claim 25 unique hexagonal territories',
                            unlocked: profile.badges.contains('Sector Commander'),
                          ),
                          const SizedBox(height: 10),
                          _AchievementTile(
                            icon: Icons.public,
                            title: '10K Centurion',
                            subtitle: 'Log over 10.0 total kilometers on foot',
                            unlocked: profile.badges.contains('10K Centurion'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Settings & Cloud',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  SlideTransition(
                    position: _settingsSlideAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        children: [
                          _OptionTile(
                            icon: Icons.cloud_done_outlined,
                            title: _firebaseService.isInitialized
                                ? 'Firebase Connected (${_firebaseService.currentUsername})'
                                : 'Offline Storage (Tap to Sign In)',
                            onTap: _showAuthDialog,
                          ),
                          const Divider(height: 1, color: Color(0x22FFFFFF)),
                          _OptionTile(
                            icon: Icons.refresh,
                            title: 'Reset Local Territories (Dev)',
                            onTap: () async {
                              await _territoryService.resetTerritories();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Territories reset.')),
                                );
                              }
                            },
                          ),
                        ],
                      ),
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final int delay;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    const Color card = Color(0xFF14151F);
    const Color textPrimary = Colors.white;
    const Color textSecondary = Color(0xFFA0AEC0);
    const Color accent = Color(0xFF00F0FF);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1.0),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 22),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool unlocked;

  const _AchievementTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    const Color textPrimary = Colors.white;
    const Color textSecondary = Color(0xFFA0AEC0);

    final Color iconBg =
        unlocked ? const Color(0xFF00F0FF) : Colors.white.withValues(alpha: 0.06);
    final Color iconColor = unlocked ? Colors.black : Colors.grey;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            unlocked ? Icons.check_circle : Icons.lock_outline,
            color: unlocked ? const Color(0xFF00F0FF) : Colors.grey,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color titleColor = Colors.white;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF00F0FF)),
        title: Text(
          title,
          style: const TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: titleColor.withValues(alpha: 0.5),
        ),
        onTap: onTap,
      ),
    );
  }
}