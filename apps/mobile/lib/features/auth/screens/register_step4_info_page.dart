import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../login_design.dart';
import '../widgets/auth_wizard_layout.dart';
import 'register_step5_username_page.dart';

class RegisterStep4InfoPage extends StatefulWidget {
  const RegisterStep4InfoPage({super.key});

  @override
  State<RegisterStep4InfoPage> createState() => _RegisterStep4State();
}

class _RegisterStep4State extends State<RegisterStep4InfoPage> {
  String _gender = 'Nam';
  DateTime? _selectedDate;

  void _submit() {
    if (_selectedDate == null) return;
    
    // TODO: Save to temp state/provider
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const RegisterStep5UsernamePage()),
    );
  }

  void _showDatePicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoTheme(
        data: const CupertinoThemeData(
          brightness: Brightness.light,
          textTheme: CupertinoTextThemeData(
            dateTimePickerTextStyle: TextStyle(color: Colors.black, fontSize: 21),
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
                child: const Text('Xong', style: TextStyle(color: Color(0xFFEF4050))),
                onPressed: () => Navigator.of(context).pop(),
              )
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
          Center(
            child: DropdownButton<String>(
              value: _gender,
              icon: const Icon(Icons.keyboard_arrow_down, color: LoginColors.textMuted),
              elevation: 16,
              style: LoginTextStyles.title().copyWith(fontSize: 28, color: LoginColors.textMuted),
              underline: const SizedBox(),
              onChanged: (String? value) {
                if (value != null) setState(() => _gender = value);
              },
              items: ['Nam', 'Nữ', 'Không tiện nói'].map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nam/Nữ/Không tiện nói',
            textAlign: TextAlign.center,
            style: LoginTextStyles.fieldText().copyWith(fontStyle: FontStyle.italic),
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
                _selectedDate == null ? 'DD-MM-YYYY' : DateFormat('dd-MM-yyyy').format(_selectedDate!),
                style: LoginTextStyles.title().copyWith(
                  fontSize: 28, 
                  color: _selectedDate == null ? LoginColors.border : LoginColors.textPrimary,
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


