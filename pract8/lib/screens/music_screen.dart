import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:media_gallery_app/widgets/audio_player_widget.dart';
import 'package:media_gallery_app/models/audio_item.dart';
import 'package:hive/hive.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final TextEditingController _urlController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late Box<AudioItem> _audioBox;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  String _currentAudioPath = '';

  List<String> _localAudioFiles = [];
  bool _isLoadingLocal = false;

  List<AudioItem> _savedAudios = [];
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _audioBox = Hive.box<AudioItem>('audio_items');
    _loadSavedAudios();
    _loadLocalAudio();

    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _duration = duration;
      });
    });
    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _position = position;
      });
    });
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
      });
    });
  }

  Future<void> _loadSavedAudios() async {
    final audios = _audioBox.values.toList();
    setState(() {
      _savedAudios = audios..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    });
  }

  Future<void> _loadLocalAudio() async {
    setState(() {
      _isLoadingLocal = true;
    });

    try {
      final status = await Permission.audio.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет доступа к аудиофайлам')),
        );
        setState(() {
          _isLoadingLocal = false;
        });
        return;
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.audio,
        onlyAll: true,
      );

      if (albums.isNotEmpty) {
        final album = albums[0];
        final audioAssets = await album.getAssetListRange(start: 0, end: 50);
        final List<String> paths = [];
        for (var asset in audioAssets) {
          final file = await asset.originFile;
          if (file != null) {
            paths.add(file.path);
          }
        }
        setState(() {
          _localAudioFiles = paths;
          _isLoadingLocal = false;
        });
      } else {
        setState(() {
          _isLoadingLocal = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingLocal = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки аудио: $e')),
      );
    }
  }

  Future<void> _downloadAndPlayAudio(String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите URL аудио')),
      );
      return;
    }

    final existing =
        _audioBox.values.where((item) => item.url == url).firstOrNull;
    if (existing != null) {
      await _playAudio(existing.localPath, existing);
      return;
    }

    setState(() {
      _downloading = true;
    });

    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.isAbsolute) {
        throw Exception('Неверный URL');
      }

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final fileName = uri.path.split('/').last.isNotEmpty
            ? uri.path.split('/').last
            : 'audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final filePath = '${dir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        final title = fileName.split('.').first;
        final audioItem = AudioItem(
          url: url,
          localPath: filePath,
          title: title,
        );
        await _audioBox.add(audioItem);

        await _playAudio(filePath, audioItem);
        await _loadSavedAudios();
      } else {
        throw Exception('Ошибка загрузки: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      setState(() {
        _downloading = false;
      });
    }
  }

  Future<void> _playAudio(String path, AudioItem? item) async {
    if (_currentAudioPath == path && _isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
      return;
    }

    if (_currentAudioPath == path && !_isPlaying) {
      await _audioPlayer.resume();
      setState(() {
        _isPlaying = true;
      });
      return;
    }

    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(path));
    setState(() {
      _currentAudioPath = path;
      _isPlaying = true;
      _position = Duration.zero;
    });
  }

  Future<void> _seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Музыка'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'URL / Сохранённые'),
              Tab(text: 'Устройство'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: 'URL аудио (mp3)',
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: _urlController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _urlController.clear(),
                            )
                          : null,
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _downloading
                          ? null
                          : () async {
                              await _downloadAndPlayAudio(_urlController.text);
                            },
                      icon: _downloading
                          ? const CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)
                          : const Icon(Icons.download),
                      label: _downloading
                          ? const Text('Загрузка...')
                          : const Text('Загрузить и воспроизвести'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_currentAudioPath.isNotEmpty)
                    AudioPlayerWidget(
                      duration: _duration,
                      position: _position,
                      isPlaying: _isPlaying,
                      onPlayPause: () async {
                        if (_isPlaying) {
                          await _audioPlayer.pause();
                        } else {
                          await _audioPlayer.resume();
                        }
                        setState(() {
                          _isPlaying = !_isPlaying;
                        });
                      },
                      onSeek: _seekTo,
                      audioPath: _currentAudioPath,
                    ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _savedAudios.isEmpty
                        ? const Center(child: Text('Нет сохранённых аудио'))
                        : ListView.builder(
                            itemCount: _savedAudios.length,
                            itemBuilder: (context, index) {
                              final item = _savedAudios[index];
                              final isActive =
                                  _currentAudioPath == item.localPath;

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: Icon(
                                    isActive
                                        ? (_isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow)
                                        : Icons.music_note,
                                    color: isActive ? Colors.blue : null,
                                  ),
                                  title: Text(item.title),
                                  subtitle: Text(item.url),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.play_arrow),
                                    onPressed: () =>
                                        _playAudio(item.localPath, item),
                                  ),
                                  onTap: () => _playAudio(item.localPath, item),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            _isLoadingLocal
                ? const Center(child: CircularProgressIndicator())
                : _localAudioFiles.isEmpty
                    ? const Center(
                        child: Text(
                          'Аудиофайлы не найдены',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _localAudioFiles.length,
                        itemBuilder: (context, index) {
                          final path = _localAudioFiles[index];
                          final fileName = path.split('/').last;
                          final isActive = _currentAudioPath == path;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Icon(
                                isActive
                                    ? (_isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow)
                                    : Icons.music_note,
                                color: isActive ? Colors.blue : null,
                              ),
                              title: Text(
                                fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                path
                                    .split('/')
                                    .sublist(0, path.split('/').length - 1)
                                    .join('/'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.play_arrow),
                                onPressed: () => _playAudio(path, null),
                              ),
                              onTap: () => _playAudio(path, null),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}
