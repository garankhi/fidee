import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/nearby_place.dart';
import '../services/friend_service.dart';

class AddSpotScreen extends StatefulWidget {
  final List<NearbyPlace> spotSuggestions;

  const AddSpotScreen({super.key, this.spotSuggestions = const []});

  @override
  State<AddSpotScreen> createState() => _AddSpotScreenState();
}

class _AddSpotScreenState extends State<AddSpotScreen> {
  static const Color _accent = Color(0xFFEF4050);
  static const Color _softAccent = Color(0xFFFFE9EC);
  static const Color _text = Color(0xFF151515);
  static const Color _muted = Color(0xFF8D8D8D);
  static const Color _field = Color(0xFFF8F8F8);
  static const Color _border = Color(0xFFE9E9E9);

  String? _selectedSpotName;

  final PageController _pageController = PageController();
  final ImagePicker _imagePicker = ImagePicker();
  final FriendService _friendService = const FriendService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _openController = TextEditingController();
  final TextEditingController _closeController = TextEditingController();
  final TextEditingController _priceFromController = TextEditingController();
  final TextEditingController _priceToController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dishNoteController = TextEditingController();
  final TextEditingController _reviewController = TextEditingController();

  final Set<String> _selectedVibes = <String>{'Hẹn hò', 'Cà phê'};
  final Set<String> _selectedServices = <String>{'Wifi', 'Ngoài trời'};
  final Set<String> _selectedReviewTags = <String>{'Không khí tuyệt'};
  final Set<String> _sentFriendIds = <String>{};

  int _step = 0;
  int _rating = 5;
  String _visibility = 'public';
  XFile? _menuImage;
  XFile? _vibeImage;
  XFile? _dishImage;
  XFile? _checkInImage;
  Future<List<FriendProfile>>? _friendsFuture;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _openController.dispose();
    _closeController.dispose();
    _priceFromController.dispose();
    _priceToController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _dishNoteController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(_SpotImageSlot slot) async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (image == null || !mounted) return;

