// lib/add_song_screen.dart

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_service/audio_service.dart';
import 'package:hive/hive.dart';

import 'media_item_model.dart';

class AddSongScreen extends StatefulWidget {
  const AddSongScreen({super.key});

  @override
  State<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends State<AddSongScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  List<SongModel> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoad();
  }

  Future<void> _requestPermissionAndLoad() async {
    final status = await Permission.audio.request();
    if (status.isGranted) {
      _loadSongs();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadSongs() async {
    final songs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
    );

    setState(() {
      _songs = songs.where((s) => s.isMusic!).toList();
      _loading = false;
    });
  }

  Future<void> _addSong(SongModel song) async {
    final box = Hive.box<MediaItemModel>('mediaItems');

    final mediaItem = MediaItem(
      id: song.id.toString(),
      title: song.title,
      artist: song.artist,
      duration: Duration(milliseconds: song.duration ?? 0),
      extras: {
        'filePath': song.data,
      },
    );

    await box.put(
      mediaItem.id,
      MediaItemModel.fromMediaItem(mediaItem),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${song.title} adicionada')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Músicas do dispositivo'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _songs.length,
              itemBuilder: (context, index) {
                final song = _songs[index];
                return ListTile(
                  leading: const Icon(Icons.music_note),
                  title: Text(song.title),
                  subtitle: Text(song.artist ?? 'Desconhecido'),
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addSong(song),
                  ),
                );
              },
            ),
    );
  }
}
