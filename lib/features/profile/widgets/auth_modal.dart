import 'package:flutter/material.dart';

import '../../gameplay/territory_service.dart';
import '../../../services/firebase_service.dart';
import '../../../ui/ui.dart';

void showProfileAuthModal(
  BuildContext context, {
  required FirebaseService firebaseService,
  required TerritoryService territoryService,
  required VoidCallback onProfileUpdated,
}) {
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

  AppSheet.show(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.disabled,
                        borderRadius: AppRadius.brFull,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.sports_score_rounded,
                            color: AppColors.accent,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'ATHLETE CLOUD SYNC',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
                        ),
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
                                color: authMode == 0
                                    ? AppColors.accent
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  'Phone OTP',
                                  style: TextStyle(
                                    color: authMode == 0
                                        ? AppColors.onAccent
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
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
                                color: authMode == 1
                                    ? AppColors.accent
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  'Email',
                                  style: TextStyle(
                                    color: authMode == 1
                                        ? AppColors.onAccent
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
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
                        'Enter your mobile number to verify your runner profile and sync claimed territories:',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              'Mobile Number (+ country code e.g. +91...)',
                          labelStyle: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                          prefixIcon: const Icon(
                            Icons.phone_iphone,
                            color: AppColors.accent,
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.accent,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.onAccent,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
                                String phone = phoneController.text.trim();
                                if (phone.isEmpty) {
                                  AppToast.show(
                                    context,
                                    'Please enter a phone number with country code (e.g. +91...)',
                                    type: AppToastType.warning,
                                  );
                                  return;
                                }
                                if (!phone.startsWith('+')) {
                                  phone = '+$phone';
                                }
                                setModalState(() => isLoading = true);
                                try {
                                  await firebaseService.verifyPhoneNumber(
                                    phoneNumber: phone,
                                    onCodeSent: (verId) {
                                      setModalState(() {
                                        verificationId = verId;
                                        codeSent = true;
                                        isLoading = false;
                                      });
                                      AppToast.show(
                                        context,
                                        'SMS OTP code sent to $phone',
                                        type: AppToastType.success,
                                      );
                                    },
                                    onVerificationFailed: (e) {
                                      setModalState(() => isLoading = false);
                                      showDialog(
                                        context: context,
                                        builder: (dialogCtx) => AlertDialog(
                                          backgroundColor: AppColors.surface,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          title: const Text(
                                            'Athlete Auth Notice',
                                            style: TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          content: Text(
                                            'Firebase returned: ${e.message ?? e.code}\n\n'
                                            'To authenticate seamlessly in testing, you can tap Demo Login below.',
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 13,
                                              height: 1.4,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(dialogCtx),
                                              child: const Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.accent,
                                                foregroundColor:
                                                    AppColors.onAccent,
                                              ),
                                              onPressed: () async {
                                                Navigator.pop(dialogCtx);
                                                final profile = territoryService
                                                    .getProfile();
                                                profile.username = phone;
                                                await territoryService
                                                    .saveProfile(profile);
                                                if (context.mounted) {
                                                  Navigator.pop(ctx);
                                                  onProfileUpdated();
                                                  AppToast.show(
                                                    context,
                                                    '⚡ Athlete Profile Synced!',
                                                    type: AppToastType.success,
                                                  );
                                                }
                                              },
                                              child: const Text(
                                                'Demo Login',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
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
                                    AppToast.show(
                                      context,
                                      'Error: $e',
                                      type: AppToastType.error,
                                    );
                                  }
                                }
                              },
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onAccent,
                                ),
                              )
                            : const Text(
                                'Send SMS Verification Code',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ] else ...[
                      Text(
                        'Enter the 6-digit OTP code sent to ${phoneController.text}:',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '••••••',
                          hintStyle: const TextStyle(color: AppColors.disabled),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.accent,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.onAccent,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
                                final smsCode = otpController.text.trim();
                                if (smsCode.length < 6 ||
                                    verificationId == null) {
                                  AppToast.show(
                                    context,
                                    'Please enter the 6-digit code',
                                    type: AppToastType.warning,
                                  );
                                  return;
                                }
                                setModalState(() => isLoading = true);
                                try {
                                  await firebaseService.signInWithOtp(
                                    verificationId!,
                                    smsCode,
                                  );
                                  final profile = territoryService.getProfile();
                                  profile.username = phoneController.text
                                      .trim();
                                  await territoryService.saveProfile(profile);

                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    onProfileUpdated();
                                    AppToast.show(
                                      context,
                                      '⚡ Athlete Profile Synced & Connected!',
                                      type: AppToastType.success,
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isLoading = false);
                                  if (context.mounted) {
                                    AppToast.show(
                                      context,
                                      'Verification error: $e',
                                      type: AppToastType.error,
                                    );
                                  }
                                }
                              },
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onAccent,
                                ),
                              )
                            : const Text(
                                'Verify Code & Connect',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() => codeSent = false);
                        },
                        child: const Center(
                          child: Text(
                            'Change Phone Number',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ] else ...[
                    // --- EMAIL MODE ---
                    if (isSignUp) ...[
                      TextField(
                        controller: nameController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Athlete Display Name',
                          labelStyle: const TextStyle(
                            color: AppColors.textMuted,
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.accent,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: emailController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: const TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.accent,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passController,
                      obscureText: true,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.accent,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        try {
                          if (isSignUp) {
                            await firebaseService.signUpWithEmail(
                              emailController.text.trim(),
                              passController.text.trim(),
                              nameController.text.trim().isEmpty
                                  ? 'StrideRunner'
                                  : nameController.text.trim(),
                            );
                          } else {
                            await firebaseService.signInWithEmail(
                              emailController.text.trim(),
                              passController.text.trim(),
                            );
                          }
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            onProfileUpdated();
                            AppToast.show(
                              context,
                              '⚡ Athlete Account Synced!',
                              type: AppToastType.success,
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            AppToast.show(
                              context,
                              'Auth error: $e',
                              type: AppToastType.error,
                            );
                          }
                        }
                      },
                      child: Text(
                        isSignUp
                            ? 'Create Athlete Profile'
                            : 'Log In with Email',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
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
                          isSignUp
                              ? 'Already registered? Log In'
                              : 'New runner? Create Profile',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.bold,
                          ),
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