    setState(() {
      switch (slot) {
        case _SpotImageSlot.menu:
          _menuImage = image;
        case _SpotImageSlot.vibe:
          _vibeImage = image;
        case _SpotImageSlot.dishes:
          _dishImage = image;
        case _SpotImageSlot.checkIn:
          _checkInImage = image;
      }
    });
  }

  void _goToStep(int index) {
    setState(() => _step = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    if (_step < 3) _goToStep(_step + 1);
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    _goToStep(_step - 1);
  }

  void _submit() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Địa điểm đã sẵn sàng để đăng')),
    );
    Navigator.pop(context);
  }

  void _showFriendSheet() {
    setState(() => _visibility = 'friends');
    _friendsFuture ??= _friendService.fetchFriends();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _FriendPickerSheet(
          friendsFuture: _friendsFuture!,
          sentFriendIds: _sentFriendIds,
          onSendFriend: (String id) {
            setState(() => _sentFriendIds.add(id));
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _AddSpotHeader(step: _step, onBack: _back),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepOne(
                    nameController: _nameController,
                    spotSuggestions: widget.spotSuggestions,
                    selectedSpotName: _selectedSpotName,
                    onSpotNameChanged: (v) => setState(() => _selectedSpotName = v),
                    openController: _openController,
                    closeController: _closeController,
                    priceFromController: _priceFromController,
                    priceToController: _priceToController,
                    addressController: _addressController,
                    phoneController: _phoneController,
                    descriptionController: _descriptionController,
                    selectedVibes: _selectedVibes,
                    selectedServices: _selectedServices,
                    onToggleVibe: (String value) =>
                        _toggle(_selectedVibes, value),
                    onToggleService: (String value) =>
                        _toggle(_selectedServices, value),
                    onNext: _next,
                  ),
                  _StepTwo(
                    menuImage: _menuImage,
                    vibeImage: _vibeImage,
                    dishImage: _dishImage,
                    dishNoteController: _dishNoteController,
                    onPickImage: _pickImage,
                    onNext: _next,
                  ),
                  _StepThree(
                    checkInImage: _checkInImage,
                    rating: _rating,
                    selectedTags: _selectedReviewTags,
                    reviewController: _reviewController,
                    onPickImage: () => _pickImage(_SpotImageSlot.checkIn),
                    onRate: (int value) => setState(() => _rating = value),
                    onToggleTag: (String value) =>
                        _toggle(_selectedReviewTags, value),
                    onNext: _next,
                  ),
                  _StepFour(
                    visibility: _visibility,
                    onVisibilityChanged: (String value) =>
                        setState(() => _visibility = value),
                    onOpenFriendSheet: _showFriendSheet,
                    onSubmit: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(Set<String> values, String value) {
    setState(() {
      if (!values.add(value)) {
        values.remove(value);
      }
    });
  }
}

class _AddSpotHeader extends StatelessWidget {
  final int step;
  final VoidCallback onBack;

  const _AddSpotHeader({required this.step, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _IconCircleButton(
                  icon: Icons.chevron_left,
                  onTap: onBack,
                ),
              ),
              Column(
                children: [
                  Text(
                    'Bước ${step + 1} / 4',
                    style: const TextStyle(
                      color: _AddSpotScreenState._text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Thêm địa điểm',
                    style: TextStyle(
                      color: _AddSpotScreenState._text,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: List.generate(4, (int index) {
              final bool active = index <= step;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 5,
                  margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
                  decoration: BoxDecoration(
                    color: active
                        ? _AddSpotScreenState._accent
                        : _AddSpotScreenState._border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StepOne extends StatefulWidget {
  final TextEditingController nameController;
  final List<NearbyPlace> spotSuggestions;
  final String? selectedSpotName;
  final ValueChanged<String> onSpotNameChanged;
  final TextEditingController openController;
  final TextEditingController closeController;
  final TextEditingController priceFromController;
  final TextEditingController priceToController;
  final TextEditingController addressController;
  final TextEditingController phoneController;
  final TextEditingController descriptionController;
  final Set<String> selectedVibes;
  final Set<String> selectedServices;
  final ValueChanged<String> onToggleVibe;
  final ValueChanged<String> onToggleService;
  final VoidCallback onNext;

  const _StepOne({
    required this.nameController,
    required this.spotSuggestions,
    required this.selectedSpotName,
    required this.onSpotNameChanged,
    required this.openController,
    required this.closeController,
    required this.priceFromController,
    required this.priceToController,
    required this.addressController,
    required this.phoneController,
    required this.descriptionController,
    required this.selectedVibes,
    required this.selectedServices,
    required this.onToggleVibe,
    required this.onToggleService,
    required this.onNext,
  });

  @override
  State<_StepOne> createState() => _StepOneState();
}

class _StepOneState extends State<_StepOne> {
  String? _nameError;
  String? _vibeError;
  String? _hoursError;
  String? _priceError;
  String? _addressError;
  String? _serviceError;

  int? _parseTime(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return h * 60 + m;
  }

  bool _validate() {
    String? nameError;
    String? vibeError;
    String? hoursError;
    String? priceError;
    String? addressError;
    String? serviceError;

    if (widget.selectedSpotName == null || widget.selectedSpotName!.trim().isEmpty) {
      nameError = 'Vui lòng chọn tên địa điểm';
    }
    if (widget.selectedVibes.isEmpty) {
      vibeError = 'Vui lòng chọn ít nhất một không khí';
    }
    if (widget.addressController.text.trim().isEmpty) {
      addressError = 'Vui lòng nhập địa chỉ';
    }
    if (widget.selectedServices.isEmpty) {
      serviceError = 'Vui lòng chọn ít nhất một tiện ích';
    }

    final openVal = widget.openController.text.trim();
    final closeVal = widget.closeController.text.trim();
    if (openVal.isEmpty || closeVal.isEmpty) {
      hoursError = 'Vui lòng nhập đầy đủ giờ mở và đóng cửa';
    } else {
      final open = _parseTime(openVal);
      final close = _parseTime(closeVal);
      if (open == null) {
        hoursError = 'Giờ mở cửa không hợp lệ';
      } else if (close == null) {
        hoursError = 'Giờ đóng cửa không hợp lệ';
      } else if (close <= open) {
        hoursError = 'Giờ đóng cửa phải sau giờ mở cửa';
      }
    }

    final fromVal = widget.priceFromController.text.trim();
    final toVal = widget.priceToController.text.trim();
    if (fromVal.isEmpty || toVal.isEmpty) {
      priceError = 'Vui lòng nhập đầy đủ giá từ và giá đến';
    } else {
      final from = double.tryParse(fromVal);
      final to = double.tryParse(toVal);
      if (from == null) {
        priceError = 'Giá từ không hợp lệ';
      } else if (to == null) {
        priceError = 'Giá đến không hợp lệ';
      } else if (to <= from) {
        priceError = 'Giá đến phải lớn hơn giá từ';
      }
    }

    setState(() {
      _nameError = nameError;
      _vibeError = vibeError;
      _hoursError = hoursError;
      _priceError = priceError;
      _addressError = addressError;
      _serviceError = serviceError;
    });
    return nameError == null &&
        vibeError == null &&
        hoursError == null &&
        priceError == null &&
        addressError == null &&
        serviceError == null;
  }

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      action: _PrimaryButton(
        label: 'Tiếp theo',
        onTap: () {
          if (_validate()) widget.onNext();
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('Tên địa điểm', isRequired: true),
          _SpotNameDropdown(
            suggestions: widget.spotSuggestions,
            value: widget.selectedSpotName,
            onChanged: widget.onSpotNameChanged,
            hasError: _nameError != null,
          ),
          if (_nameError != null) _ErrorText(_nameError!),
          const SizedBox(height: 20),
          const _Label('Không khí', isRequired: true),
          _ChipWrap(
            options: const <String>[
              'Hẹn hò',
              'Nhóm bạn',
              'Học tập',
              'Cà phê',
              'Thư giãn',
              'Healthy',
              'Acoustic',
              'Đồ ngọt',
              'Khác',
            ],
            selected: widget.selectedVibes,
            onToggle: widget.onToggleVibe,
          ),
          if (_vibeError != null) _ErrorText(_vibeError!),
          const SizedBox(height: 20),
          const _Label('Khung giờ hoạt động', isRequired: true),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 62,
                child: Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    'Mở cửa',
                    style: TextStyle(
                      color: _AddSpotScreenState._text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _SoftTextField(
                  controller: widget.openController,
                  hint: '08:00',
                  keyboardType: TextInputType.number,
                  inputFormatters: [_TimeInputFormatter()],
                  hasError: _hoursError != null,
                ),
              ),
              const SizedBox(width: 14),
              const SizedBox(
                width: 68,
                child: Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    'Đóng cửa',
                    style: TextStyle(
                      color: _AddSpotScreenState._text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _SoftTextField(
                  controller: widget.closeController,
                  hint: '22:00',
                  keyboardType: TextInputType.number,
                  inputFormatters: [_TimeInputFormatter()],
                  hasError: _hoursError != null,
                ),
              ),
            ],
          ),
          if (_hoursError != null) _ErrorText(_hoursError!),
          const SizedBox(height: 20),
          const _Label('Giá tiền', isRequired: true),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'từ',
                  style: TextStyle(color: _AddSpotScreenState._text),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SoftTextField(
                  controller: widget.priceFromController,
                  hint: '20000',
                  keyboardType: TextInputType.number,
                  hasError: _priceError != null,
                ),
              ),
              const SizedBox(width: 18),
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'đến',
                  style: TextStyle(color: _AddSpotScreenState._text),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SoftTextField(
                  controller: widget.priceToController,
                  hint: '120000',
                  keyboardType: TextInputType.number,
                  hasError: _priceError != null,
                ),
              ),
            ],
          ),
          if (_priceError != null) _ErrorText(_priceError!),
          const SizedBox(height: 20),
          const _Label('Địa chỉ', isRequired: true),
          _SoftTextField(
            controller: widget.addressController,
            hint: '123 Đường Abc, Phường Bến Thành',
            hasError: _addressError != null,
          ),
          if (_addressError != null) _ErrorText(_addressError!),
          const SizedBox(height: 20),
          const _Label('Số điện thoại'),
          _SoftTextField(
            controller: widget.phoneController,
            hint: '0912 345 678',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          const _Label('Mô tả'),
          _SoftTextField(
            controller: widget.descriptionController,
            hint: 'Không gian chill, view đẹp, acoustic mỗi tối thứ 7...',
            minLines: 3,
            maxLines: 4,
          ),
          const SizedBox(height: 20),
          const _Label('Tiện ích', isRequired: true),
          _ChipWrap(
            options: const <String>[
              'Wifi',
              'Trong nhà',
              'Ngoài trời',
              'Làm việc được',
              'Không tiền mặt',
              'Acoustic',
              'Đỗ xe ô tô',
              'Yên tĩnh',
              'Không thú cưng',
              'Giao hàng',
              'Không có chỗ ngồi',
              '+ Thêm',
            ],
            selected: widget.selectedServices,
            onToggle: widget.onToggleService,
          ),
          if (_serviceError != null) _ErrorText(_serviceError!),
        ],
      ),
    );
  }
}

class _StepTwo extends StatefulWidget {
  final XFile? menuImage;
  final XFile? vibeImage;
  final XFile? dishImage;
  final TextEditingController dishNoteController;
  final ValueChanged<_SpotImageSlot> onPickImage;
  final VoidCallback onNext;

  const _StepTwo({
    required this.menuImage,
    required this.vibeImage,
    required this.dishImage,
    required this.dishNoteController,
    required this.onPickImage,
    required this.onNext,
  });

  @override
  State<_StepTwo> createState() => _StepTwoState();
}

class _StepTwoState extends State<_StepTwo> {
  String? _menuError;

  bool _validate() {
    final error = widget.menuImage == null ? 'Vui lòng thêm ảnh thực đơn' : null;
    setState(() => _menuError = error);
    return error == null;
  }

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      action: _PrimaryButton(
        label: 'Tiếp theo',
        onTap: () { if (_validate()) widget.onNext(); },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('Ảnh thực đơn', isRequired: true),
          _ImageDropBox(
            image: widget.menuImage,
            onTap: () => widget.onPickImage(_SpotImageSlot.menu),
            hasError: _menuError != null,
          ),
          if (_menuError != null) _ErrorText(_menuError!),
          const SizedBox(height: 22),
          const _Label('Ảnh không khí địa điểm'),
          _ImageDropBox(
            image: widget.vibeImage,
            onTap: () => widget.onPickImage(_SpotImageSlot.vibe),
          ),
          const SizedBox(height: 22),
          const _Label('Món đặc trưng'),
          _ImageDropBox(
            image: widget.dishImage,
            onTap: () => widget.onPickImage(_SpotImageSlot.dishes),
          ),
          const SizedBox(height: 14),
          _SoftTextField(
            controller: widget.dishNoteController,
            hint: 'Chia sẻ gì đó về những món này...',
            minLines: 2,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

class _StepThree extends StatefulWidget {
  final XFile? checkInImage;
  final int rating;
  final Set<String> selectedTags;
  final TextEditingController reviewController;
  final VoidCallback onPickImage;
  final ValueChanged<int> onRate;
  final ValueChanged<String> onToggleTag;
  final VoidCallback onNext;

  const _StepThree({
    required this.checkInImage,
    required this.rating,
    required this.selectedTags,
    required this.reviewController,
    required this.onPickImage,
    required this.onRate,
    required this.onToggleTag,
    required this.onNext,
  });

  @override
  State<_StepThree> createState() => _StepThreeState();
}

class _StepThreeState extends State<_StepThree> {
  String? _checkInError;

  bool _validate() {
    final error = widget.checkInImage == null ? 'Vui lòng thêm ảnh check-in' : null;
    setState(() => _checkInError = error);
    return error == null;
  }

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      action: _PrimaryButton(
        label: 'Tiếp theo',
        onTap: () { if (_validate()) widget.onNext(); },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('Ảnh check-in của bạn', isRequired: true),
          _ImageDropBox(
            image: widget.checkInImage,
            onTap: widget.onPickImage,
            hasError: _checkInError != null,
          ),
          if (_checkInError != null) _ErrorText(_checkInError!),
          const SizedBox(height: 20),
          Row(
            children: [
              const _Label('Đánh giá địa điểm', isRequired: true),
              const SizedBox(width: 20),
              Row(
                children: List.generate(5, (int index) {
                  final int star = index + 1;
                  return GestureDetector(
                    onTap: () => widget.onRate(star),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        star <= widget.rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: _AddSpotScreenState._accent,
                        size: 24,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ChipWrap(
            options: const <String>[
              'Không khí tuyệt',
              'Phục vụ nhanh',
              'Xứng đáng giá tiền',
            ],
            selected: widget.selectedTags,
            onToggle: widget.onToggleTag,
          ),
          const SizedBox(height: 18),
          _SoftTextField(
            controller: widget.reviewController,
            hint: 'Chia sẻ cảm nhận của bạn...',
            minLines: 3,
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}

class _StepFour extends StatelessWidget {
  final String visibility;
  final ValueChanged<String> onVisibilityChanged;
  final VoidCallback onOpenFriendSheet;
  final VoidCallback onSubmit;

  const _StepFour({
    required this.visibility,
    required this.onVisibilityChanged,
    required this.onOpenFriendSheet,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      action: Row(
        children: [
          Expanded(
            child: _PrimaryButton(
              label: 'Gửi cho',
              icon: Icons.send_rounded,
              onTap: onOpenFriendSheet,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: _PrimaryButton(label: 'Đăng', onTap: onSubmit),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ai có thể xem địa điểm này?',
            style: TextStyle(
              color: _AddSpotScreenState._accent,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          _VisibilityTile(
            icon: Icons.public_rounded,
            title: 'Công khai',
            subtitle: 'Mọi người đều có thể xem trên bản đồ',
            active: visibility == 'public',
            onTap: () => onVisibilityChanged('public'),
          ),
          const SizedBox(height: 12),
          _VisibilityTile(
            icon: Icons.people_rounded,
            title: 'Chia sẻ với bạn bè',
            subtitle: 'Chỉ bạn bè của bạn mới thấy trên bản đồ',
            active: visibility == 'friends',
            onTap: () => onVisibilityChanged('friends'),
          ),
          const SizedBox(height: 12),
          _VisibilityTile(
            icon: Icons.star_rounded,
            title: 'Bạn thân',
            subtitle: 'Chọn bạn thân để họ thấy trên bản đồ',
            active: visibility == 'close',
            onTap: () => onVisibilityChanged('close'),
          ),
        ],
      ),
    );
  }
}

class _FriendPickerSheet extends StatefulWidget {
  final Future<List<FriendProfile>> friendsFuture;
  final Set<String> sentFriendIds;
  final ValueChanged<String> onSendFriend;

  const _FriendPickerSheet({
    required this.friendsFuture,
    required this.sentFriendIds,
    required this.onSendFriend,
  });

  @override
  State<_FriendPickerSheet> createState() => _FriendPickerSheetState();
}

class _FriendPickerSheetState extends State<_FriendPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E2E2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Nhắn tin',
              style: TextStyle(
                color: _AddSpotScreenState._text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            _SoftTextField(
              controller: _searchController,
              hint: 'Tìm kiếm',
              prefixIcon: Icons.search_rounded,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: FutureBuilder<List<FriendProfile>>(
                future: widget.friendsFuture,
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<FriendProfile>> snapshot,
                    ) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const _FriendSheetSkeleton();
                      }

                      final List<FriendProfile> friends = _filteredFriends(
                        snapshot.data ?? const <FriendProfile>[],
                      );
                      if (friends.isEmpty) {
                        return const _FriendEmptyState();
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: friends.length,
                        itemBuilder: (BuildContext context, int index) {
                          final FriendProfile friend = friends[index];
                          return _FriendRow(
                            friend: friend,
                            sent: widget.sentFriendIds.contains(friend.id),
                            onSend: () {
                              widget.onSendFriend(friend.id);
                              setState(() {});
                            },
                          );
                        },
                      );
                    },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FriendProfile> _filteredFriends(List<FriendProfile> friends) {
    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return friends;
    return friends
        .where(
          (friend) =>
              friend.name.toLowerCase().contains(query) ||
              friend.handle.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }
}

class _FriendSheetSkeleton extends StatelessWidget {
  const _FriendSheetSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: 4,
      itemBuilder: (BuildContext context, int index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              _SkeletonBlock(width: 42, height: 42, radius: 21),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBlock(
                      width: double.infinity,
                      height: 12,
                      radius: 8,
                    ),
                    SizedBox(height: 7),
                    _SkeletonBlock(width: 76, height: 10, radius: 8),
                  ],
                ),
              ),
              SizedBox(width: 18),
              _SkeletonBlock(
                width: 56,
                height: 28,
                radius: 999,
                color: _AddSpotScreenState._softAccent,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FriendEmptyState extends StatelessWidget {
  const _FriendEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_rounded, color: _AddSpotScreenState._accent, size: 34),
          SizedBox(height: 12),
          Text(
            'Chưa có bạn bè',
            style: TextStyle(
              color: _AddSpotScreenState._text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Danh sách bạn bè sẽ hiển thị ở đây khi có sẵn.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _AddSpotScreenState._muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final Color color;

  const _SkeletonBlock({
    required this.width,
    required this.height,
    required this.radius,
    this.color = const Color(0xFFF1F1F1),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  final Widget child;
  final Widget action;

  const _StepScaffold({required this.child, required this.action});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
            child: child,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
          child: Align(alignment: Alignment.centerRight, child: action),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final bool isRequired;

  const _Label(this.text, {this.isRequired = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: _AddSpotScreenState._text,
            fontFamily: 'SF Pro',
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          children: [
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: _AddSpotScreenState._accent),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(':', '');
    if (digits.length > 4) return oldValue;
    String formatted = digits;
    if (digits.length >= 3) {
      formatted = '${digits.substring(0, 2)}:${digits.substring(2)}';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _SpotNameDropdown extends StatefulWidget {
  final List<NearbyPlace> suggestions;
  final String? value;
  final ValueChanged<String> onChanged;
  final bool hasError;

  const _SpotNameDropdown({
    required this.suggestions,
    required this.value,
    required this.onChanged,
    this.hasError = false,
  });

  @override
  State<_SpotNameDropdown> createState() => _SpotNameDropdownState();
}

class _SpotNameDropdownState extends State<_SpotNameDropdown> {
  final TextEditingController _customController = TextEditingController();
  bool _isCustom = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCustom) {
      return Row(
        children: [
          Expanded(
            child: _SoftTextField(
              controller: _customController,
              hint: 'Nhập tên địa điểm...',
              hasError: widget.hasError,
              onChanged: widget.onChanged,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() {
              _isCustom = false;
              _customController.clear();
            }),
            child: const Icon(
              Icons.close_rounded,
              color: _AddSpotScreenState._muted,
              size: 20,
            ),
          ),
        ],
      );
    }

    final items = [
      ...widget.suggestions.map((p) => p.displayName),
      '+ Nhập tên khác',
    ];

    return GestureDetector(
      onTap: () {
        showModalBottomSheet<String>(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E2E2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Chọn địa điểm',
                  style: TextStyle(
                    color: _AddSpotScreenState._text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ...items.map(
                  (name) => GestureDetector(
                    onTap: () => Navigator.pop(context, name),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: widget.value == name
                            ? _AddSpotScreenState._softAccent
                            : _AddSpotScreenState._field,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: widget.value == name
                              ? _AddSpotScreenState._accent
                              : _AddSpotScreenState._border,
                        ),
                      ),
                      child: Text(
                        name,
                        style: TextStyle(
                          color: name.startsWith('+')
                              ? _AddSpotScreenState._accent
                              : _AddSpotScreenState._text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ).then((selected) {
          if (selected == null) return;
          if (selected.startsWith('+')) {
            setState(() => _isCustom = true);
          } else {
            widget.onChanged(selected);
          }
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: _AddSpotScreenState._field,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.hasError
                ? _AddSpotScreenState._accent
                : _AddSpotScreenState._border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.value ?? 'Chọn địa điểm...',
                style: TextStyle(
                  color: widget.value != null
                      ? _AddSpotScreenState._text
                      : const Color(0xFFC9C9C9),
                  fontSize: widget.value != null ? 14 : 13,
                  fontWeight: widget.value != null
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _AddSpotScreenState._muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String message;
  const _ErrorText(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message,
        style: const TextStyle(
          color: _AddSpotScreenState._accent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SoftTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;
  final bool hasError;
  final List<TextInputFormatter>? inputFormatters;

  const _SoftTextField({
    required this.controller,
    required this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.prefixIcon,
    this.onChanged,
    this.hasError = false,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      minLines: minLines,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(
        color: _AddSpotScreenState._text,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: _AddSpotScreenState._field,
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFFC9C9C9),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 18, color: _AddSpotScreenState._muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: hasError ? _AddSpotScreenState._accent : _AddSpotScreenState._border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _AddSpotScreenState._accent),
        ),
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _ChipWrap({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map((String option) {
            final bool active = selected.contains(option);
            final bool add = option.startsWith('+');
            return GestureDetector(
              onTap: () => onToggle(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: EdgeInsets.fromLTRB(active ? 10 : 15, 8, 15, 8),
                decoration: BoxDecoration(
                  color: active
                      ? _AddSpotScreenState._accent
                      : add
                      ? _AddSpotScreenState._field
                      : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active
                        ? _AddSpotScreenState._accent
                        : _AddSpotScreenState._border,
                    width: active ? 1.4 : 1,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: _AddSpotScreenState._accent.withValues(
                              alpha: 0.18,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (active) ...[
                      const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      option,
                      style: TextStyle(
                        color: active
                            ? Colors.white
                            : add
                            ? _AddSpotScreenState._text
                            : _AddSpotScreenState._muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _ImageDropBox extends StatelessWidget {
  final XFile? image;
  final VoidCallback onTap;
  final bool hasError;

  const _ImageDropBox({required this.image, required this.onTap, this.hasError = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 132,
        height: 132,
        decoration: BoxDecoration(
          color: _AddSpotScreenState._field,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasError ? _AddSpotScreenState._accent : _AddSpotScreenState._border,
            width: hasError ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: image == null
            ? const Center(
                child: Icon(
                  Icons.image_rounded,
                  color: Color(0xFFD2D2D2),
                  size: 40,
                ),
              )
            : Image.file(File(image!.path), fit: BoxFit.cover),
      ),
    );
  }
}

class _VisibilityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  const _VisibilityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: active ? _AddSpotScreenState._softAccent : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? _AddSpotScreenState._accent
                : _AddSpotScreenState._border,
            width: active ? 1.6 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: _AddSpotScreenState._accent.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: active
                    ? _AddSpotScreenState._accent
                    : _AddSpotScreenState._field,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: active ? Colors.white : _AddSpotScreenState._muted,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: active
                          ? _AddSpotScreenState._accent
                          : _AddSpotScreenState._text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: active
                          ? _AddSpotScreenState._accent
                          : _AddSpotScreenState._muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: active ? _AddSpotScreenState._accent : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active
                      ? _AddSpotScreenState._accent
                      : _AddSpotScreenState._border,
                ),
              ),
              child: active
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 15,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  final FriendProfile friend;
  final bool sent;
  final VoidCallback onSend;

  const _FriendRow({
    required this.friend,
    required this.sent,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFF5FA66B),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                friend.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AddSpotScreenState._text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  friend.handle,
                  style: const TextStyle(
                    color: _AddSpotScreenState._muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _MiniButton(
            label: sent ? 'Đã gửi' : 'Gửi',
            onTap: sent ? null : onSend,
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        constraints: const BoxConstraints(minWidth: 76),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: _AddSpotScreenState._accent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: _AddSpotScreenState._accent.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 17),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _MiniButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: onTap == null
              ? _AddSpotScreenState._accent.withValues(alpha: 0.5)
              : _AddSpotScreenState._accent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: _AddSpotScreenState._softAccent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _AddSpotScreenState._accent, size: 22),
      ),
    );
  }
}

enum _SpotImageSlot { menu, vibe, dishes, checkIn }
