import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// Dialog for entering and verifying OTP code for withdrawal security
/// Supports both legacy (Cloud Functions) and Firebase Phone Auth flows
class OTPVerificationDialog extends StatefulWidget {
  final String otpId;
  final double amount;
  final String accountName;
  final String accountNumber;
  final String bankName;

  // Firebase Phone Auth specific (optional, new flow)
  final String? verificationId;
  final String? phoneNumber;

  // Legacy fields (optional, old flow)
  final DateTime? expiresAt;
  final List<String>? deliveredVia;

  // Callbacks
  final Future<Map<String, dynamic>> Function(
    String otpId,
    String code, [
    String? verificationId,
  ])
  onVerify;
  final Future<Map<String, dynamic>> Function(String otpId)? onResend;

  const OTPVerificationDialog({
    super.key,
    required this.otpId,
    required this.amount,
    required this.accountName,
    required this.accountNumber,
    required this.bankName,
    this.verificationId,
    this.phoneNumber,
    this.expiresAt,
    this.deliveredVia,
    required this.onVerify,
    this.onResend,
  });

  @override
  State<OTPVerificationDialog> createState() => _OTPVerificationDialogState();
}

class _OTPVerificationDialogState extends State<OTPVerificationDialog> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  int? _remainingAttempts;
  Timer? _countdownTimer;
  int _secondsRemaining = 0;

  bool get _isFirebasePhoneAuth => widget.verificationId != null;

  @override
  void initState() {
    super.initState();
    if (widget.expiresAt != null) {
      _startCountdown();
    } else {
      // Firebase Phone Auth has 5-minute timeout
      _secondsRemaining = 300;
      _startSimpleCountdown();
    }
  }

  void _startCountdown() {
    if (widget.expiresAt == null) return;
    _secondsRemaining = widget.expiresAt!.difference(DateTime.now()).inSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining = widget.expiresAt!
            .difference(DateTime.now())
            .inSeconds;
        if (_secondsRemaining <= 0) {
          timer.cancel();
          _errorMessage = 'OTP has expired. Please request a new one.';
        }
      });
    });
  }

  void _startSimpleCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
        if (_secondsRemaining <= 0) {
          timer.cancel();
          _errorMessage = 'OTP has expired. Please request a new one.';
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String get _otpCode {
    return _controllers.map((c) => c.text).join();
  }

  bool get _isOtpComplete {
    return _otpCode.length == 6;
  }

  Future<void> _verifyOTP() async {
    if (!_isOtpComplete) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit code');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      // Pass verificationId if using Firebase Phone Auth
      final result = _isFirebasePhoneAuth
          ? await widget.onVerify(widget.otpId, _otpCode, widget.verificationId)
          : await widget.onVerify(widget.otpId, _otpCode);

      if (result['success'] == true) {
        if (mounted) {
          Navigator.of(context).pop(true); // Return success
        }
      } else {
        setState(() {
          _errorMessage = result['error'];
          _remainingAttempts = result['remainingAttempts'];
          // Clear all fields on error
          for (var controller in _controllers) {
            controller.clear();
          }
          _focusNodes[0].requestFocus();
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Verification failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendOTP() async {
    if (widget.onResend == null) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.onResend!(widget.otpId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'New OTP sent via ${result['deliveredVia'].join(", ")}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Clear existing input
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to resend OTP: $e');
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _secondsRemaining <= 0;
    final isExpiringSoon = _secondsRemaining > 0 && _secondsRemaining <= 60;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.security, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          const Expanded(child: Text('Withdrawal Verification')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Withdrawal Details:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Amount: ₦${widget.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Bank: ${widget.bankName}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Account: ${widget.accountName}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Number: ${widget.accountNumber}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Delivery info
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isFirebasePhoneAuth
                          ? 'Code sent via SMS to ${widget.phoneNumber ?? "your phone"}'
                          : 'Code sent via: ${widget.deliveredVia?.join(", ") ?? "SMS/Email"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // OTP instruction
            const Text(
              'Enter the 6-digit code:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),

            // OTP input fields
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 40,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    enabled: !_isVerifying && !isExpired,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        // Move to next field
                        if (index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else {
                          // Last field filled, auto-verify
                          _focusNodes[index].unfocus();
                          if (_isOtpComplete) {
                            _verifyOTP();
                          }
                        }
                      } else if (value.isEmpty && index > 0) {
                        // Move to previous field on backspace
                        _focusNodes[index - 1].requestFocus();
                      }
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Timer
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isExpired
                    ? Colors.red.shade50
                    : isExpiringSoon
                    ? Colors.orange.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isExpired ? Icons.error : Icons.timer,
                    size: 16,
                    color: isExpired
                        ? Colors.red
                        : isExpiringSoon
                        ? Colors.orange
                        : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isExpired
                        ? 'Code expired'
                        : 'Expires in ${_formatTime(_secondsRemaining)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isExpired
                          ? Colors.red
                          : isExpiringSoon
                          ? Colors.orange
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                            ),
                          ),
                          if (_remainingAttempts != null &&
                              _remainingAttempts! > 0)
                            Text(
                              'Attempts remaining: $_remainingAttempts',
                              style: TextStyle(
                                color: Colors.red.shade600,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Resend option
            if (!isExpired && widget.onResend != null) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: _isResending ? null : _resendOTP,
                  icon: _isResending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(_isResending ? 'Resending...' : 'Resend Code'),
                ),
              ),
            ],

            // Security notice
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Colors.amber.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Never share this code with anyone. LifeCare staff will never ask for it.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (!isExpired)
          ElevatedButton(
            onPressed: (_isVerifying || !_isOtpComplete) ? null : _verifyOTP,
            child: _isVerifying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Verify'),
          ),
      ],
    );
  }
}
