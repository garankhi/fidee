import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/gallery_permission_service.dart';

enum GalleryPermissionAction { requestAccess, selectMore, openSettings, deny }

class GalleryPermissionSheet extends StatelessWidget {
  const GalleryPermissionSheet({super.key, required this.status});

  final GalleryPermissionStatus status;

  bool get _isLimited => status == GalleryPermissionStatus.limited;

  bool get _needsSettings =>
      status == GalleryPermissionStatus.denied ||
      status == GalleryPermissionStatus.limited;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1F1F1F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 54,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFC400),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.images,
                        color: Colors.black,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isLimited
                        ? 'Bạn đang chỉ chia sẻ một số ảnh với Fidee'
                        : 'Chia sẻ ảnh từ thư viện',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isLimited
                        ? 'Bạn có thể chọn thêm ảnh hoặc mở cài đặt để cho Fidee truy cập toàn bộ thư viện.'
                        : 'Fidee cần quyền thư viện để hiển thị ảnh preview và chọn ảnh upload.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _PermissionActionButton(
                    key: const ValueKey('gallery-permission-share-all'),
                    icon: LucideIcons.image,
                    label: 'Chia sẻ tất cả ảnh',
                    color: const Color(0xFFFFC400),
                    foregroundColor: Colors.black,
                    onPressed: () => Navigator.pop(
                      context,
                      _needsSettings
                          ? GalleryPermissionAction.openSettings
                          : GalleryPermissionAction.requestAccess,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PermissionActionButton(
                    key: const ValueKey('gallery-permission-select'),
                    icon: LucideIcons.listPlus,
                    label: _isLimited ? 'Chọn thêm ảnh' : 'Chọn ảnh',
                    color: const Color(0xFF353535),
                    foregroundColor: Colors.white,
                    onPressed: () => Navigator.pop(
                      context,
                      _isLimited
                          ? GalleryPermissionAction.selectMore
                          : GalleryPermissionAction.requestAccess,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PermissionActionButton(
                    key: const ValueKey('gallery-permission-deny'),
                    icon: LucideIcons.x,
                    label: 'Không chia sẻ',
                    color: const Color(0xFF2A2A2A),
                    foregroundColor: Colors.white.withValues(alpha: 0.9),
                    onPressed: () =>
                        Navigator.pop(context, GalleryPermissionAction.deny),
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

class _PermissionActionButton extends StatelessWidget {
  const _PermissionActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.foregroundColor,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color foregroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foregroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
