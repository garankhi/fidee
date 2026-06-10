import 'package:flutter/material.dart';

import '../widgets/glass_surface.dart';

class SendImagePlaceTagPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const SendImagePlaceTagPill({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassSurface(
        key: const ValueKey('send-image-place-tag-pill'),
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        tint: const Color(0x26FFFFFF),
        borderColor: const Color(0x66FFFFFF),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'SF Pro',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
