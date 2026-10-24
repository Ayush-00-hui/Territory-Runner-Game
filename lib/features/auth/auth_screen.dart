import 'package:flutter/material.dart';

import '../../services/firebase_service.dart';
import '../gameplay/territory_service.dart';
import '../../ui/ui.dart';

/// Redesigned Athlete Authentication Screen with Charcoal + Ember aesthetic.
/// Supports Google One-Tap, Email & Password, Phone SMS OTP, and Instant Guest Access.
class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TerritoryService _territoryService = TerritoryService();

  int _selectedTab = 0; // 0 = Google / One-Tap, 1 = Email, 2 = Phone OTP
  bool _isLoading = false;
  String? _errorMessage;

  // Email controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;

  // Phone controllers
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String? _verificationId;
  bool _codeSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _finishAuth(String displayName) {
    if (displayName.isNotEmpty) {
      try {
        final profile = _territoryService.getProfile();
        profile.username = displayName;
        _territoryService.saveProfile(profile);
      } catch (e) {
        AppLogger.warning('Notice saving profile: $e', tag: 'AuthScreen');
      }
    }
    widget.onAuthenticated();
    if (!mounted) return;
    AppToast.show(
      context,
      'Welcome, $displayName!',
      type: AppToastType.success,
      icon: Icons.check_circle_rounded,
    );
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    if (mounted) {
      AppToast.show(
        context,
        message,
        type: AppToastType.error,
        icon: Icons.error_outline_rounded,
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cred = await _firebaseService.signInWithGoogle();
      if (cred != null) {
        final name =
            cred.user?.displayName ??
            cred.user?.email?.split('@').first ??
            'Runner';
        _finishAuth(name);
      }
    } catch (e) {
      _showError(
        'Google Sign-In notice: $e\n\n(Tip: Ensure SHA-1 is added in Firebase Console)',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter both email and password.');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUp) {
        final cred = await _firebaseService.signUpWithEmail(
          email,
          password,
          name.isNotEmpty ? name : email.split('@').first,
        );
        if (cred != null) {
          _finishAuth(name.isNotEmpty ? name : email.split('@').first);
        }
      } else {
        final cred = await _firebaseService.signInWithEmail(email, password);
        if (cred != null) {
          _finishAuth(cred.user?.displayName ?? email.split('@').first);
        }
      }
    } catch (e) {
      _showError('Authentication failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendPhoneOtp() async {
    String phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showError('Please enter a valid phone number.');
      return;
    }
    if (!phone.startsWith('+')) {
      phone = '+$phone';
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _firebaseService.verifyPhoneNumber(
        phoneNumber: phone,
        onCodeSent: (verId) {
          if (mounted) {
            setState(() {
              _verificationId = verId;
              _codeSent = true;
              _isLoading = false;
            });
            AppToast.show(
              context,
              'SMS verification code sent to $phone',
              type: AppToastType.info,
            );
          }
        },
        onVerificationFailed: (e) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showError('Phone verification failed: ${e.message ?? e.code}');
          }
        },
        onVerificationCompleted: (cred) async {
          if (mounted) {
            setState(() => _isLoading = false);
            _finishAuth(phone);
          }
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error sending OTP: $e');
    }
  }

  Future<void> _verifyPhoneOtp() async {
    final code = _otpController.text.trim();
    if (code.length < 6 || _verificationId == null) {
      _showError('Please enter the 6-digit OTP code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cred = await _firebaseService.signInWithOtp(_verificationId!, code);
      if (cred != null) {
        _finishAuth(_phoneController.text.trim());
      }
    } catch (e) {
      _showError('Invalid OTP code: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleGuestContinue() {
    AppMotion.selectionTick();
    _finishAuth('Athlete');
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s24,
            topPad > 0 ? AppSpacing.s12 : AppSpacing.s24,
            AppSpacing.s24,
            AppSpacing.s24,
          ),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- APP LOGO & BRAND HEADER ---
              Row(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: AppColors.accentContainer,
                      borderRadius: AppRadius.br16,
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                      boxShadow: AppElevation.floating,
                    ),
                    child: const Icon(
                      Icons.terrain_rounded,
                      color: AppColors.accent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TERRITORY RUNNER',
                        style: AppText.headingSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Claim real-world territory on foot',
                        style: AppText.label.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.s32),

              // Title & Subtitle
              Text(
                'Athlete Access',
                style: AppText.headingLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.s6),
              Text(
                'Sync your claimed territories, weekly league standing, and badges across devices.',
                style: AppText.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: AppSpacing.s24),

              // --- TAB SELECTOR (Google / Email / Phone) ---
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.br16,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    _buildTabPill(0, Icons.bolt_rounded, 'One-Tap'),
                    _buildTabPill(1, Icons.mail_outline_rounded, 'Email'),
                    _buildTabPill(2, Icons.phone_android_rounded, 'Phone OTP'),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.s20),

              // Error Banner if present
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: AppRadius.br12,
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.s10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppText.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
              ],

              // --- TAB CONTENT ---
              if (_selectedTab == 0) ...[
                // --- GOOGLE SIGN IN TAB ---
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.account_circle_outlined,
                          color: AppColors.accent,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s14),
                      Text(
                        'Instant Google Sign-In',
                        style: AppText.headingSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      Text(
                        'Authenticate securely with your verified Google account to claim your runner callsign instantly.',
                        textAlign: TextAlign.center,
                        style: AppText.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s20),
                      PrimaryButton(
                        label: 'Continue with Google',
                        icon: Icons.login_rounded,
                        isLoading: _isLoading,
                        onPressed: _handleGoogleSignIn,
                      ),
                    ],
                  ),
                ),
              ] else if (_selectedTab == 1) ...[
                // --- EMAIL & PASSWORD TAB ---
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isSignUp) ...[
                        _buildInputField(
                          controller: _nameController,
                          label: 'Athlete Callsign / Name',
                          hintText: 'e.g. ApexStrider',
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: AppSpacing.s14),
                      ],
                      _buildInputField(
                        controller: _emailController,
                        label: 'Email Address',
                        hintText: 'runner@domain.com',
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: AppSpacing.s14),
                      _buildInputField(
                        controller: _passwordController,
                        label: 'Password (min 6 characters)',
                        hintText: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s20),
                      PrimaryButton(
                        label: _isSignUp
                            ? 'Create Athlete Account'
                            : 'Log In with Email',
                        icon: _isSignUp
                            ? Icons.person_add_alt_1_rounded
                            : Icons.login_rounded,
                        isLoading: _isLoading,
                        onPressed: _handleEmailAuth,
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            AppMotion.selectionTick();
                            setState(() {
                              _isSignUp = !_isSignUp;
                              _errorMessage = null;
                            });
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s12,
                              vertical: AppSpacing.s6,
                            ),
                            child: Text(
                              _isSignUp
                                  ? 'Already registered? Log In'
                                  : 'New to Territory Runner? Create Account',
                              style: AppText.label.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // --- PHONE OTP TAB ---
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_codeSent) ...[
                        Text(
                          'Enter mobile number with country code (e.g. +91 98765 43210):',
                          style: AppText.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s14),
                        _buildInputField(
                          controller: _phoneController,
                          label: 'Phone Number',
                          hintText: '+91 98765 43210',
                          icon: Icons.phone_iphone_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: AppSpacing.s20),
                        PrimaryButton(
                          label: 'Send SMS OTP Code',
                          icon: Icons.sms_rounded,
                          isLoading: _isLoading,
                          onPressed: _sendPhoneOtp,
                        ),
                      ] else ...[
                        Text(
                          'Enter 6-digit OTP code sent to ${_phoneController.text}:',
                          style: AppText.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s14),
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: AppText.headingMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 24,
                            letterSpacing: 8,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '••••••',
                            hintStyle: TextStyle(
                              color: AppColors.textMuted.withValues(alpha: 0.5),
                              letterSpacing: 8,
                            ),
                            filled: true,
                            fillColor: AppColors.surface2,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.s16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.br12,
                              borderSide: const BorderSide(
                                color: AppColors.borderSubtle,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: AppRadius.br12,
                              borderSide: const BorderSide(
                                color: AppColors.borderSubtle,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: AppRadius.br12,
                              borderSide: const BorderSide(
                                color: AppColors.accent,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s20),
                        PrimaryButton(
                          label: 'Verify & Enter Grid',
                          icon: Icons.check_circle_outline_rounded,
                          isLoading: _isLoading,
                          onPressed: _verifyPhoneOtp,
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              AppMotion.selectionTick();
                              setState(() => _codeSent = false);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s12,
                                vertical: AppSpacing.s6,
                              ),
                              child: Text(
                                'Change Phone Number',
                                style: AppText.label.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.s24),

              // --- QUICK START / GUEST FALLBACK ---
              Center(
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(
                            color: AppColors.borderSubtle,
                            height: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s12,
                          ),
                          child: Text(
                            'OR',
                            style: AppText.labelSmall.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(
                            color: AppColors.borderSubtle,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    SecondaryButton(
                      label: 'Continue as Guest (Instant Play)',
                      icon: Icons.directions_run_rounded,
                      onPressed: _handleGuestContinue,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.labelSmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.s6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: AppText.bodyMedium.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppText.bodyMedium.copyWith(
              color: AppColors.textMuted.withValues(alpha: 0.6),
            ),
            prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.surface2,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s14,
            ),
            border: OutlineInputBorder(
              borderRadius: AppRadius.br12,
              borderSide: const BorderSide(color: AppColors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.br12,
              borderSide: const BorderSide(color: AppColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.br12,
              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabPill(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          AppMotion.selectionTick();
          setState(() {
            _selectedTab = index;
            _errorMessage = null;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface2 : Colors.transparent,
            borderRadius: AppRadius.br12,
            border: isSelected
                ? Border.all(
                    color: AppColors.accent.withValues(alpha: 0.6),
                    width: 1.0,
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? AppColors.accent : AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.s6),
              Text(
                label,
                style: AppText.label.copyWith(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
