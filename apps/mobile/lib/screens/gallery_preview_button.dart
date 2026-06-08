import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

class GalleryPreviewButton extends StatelessWidget {
  const GalleryPreviewButton({
    super.key,
    required this.thumbnails,
    required this.onTap,
  });

  final List<Uint8List> thumbnails;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(width: 55, height: 55, child: _buildPreview()),
    );
  }

  Widget _buildPreview() {
    if (thumbnails.isEmpty) {
      return const Align(alignment: Alignment.centerLeft, child: _GalleryPlaceholder());
    }

    if (thumbnails.length == 1) {
      return Stack(
        children: [
          Positioned(
            left: 0,
            top: 5,
            child: _GalleryPhoto(
              key: const ValueKey('gallery-preview-back-photo'),
              bytes: thumbnails.first,
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 5,
          child: _GalleryPhoto(
            key: const ValueKey('gallery-preview-back-photo'),
            bytes: thumbnails[1],
          ),
        ),
        Positioned(
          left: 6,
          top: 8,
          child: Transform.rotate(
            angle: 17 * math.pi / 180,
            child: _GalleryPhoto(
              key: const ValueKey('gallery-preview-front-photo'),
              bytes: thumbnails[0],
            ),
          ),
        ),
      ],
    );
  }
}

class _GalleryPhoto extends StatelessWidget {
  const _GalleryPhoto({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.memory(
        bytes,
        width: 45,
        height: 45,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _GalleryPlaceholder extends StatelessWidget {
  const _GalleryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('gallery-preview-placeholder'),
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: const Icon(
        Icons.photo_library_outlined,
        color: Colors.white70,
        size: 24,
      ),
    );
  }
}
