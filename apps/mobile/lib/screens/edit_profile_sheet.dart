import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';

enum _UsernameAvailabilityStatus { idle, checking, available, taken, error }

class EditProfileSheet extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String preferredUsername;
  final Future<AuthResult> Function({
    required String firstName,
    required String lastName,
    required String preferredUsername,
  }) onSave;
  final Future<UsernameAvailabilityResult> Function(String username) onCheckUsername;
  final VoidCallback onSaved;

  const EditProfileSheet({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.preferredUsername,
    required this.onSave,
    required this.onCheckUsername,
    required this.onSaved,
  });

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  static final _usernamePattern = RegExp(r'^[a-z0-9._]{3,30}$');

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _usernameController;
  bool _isSaving = false;
  String? _saveErrorMessage;
  Timer? _usernameDebounce;
  int _usernameCheckRequestId = 0;
  late final String _initialNormalizedUsername;
  _UsernameAvailabilityStatus _usernameStatus = _UsernameAvailabilityStatus.idle;
  String? _usernameAvailabilityMessage;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.firstName);
    _lastNameController = TextEditingController(text: widget.lastName);
    _usernameController = TextEditingController(text: widget.preferredUsername);
    _initialNormalizedUsername = widget.preferredUsername.trim().toLowerCase();
    _usernameStatus = _isValidUsername(_initialNormalizedUsername)
        ? _UsernameAvailabilityStatus.available
        : _UsernameAvailabilityStatus.idle;
    _firstNameController.addListener(_onProfileFieldChanged);
    _lastNameController.addListener(_onProfileFieldChanged);
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _firstNameController.removeListener(_onProfileFieldChanged);
    _lastNameController.removeListener(_onProfileFieldChanged);
    _usernameController.removeListener(_onUsernameChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  bool _isValidUsername(String value) {
    return _usernamePattern.hasMatch(value.trim().toLowerCase());
  }

  bool get _hasRequiredProfileFields {
    return _firstNameController.text.trim().isNotEmpty &&
        _lastNameController.text.trim().isNotEmpty &&
        _usernameController.text.trim().isNotEmpty;
  }

  bool get _canSave {
    return !_isSaving &&
        _hasRequiredProfileFields &&
        _usernameStatus == _UsernameAvailabilityStatus.available;
  }

  void _onProfileFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onUsernameChanged() {
    _usernameDebounce?.cancel();
    final username = _usernameController.text.trim().toLowerCase();

    setState(() {
      _saveErrorMessage = null;
      _usernameAvailabilityMessage = null;

      if (username.isEmpty || !_isValidUsername(username)) {
        _usernameStatus = _UsernameAvailabilityStatus.idle;
        return;
      }

      if (username == _initialNormalizedUsername) {
        _usernameStatus = _UsernameAvailabilityStatus.available;
        return;
      }

      _usernameStatus = _UsernameAvailabilityStatus.checking;
      _usernameAvailabilityMessage = 'Đang kiểm tra username...';
    });

    if (username.isEmpty || !_isValidUsername(username) || username == _initialNormalizedUsername) {
      return;
    }

    final requestId = ++_usernameCheckRequestId;
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      UsernameAvailabilityResult result;
      try {
        result = await widget.onCheckUsername(username);
      } catch (_) {
        result = const UsernameAvailabilityResult(
          success: false,
          available: false,
          errorMessage: 'Không kiểm tra được username. Vui lòng thử lại.',
        );
      }

      if (!mounted || requestId != _usernameCheckRequestId) return;
      if (_usernameController.text.trim().toLowerCase() != username) return;

      setState(() {
        if (!result.success) {
          _usernameStatus = _UsernameAvailabilityStatus.error;
          _usernameAvailabilityMessage = result.errorMessage ??
              'Không kiểm tra được username. Vui lòng thử lại.';
        } else if (result.available) {
          _usernameStatus = _UsernameAvailabilityStatus.available;
          _usernameAvailabilityMessage = 'Username có thể sử dụng';
        } else {
          _usernameStatus = _UsernameAvailabilityStatus.taken;
          _usernameAvailabilityMessage = result.errorMessage ?? 'Username đã được sử dụng';
        }
      });
    });
  }

  Future<void> _save() async {
    if (!_canSave || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSaving = true;
      _saveErrorMessage = null;
    });

    final result = await widget.onSave(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      preferredUsername: _usernameController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (result.success) {
      final messenger = ScaffoldMessenger.of(context);
      widget.onSaved();
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Cập nhật thông tin thành công!')),
      );
    } else {
      setState(() {
        _saveErrorMessage = result.errorMessage ?? 'Cập nhật profile thất bại';
      });
    }
  }

  String? _requiredMessage(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label không được để trống';
    }
    return null;
  }

  String? _usernameMessage(String? value) {
    final requiredMessage = _requiredMessage(value, 'Username');
    if (requiredMessage != null) return requiredMessage;

    if (!_usernamePattern.hasMatch(value!.trim().toLowerCase())) {
      return 'Username chỉ gồm chữ thường, số, dấu . hoặc _, 3-30 ký tự';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5E5),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Sửa thông tin',
                    style: TextStyle(
                      color: Color(0xFF151515),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ProfileTextField(
                    controller: _firstNameController,
                    label: 'Họ',
                    textInputAction: TextInputAction.next,
                    enabled: !_isSaving,
                    validator: (value) => _requiredMessage(value, 'Họ'),
                  ),
                  const SizedBox(height: 14),
                  _ProfileTextField(
                    controller: _lastNameController,
                    label: 'Tên',
                    textInputAction: TextInputAction.next,
                    enabled: !_isSaving,
                    validator: (value) => _requiredMessage(value, 'Tên'),
                  ),
                  const SizedBox(height: 14),
                  _ProfileTextField(
                    controller: _usernameController,
                    label: 'Username',
                    prefixText: '@',
                    textInputAction: TextInputAction.done,
                    enabled: !_isSaving,
                    validator: _usernameMessage,
                    onFieldSubmitted: (_) => _save(),
                  ),
                  if (_usernameAvailabilityMessage != null) ...[
                    const SizedBox(height: 10),
                    _UsernameAvailabilityMessage(
                      message: _usernameAvailabilityMessage!,
                      status: _usernameStatus,
                    ),
                  ],
                  if (_saveErrorMessage != null) ...[
                    const SizedBox(height: 14),
                    _ProfileSaveMessage(message: _saveErrorMessage!),
                  ],
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8D8D8D),
                            side: const BorderSide(color: Color(0xFFE9E9E9)),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Hủy',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _canSave ? _save : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4050),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFFFB9C1),
                            disabledForegroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Lưu',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSaveMessage extends StatelessWidget {
  final String message;

  const _ProfileSaveMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC7D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFEF4050),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF9B1C2B),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsernameAvailabilityMessage extends StatelessWidget {
  final String message;
  final _UsernameAvailabilityStatus status;

  const _UsernameAvailabilityMessage({
    required this.message,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = status == _UsernameAvailabilityStatus.available;
    final isChecking = status == _UsernameAvailabilityStatus.checking;
    final color = isAvailable
        ? const Color(0xFF1F8A4C)
        : isChecking
            ? const Color(0xFF6E7E91)
            : const Color(0xFFEF4050);
    final icon = isAvailable
        ? Icons.check_circle_outline_rounded
        : isChecking
            ? Icons.hourglass_empty_rounded
            : Icons.error_outline_rounded;

    return Row(
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? prefixText;
  final TextInputAction textInputAction;
  final bool enabled;
  final String? Function(String?) validator;
  final ValueChanged<String>? onFieldSubmitted;

  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.textInputAction,
    required this.enabled,
    required this.validator,
    this.prefixText,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      cursorColor: const Color(0xFFEF4050),
      style: const TextStyle(
        color: Color(0xFF151515),
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        labelStyle: const TextStyle(
          color: Color(0xFF8D8D8D),
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: const Color(0xFFFFF7F8),
        errorStyle: const TextStyle(fontWeight: FontWeight.w700),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFFD8DE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4050), width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4050)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4050), width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE9E9E9)),
        ),
      ),
    );
  }
}
