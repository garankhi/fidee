import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../login_design.dart';
import '../profile_draft_provider.dart';
import '../widgets/auth_wizard_layout.dart';
import 'register_step5_username_page.dart';

class RegisterStep4InfoPage extends ConsumerStatefulWidget {
  final String firstName;
  final String lastName;

  const RegisterStep4InfoPage({
    super.key,
    required this.firstName,
    required this.lastName,
  });

  @override
  ConsumerState<RegisterStep4InfoPage> createState() => _RegisterStep4State();
}

class _RegisterStep4State extends ConsumerState<RegisterStep4InfoPage> {
  String _gender = 'Nam';
  DateTime? _selectedDate;

  void _submit() {
    if (_selectedDate == null) return;

    ref
        .read(profileDraftControllerProvider.notifier)
        .updateInfo(_gender, _selectedDate!);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RegisterStep5UsernamePage(
          firstName: widget.firstName,
          lastName: widget.lastName,
          gender: _gender,
          dob: _selectedDate!,
        ),
      ),
    );
  }

  void _showGenderPicker() {
    final List<String> genders = ['Nam', 'Nữ', 'Không tiện nói'];
    int initialIndex = genders.indexOf(_gender);
    if (initialIndex == -1) initialIndex = 0;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoTheme(
        data: const CupertinoThemeData(
          brightness: Brightness.light,
          textTheme: CupertinoTextThemeData(
            pickerTextStyle: TextStyle(color: Colors.black, fontSize: 21),
          ),
        ),
        child: Container(
          height: 250,
          color: Colors.white,
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(
                    initialItem: initialIndex,
                  ),
                  itemExtent: 32.0,
                  onSelectedItemChanged: (int index) {
                    setState(() {
                      _gender = genders[index];
                    });
                  },
                  children: List<Widget>.generate(genders.length, (int index) {
                    return Center(child: Text(genders[index]));
                  }),
                ),
              ),
              CupertinoButton(
                child: const Text(
                  'Xong',
                  style: TextStyle(color: Color(0xFFEF4050)),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDatePicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoTheme(
        data: const CupertinoThemeData(
          brightness: Brightness.light,
          textTheme: CupertinoTextThemeData(
            dateTimePickerTextStyle: TextStyle(
              color: Colors.black,
              fontSize: 21,
            ),
          ),
        ),
        child: Container(
          height: 250,
          color: Colors.white,
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: CupertinoDatePicker(
                  initialDateTime: _selectedDate ?? DateTime(2000, 1, 1),
                  mode: CupertinoDatePickerMode.date,
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (val) {
                    setState(() {
                      _selectedDate = val;
                    });
                  },
                ),
              ),
              CupertinoButton(
                child: const Text(
                  'Xong',
                  style: TextStyle(color: Color(0xFFEF4050)),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthWizardLayout(
      title: 'Bạn là?',
      onBack: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _showGenderPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: Text(
                _gender,
                style: LoginTextStyles.title().copyWith(
                  fontSize: 28,
                  color: LoginColors.textPrimary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nam/Nữ/Không tiện nói',
            textAlign: TextAlign.center,
            style: LoginTextStyles.fieldText().copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 60),
          Text(
            'Ngày sinh của bạn là?',
            textAlign: TextAlign.center,
            style: LoginTextStyles.title().copyWith(fontSize: 24),
          ),
          const SizedBox(height: 30),
          GestureDetector(
            onTap: _showDatePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: Text(
                _selectedDate == null
                    ? 'DD-MM-YYYY'
                    : DateFormat('dd-MM-yyyy').format(_selectedDate!),
                style: LoginTextStyles.title().copyWith(
                  fontSize: 28,
                  color: _selectedDate == null
                      ? LoginColors.border
                      : LoginColors.textPrimary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _selectedDate == null ? null : _submit,
                style: TextButton.styleFrom(foregroundColor: LoginColors.red),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Tiếp tục', style: LoginTextStyles.button()),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
