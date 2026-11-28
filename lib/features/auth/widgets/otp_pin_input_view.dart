import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/ui.dart';

/// Interactive 6-digit athletic PIN verification view with auto-advance and resend timer.
class OtpPinInputView extends StatefulWidget {
  final ValueChanged<String> onCompleted;
  final VoidCallback onResend;
  final String formattedPhone;
  final int resendTimeoutSeconds;

  const OtpPinInputView({
    super.key,
    required this.onCompleted,
    required this.onResend,
    required this.formattedPhone,
    this.resendTimeoutSeconds = 45,
  });

  @override
  State<OtpPinInputView> createState() => _OtpPinInputViewState();
}

class _OtpPinInputViewState extends State<OtpPinInputView> {
  static const int _pinLength = 6;
  final List<TextEditingController> _controllers = List.generate(
    _pinLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _pinLength,
    (_) => FocusNode(),
  );

  int _countdown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    setState(() => _countdown = widget.resendTimeoutSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        t.cancel();
      }
    });
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // User pasted full OTP
      _handlePaste(value);
      return;
    }

    if (value.isNotEmpty) {
      if (index < _pinLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _notifyCompletion();
      }
    }
  }

  void _handlePaste(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    for (int i = 0; i < _pinLength; i++) {
      if (i < digits.length) {
        _controllers[i].text = digits[i];
      }
    }
    if (digits.length >= _pinLength) {
      _focusNodes.last.unfocus();
      _notifyCompletion();
    } else if (digits.isNotEmpty) {
      final nextIndex = digits.length < _pinLength
          ? digits.length
          : _pinLength - 1;
      _focusNodes[nextIndex].requestFocus();
    }
  }

  void _notifyCompletion() {
    final pin = _controllers.map((c) => c.text).join();
    if (pin.length == _pinLength) {
      widget.onCompleted(pin);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Enter Verification Code',
          style: AppText.titleLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6.0),
        Text(
          '6-digit code sent to ${widget.formattedPhone}',
          style: AppText.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pinLength, (index) {
            return Container(
              width: 44.0,
              height: 52.0,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: _controllers[index].text.isNotEmpty
                      ? AppColors.accent
                      : AppColors.borderSubtle,
                  width: _controllers[index].text.isNotEmpty ? 1.8 : 1.0,
                ),
              ),
              child: RawKeyboardListener(
                focusNode: FocusNode(),
                onKey: (event) {
                  if (event is RawKeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.backspace &&
                      _controllers[index].text.isEmpty &&
                      index > 0) {
                    _focusNodes[index - 1].requestFocus();
                  }
                },
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppText.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) => _onDigitChanged(index, val),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _countdown > 0
                  ? 'Resend code in ${_countdown}s'
                  : "Didn't receive the code? ",
              style: AppText.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            if (_countdown == 0)
              GestureDetector(
                onTap: () {
                  _startCountdown();
                  widget.onResend();
                },
                child: Text(
                  'Resend OTP',
                  style: AppText.labelMedium.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
