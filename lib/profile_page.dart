import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/gameplay/territory_service.dart';
import 'models/runner_profile.dart';
import 'services/firebase_service.dart';
import 'main.dart'; // For AppColors

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
      backgroundColor: AppColors.bgElevated,
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
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.sports_score_rounded, color: AppColors.accent, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'ATHLETE CLOUD SYNC',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white60),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Auth Method Selector (Phone OTP vs Email)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
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
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  color: authMode == 0 ? AppColors.accent : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '📱 Mobile OTP',
                                    style: TextStyle(
                                      color: authMode == 0 ? Colors.black : AppColors.textSecondary,
                                      fontWeight: FontWeight.w800,
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
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  color: authMode == 1 ? AppColors.accent : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '✉️ Email Login',
                                    style: TextStyle(
                                      color: authMode == 1 ? Colors.black : AppColors.textSecondary,
                                      fontWeight: FontWeight.w800,
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
                          'Enter your mobile number to verify your runner profile and sync conquered sectors:',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Mobile Number (+ country code e.g. +91...)',
                            labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            prefixIcon: const Icon(Icons.phone_iphone, color: AppColors.accent),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(52),
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
                                            backgroundColor: AppColors.surface,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            title: const Text('Athlete Auth Notice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            content: Text(
                                              'Firebase returned: ${e.message ?? e.code}\n\n'
                                              'To authenticate seamlessly in testing, you can tap Demo Login below.',
                                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx),
                                                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
                                                onPressed: () async {
                                                  Navigator.pop(ctx);
                                                  final profile = _territoryService.getProfile();
                                                  profile.username = phone;
                                                  await _territoryService.saveProfile(profile);
                                                  if (context.mounted) {
                                                    Navigator.pop(context);
                                                    setState(() {});
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('⚡ Athlete Profile Synced!')),
                                                    );
                                                  }
                                                },
                                                child: const Text('Demo Login', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: $e')),
                                      );
                                    }
                                  }
                                },
                          child: isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('Send SMS Verification Code', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                        ),
                      ] else ...[
                        Text(
                          'Enter the 6-digit OTP code sent to ${phoneController.text}:',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '••••••',
                            hintStyle: const TextStyle(color: Colors.white24),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(52),
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
                                        const SnackBar(content: Text('⚡ Athlete Profile Synced & Connected!')),
                                      );
                                    }
                                  } catch (e) {
                                    setModalState(() => isLoading = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Verification error: $e')),
                                      );
                                    }
                                  }
                                },
                          child: isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('Verify Code & Connect', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() => codeSent = false);
                          },
                          child: const Center(
                            child: Text('Change Phone Number', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
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
                            labelText: 'Athlete Display Name',
                            labelStyle: const TextStyle(color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: emailController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: const TextStyle(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          try {
                            if (isSignUp) {
                              await _firebaseService.signUpWithEmail(
                                emailController.text.trim(),
                                passController.text.trim(),
                                nameController.text.trim().isEmpty ? 'StrideRunner' : nameController.text.trim(),
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
                                const SnackBar(content: Text('⚡ Athlete Account Synced!')),
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
                          isSignUp ? 'Create Athlete Profile' : 'Log In with Email',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            isSignUp = !isSignUp;
                          });
                        },
                        child: Center(
                          child: Text(
                            isSignUp ? 'Already registered? Log In' : 'New runner? Create Profile',
                            style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
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

  void _showEditCallsignDialog(RunnerProfile profile) {
    final controller = TextEditingController(text: profile.username);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.badge_rounded, color: AppColors.accent, size: 22),
            SizedBox(width: 8),
            Text('Edit Athlete Callsign', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose your cyber runner callsign broadcasted to rival factions on the grid:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              maxLength: 20,
              decoration: InputDecoration(
                labelText: 'Callsign / Nickname',
                labelStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                profile.username = newName;
                await _territoryService.saveProfile(profile);
                if (!mounted) return;
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.surface,
                    content: Text('Callsign updated to "$newName" ⚡', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                  ),
                );
              }
            },
            child: const Text('Save Callsign', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _showFactionSelectionDialog(RunnerProfile profile) {
    final factions = [
      {
        'name': 'Cyber Vanguard',
        'tag': 'SYSTEM GUARDIANS',
        'color': const Color(0xFF00E676),
        'icon': Icons.security_rounded,
        'perk': 'Precision spatial radar & fast polygon enclosure recognition (+10% base claim speed)',
      },
      {
        'name': 'Solar Syndicate',
        'tag': 'KINETIC CONQUERORS',
        'color': const Color(0xFFFF9100),
        'icon': Icons.wb_sunny_rounded,
        'perk': 'Solar endurance surge & stamina battery efficiency (+15% cadence recharge boost)',
      },
      {
        'name': 'Quantum Pulse',
        'tag': 'ANTI-GRAVITY DRIFTERS',
        'color': const Color(0xFF8A2BE2),
        'icon': Icons.bolt_rounded,
        'perk': 'Zero-G sub-orbital glide thrust & +40% sprint momentum conversion multiplier',
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.flag_rounded, color: AppColors.accent, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'FACTION ALIGNMENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Pledge allegiance to a runner syndicate to represent them on the territorial map grid and unlock tactical flight bonuses:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3),
              ),
              const SizedBox(height: 20),
              ...factions.map((f) {
                final isSelected = profile.faction == f['name'];
                final factionColor = f['color'] as Color;
                final factionIcon = f['icon'] as IconData;

                return GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    profile.faction = f['name'] as String;
                    await _territoryService.saveProfile(profile);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    setState(() {});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.surface,
                          content: Text(
                            'Aligned with ${f['name']} Syndicate! ⚡',
                            style: TextStyle(color: factionColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? factionColor.withValues(alpha: 0.15) : AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? factionColor : AppColors.border,
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: factionColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(factionIcon, color: factionColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    f['name'] as String,
                                    style: TextStyle(
                                      color: isSelected ? factionColor : Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: factionColor.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'ACTIVE',
                                        style: TextStyle(color: factionColor, fontSize: 10, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                f['tag'] as String,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                f['perk'] as String,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showStatDetailModal({
    required String title,
    required String value,
    required String description,
    required List<Map<String, String>> metrics,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: metrics.map((m) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(m['label'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text(m['val'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surface2,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CLOSE TELEMETRY', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetailModal({
    required String title,
    required String subtitle,
    required bool unlocked,
    required String criteria,
    required String reward,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (unlocked ? AppColors.accent : AppColors.surface2).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    unlocked ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
                    color: unlocked ? AppColors.accent : Colors.white38,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (unlocked ? AppColors.accent : Colors.white12).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          unlocked ? 'STATUS: UNLOCKED 🏆' : 'STATUS: LOCKED 🔒',
                          style: TextStyle(
                            color: unlocked ? AppColors.accent : AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CRITERIA', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(criteria, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3)),
                  const Divider(color: Colors.white10, height: 20),
                  const Text('CONQUEST REWARD', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(reward, style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: unlocked ? AppColors.accent : AppColors.surface2,
                foregroundColor: unlocked ? Colors.black : Colors.white70,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text(unlocked ? 'CLAIM BADGE' : 'CLOSE', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        title: const Text(
          'ATHLETE HUB',
          style: TextStyle(
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
            onPressed: _showAuthDialog,
            tooltip: 'Cloud Sync',
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
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HERO ATHLETE CARD ---
                  SlideTransition(
                    position: _topSlideAnimation,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.border,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Avatar Badge
                              Container(
                                height: 68,
                                width: 68,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.accent,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accent.withValues(alpha: 0.3),
                                      blurRadius: 18,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    profile.username.isNotEmpty ? profile.username[0].toUpperCase() : 'R',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            profile.username.isNotEmpty ? profile.username.toUpperCase() : 'ATHLETE',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () => _showEditCallsignDialog(profile),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: AppColors.surface2,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: AppColors.border),
                                            ),
                                            child: const Icon(Icons.edit_rounded, color: AppColors.accent, size: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.surface2,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'LEVEL ${profile.level} ATHLETE',
                                            style: const TextStyle(
                                              color: AppColors.accent,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.6,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => _showFactionSelectionDialog(profile),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF8A2BE2).withValues(alpha: 0.25),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFF8A2BE2), width: 1.0),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.shield_rounded, color: Color(0xFF00F0FF), size: 11),
                                                const SizedBox(width: 4),
                                                Text(
                                                  profile.faction.isNotEmpty ? profile.faction : 'FACTION',
                                                  style: const TextStyle(
                                                    color: Color(0xFF00F0FF),
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Streak Flame Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.local_fire_department,
                                      color: AppColors.secondary,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${profile.currentStreak}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          // Tier Progression Bar
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'TIER PROGRESSION',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  Text(
                                    '${profile.xp} / $nextLevelXp XP',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: xpProgress,
                                  minHeight: 8,
                                  backgroundColor: AppColors.surface2,
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- METRIC OVERVIEW GRID ---
                  const Text(
                    'PERFORMANCE TELEMETRY',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
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
                          icon: Icons.route_rounded,
                          title: 'TOTAL DISTANCE',
                          value: '${profile.totalDistanceKm.toStringAsFixed(1)} KM',
                          iconColor: AppColors.accent,
                          delay: 0,
                          onTap: () {
                            _showStatDetailModal(
                              title: 'DISTANCE TELEMETRY',
                              value: '${profile.totalDistanceKm.toStringAsFixed(2)} KM',
                              description: 'Cumulative GPS route distance logged on foot across urban and wilderness sectors.',
                              metrics: [
                                {'label': 'Lifetime Distance', 'val': '${profile.totalDistanceKm.toStringAsFixed(2)} km'},
                                {'label': 'Weekly Estimated', 'val': '${(profile.totalDistanceKm / 4).toStringAsFixed(1)} km/wk'},
                                {'label': 'Pace Rating', 'val': 'Active Runner'},
                              ],
                            );
                          },
                        ),
                        _StatCard(
                          icon: Icons.local_fire_department_rounded,
                          title: 'ACTIVE STREAK',
                          value: '${profile.currentStreak} DAYS',
                          iconColor: AppColors.secondary,
                          delay: 80,
                          onTap: () {
                            _showStatDetailModal(
                              title: 'STREAK TELEMETRY',
                              value: '${profile.currentStreak} DAYS',
                              description: 'Continuous daily conquest momentum. Running and claiming territory daily keeps your streak active.',
                              metrics: [
                                {'label': 'Active Streak Days', 'val': '${profile.currentStreak} days'},
                                {'label': 'Streak Multiplier Bonus', 'val': '+${(profile.currentStreak * 2).clamp(0, 50)}% XP'},
                                {'label': 'Status', 'val': 'Active Momentum 🔥'},
                              ],
                            );
                          },
                        ),
                        _StatCard(
                          icon: Icons.terrain_rounded,
                          title: 'TOTAL TERRITORY',
                          value: () {
                            final captured = _territoryService.getCapturedTerritoryObjects();
                            final double totalAreaM2 = captured.fold(0.0, (sum, t) => sum + t.areaSqMeters);
                            if (totalAreaM2 >= 10000) {
                              return '${(totalAreaM2 / 1000000.0).toStringAsFixed(2)} KM²';
                            }
                            return '${totalAreaM2.toStringAsFixed(0)} M²';
                          }(),
                          iconColor: AppColors.accent,
                          delay: 160,
                          onTap: () {
                            final captured = _territoryService.getCapturedTerritoryObjects();
                            final double totalAreaM2 = captured.fold(0.0, (sum, t) => sum + t.areaSqMeters);
                            _showStatDetailModal(
                              title: 'TERRITORY TELEMETRY',
                              value: '${(totalAreaM2 / 1000000.0).toStringAsFixed(3)} KM²',
                              description: 'Post-union sovereign territory polygons permanently claimed on foot.',
                              metrics: [
                                {'label': 'Captured Polygons', 'val': '${captured.length} sectors'},
                                {'label': 'Controlled Area', 'val': '${(totalAreaM2 / 1000000.0).toStringAsFixed(3)} km²'},
                                {'label': 'Square Meters', 'val': '${totalAreaM2.toStringAsFixed(0)} m²'},
                              ],
                            );
                          },
                        ),
                        _StatCard(
                          icon: Icons.military_tech_rounded,
                          title: 'ATHLETE TIER',
                          value: 'LVL ${profile.level}',
                          iconColor: AppColors.accent,
                          delay: 240,
                          onTap: () {
                            _showStatDetailModal(
                              title: 'RANK & TIER TELEMETRY',
                              value: 'LEVEL ${profile.level}',
                              description: 'Athlete experience tier. Progressing tiers grants improved sector claim speed and prestige insignia.',
                              metrics: [
                                {'label': 'Current Level', 'val': 'Level ${profile.level}'},
                                {'label': 'Experience Points', 'val': '${profile.xp} / ${profile.level * 250} XP'},
                                {'label': 'Perks Unlocked', 'val': 'Territory Sovereign, Speed Burst'},
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- TROPHY CASE & ACHIEVEMENTS ---
                  const Text(
                    'TROPHY CASE & BADGES',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),

                  SlideTransition(
                    position: _achievementsSlideAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _AchievementTile(
                            icon: Icons.emoji_events_rounded,
                            title: 'First Conquest',
                            subtitle: 'Claim your first territory polygon on foot',
                            unlocked: profile.badges.contains('First Conquest') || territoriesCount >= 1,
                            onTap: () {
                              _showBadgeDetailModal(
                                title: 'First Conquest',
                                subtitle: 'Claim your first territory polygon on foot',
                                unlocked: profile.badges.contains('First Conquest') || territoriesCount >= 1,
                                criteria: 'Enclose and claim at least 1 real-world polygon in GPS tracking mode.',
                                reward: '+50 XP, "Pioneer Runner" Title',
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _AchievementTile(
                            icon: Icons.military_tech_rounded,
                            title: 'Territory Sovereign',
                            subtitle: 'Conquer over 10,000 m² of sovereign ground',
                            unlocked: profile.badges.contains('Territory Sovereign') || profile.badges.contains('Sector Commander') || territoriesCount >= 5,
                            onTap: () {
                              _showBadgeDetailModal(
                                title: 'Territory Sovereign',
                                subtitle: 'Conquer over 10,000 m² of sovereign ground',
                                unlocked: profile.badges.contains('Territory Sovereign') || profile.badges.contains('Sector Commander') || territoriesCount >= 5,
                                criteria: 'Enclose and secure vast contiguous territory polygons.',
                                reward: '+200 XP, "Sovereign Runner" Faction Insignia',
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _AchievementTile(
                            icon: Icons.bolt_rounded,
                            title: '10K Centurion',
                            subtitle: 'Log over 10.0 total kilometers on foot',
                            unlocked: profile.badges.contains('10K Centurion') || profile.totalDistanceKm >= 10.0,
                            onTap: () {
                              _showBadgeDetailModal(
                                title: '10K Centurion',
                                subtitle: 'Log over 10.0 total kilometers on foot',
                                unlocked: profile.badges.contains('10K Centurion') || profile.totalDistanceKm >= 10.0,
                                criteria: 'Complete a cumulative 10.0 km of running or walking.',
                                reward: '+300 XP, 10K Centurion Cyber Wings',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- SETTINGS & DATA SYNC ---
                  const Text(
                    'DATA & PLATFORM',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),

                  SlideTransition(
                    position: _settingsSlideAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _OptionTile(
                            icon: Icons.cloud_done_rounded,
                            title: _firebaseService.isInitialized
                                ? 'Cloud Connected (${_firebaseService.currentUsername})'
                                : 'Offline Local Storage (Tap to Sync)',
                            onTap: _showAuthDialog,
                          ),
                          const Divider(height: 1, color: AppColors.border),
                          _OptionTile(
                            icon: Icons.refresh_rounded,
                            title: 'Reset Local Territories (Dev Mode)',
                            onTap: () async {
                              await _territoryService.resetTerritories();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Territories reset to initial grid.')),
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
  final Color iconColor;
  final int delay;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.iconColor,
    required this.delay,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1.0),
      duration: Duration(milliseconds: 400 + delay),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: () {
          if (onTap != null) {
            HapticFeedback.selectionClick();
            onTap!();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  const Icon(Icons.info_outline_rounded, color: Colors.white24, size: 14),
                ],
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
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
  final VoidCallback? onTap;

  const _AchievementTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.unlocked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconBg =
        unlocked ? AppColors.accent : AppColors.surface2;
    final Color iconColor = unlocked ? Colors.black : Colors.white30;

    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          HapticFeedback.selectionClick();
          onTap!();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface2.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: unlocked ? AppColors.accent.withValues(alpha: 0.3) : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
              color: unlocked ? AppColors.accent : Colors.white24,
              size: 20,
            ),
          ],
        ),
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
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: AppColors.accent, size: 22),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: AppColors.textMuted,
        ),
        onTap: onTap,
      ),
    );
  }
}