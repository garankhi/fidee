import 'package:flutter/material.dart';

import '../services/gallery_asset_picker_service.dart';

typedef GalleryAssetSheetLoader = Future<List<GalleryAssetPickerItem>> Function();

class GalleryAssetPickerSheet extends StatefulWidget {
  GalleryAssetPickerSheet({
    super.key,
    GalleryAssetSheetLoader? loadAssets,
  }) : loadAssets = loadAssets ?? const GalleryAssetPickerService().loadRecentImages;

  final GalleryAssetSheetLoader loadAssets;

  @override
  State<GalleryAssetPickerSheet> createState() => _GalleryAssetPickerSheetState();
}

class _GalleryAssetPickerSheetState extends State<GalleryAssetPickerSheet> {
  late final Future<List<GalleryAssetPickerItem>> _assetsFuture;
  String? _busyAssetId;

  @override
  void initState() {
    super.initState();
    _assetsFuture = widget.loadAssets();
  }

  Future<void> _selectAsset(GalleryAssetPickerItem item) async {
    setState(() {
      _busyAssetId = item.id;
    });

    final path = await item.loadPath();
    if (!mounted) return;

    if (path == null) {
      setState(() {
        _busyAssetId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được ảnh này. Vui lòng chọn ảnh khác.')),
      );
      return;
    }

    Navigator.pop(context, path);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1F1F1F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 54,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Chọn ảnh từ thư viện',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: FutureBuilder<List<GalleryAssetPickerItem>>(
                    future: _assetsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }

                      final assets = snapshot.data ?? const <GalleryAssetPickerItem>[];
                      if (assets.isEmpty) {
                        return Center(
                          child: Text(
                            'Không có ảnh nào để chọn',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: assets.length,
                        itemBuilder: (context, index) {
                          final asset = assets[index];
                          final isBusy = _busyAssetId == asset.id;
                          return _GalleryAssetTile(
                            key: ValueKey('gallery-asset-${asset.id}'),
                            item: asset,
                            isBusy: isBusy,
                            onTap: isBusy ? null : () => _selectAsset(asset),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryAssetTile extends StatelessWidget {
  const _GalleryAssetTile({
    super.key,
    required this.item,
    required this.isBusy,
    required this.onTap,
  });

  final GalleryAssetPickerItem item;
  final bool isBusy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Material(
        color: const Color(0xFF353535),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(item.thumbnail, fit: BoxFit.cover),
              if (isBusy)
                Container(
                  color: Colors.black.withValues(alpha: 0.46),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
