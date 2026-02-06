import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:media_gallery_app/widgets/media_grid_item.dart';
import 'package:media_gallery_app/screens/video_player_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<AssetEntity> _mediaList = [];
  bool _isLoading = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.photos,
      Permission.videos,
    ].request();

    final allGranted = statuses.values.every((status) => status.isGranted);

    if (allGranted) {
      setState(() {
        _hasPermission = true;
      });
      await _loadMedia();
    } else {
      setState(() {
        _hasPermission = false;
        _isLoading = false;
      });
      if (statuses[Permission.photos]?.isPermanentlyDenied == true ||
          statuses[Permission.videos]?.isPermanentlyDenied == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Разрешите доступ к медиа в настройках приложения'),
            action: SnackBarAction(
              label: 'Настройки',
              onPressed: openAppSettings,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadMedia() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<AssetEntity> allMedia = [];

      final imageAlbums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      if (imageAlbums.isNotEmpty) {
        final images =
            await imageAlbums[0].getAssetListRange(start: 0, end: 200);
        allMedia.addAll(images);
      }
      final videoAlbums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        onlyAll: true,
      );
      if (videoAlbums.isNotEmpty) {
        final videos =
            await videoAlbums[0].getAssetListRange(start: 0, end: 200);
        allMedia.addAll(videos);
      }

      final videoCount =
          allMedia.where((m) => m.type == AssetType.video).length;
      final photoCount =
          allMedia.where((m) => m.type == AssetType.image).length;
      print('Загружено: $photoCount фото, $videoCount видео');

      setState(() {
        _mediaList = allMedia;
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка загрузки медиа: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки медиа: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Нет доступа к медиафайлам',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _requestPermission,
              child: const Text('Разрешить доступ'),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_mediaList.isEmpty) {
      return const Center(
        child: Text(
          'Медиафайлы не найдены',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMedia,
      child: GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 1,
        ),
        itemCount: _mediaList.length,
        itemBuilder: (context, index) {
          final media = _mediaList[index];
          return MediaGridItem(
            media: media,
            onTap: () async {
              final file = await media.originFile;
              if (file != null) {
                if (media.type == AssetType.video) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoPlayerScreen(
                        videoFile: file,
                        title: media.title ?? 'Видео',
                      ),
                    ),
                  );
                } else {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: EdgeInsets.zero,
                      child: InteractiveViewer(
                        panEnabled: true,
                        boundaryMargin: const EdgeInsets.all(20),
                        minScale: 0.5,
                        maxScale: 4,
                        child: Image.file(
                          file,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                }
              }
            },
          );
        },
      ),
    );
  }
}
