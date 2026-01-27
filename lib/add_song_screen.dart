// lib/add_song_screen.dart

import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import 'media_item_model.dart';

class AddSongScreen extends StatefulWidget {
  final AudioHandler audioHandler;
  const AddSongScreen({super.key, required this.audioHandler});

  @override
  State<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends State<AddSongScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final TextEditingController _searchController = TextEditingController();
  List<SongModel> _songs = [];
  List<OnlineTrack> _onlineResults = [];
  bool _loadingDevice = true;
  bool _loadingOnline = false;
  String? _onlineError;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionAndLoad() async {
    final status = await Permission.audio.request();
    if (status.isGranted) {
      _loadSongs();
    } else {
      setState(() => _loadingDevice = false);
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
      _loadingDevice = false;
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
    await widget.audioHandler.addQueueItem(mediaItem);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${song.title} adicionada')),
      );
    }
  }

  Future<void> _searchOnline() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loadingOnline = true;
      _onlineError = null;
    });

    final uri = Uri.https('itunes.apple.com', '/search', {
      'term': query,
      'media': 'music',
      'entity': 'song',
      'limit': '25',
    });

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Erro ao buscar músicas (${response.statusCode})');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (data['results'] as List<dynamic>)
          .map((item) => OnlineTrack.fromJson(item as Map<String, dynamic>))
          .where((track) => track.previewUrl.isNotEmpty)
          .toList();

      setState(() {
        _onlineResults = results;
      });
    } catch (error) {
      setState(() {
        _onlineError = 'Não foi possível buscar músicas online.';
      });
    } finally {
      setState(() {
        _loadingOnline = false;
      });
    }
  }

  Future<void> _addOnlineTrack(OnlineTrack track) async {
    final box = Hive.box<MediaItemModel>('mediaItems');

    final mediaItem = MediaItem(
      id: 'itunes-${track.id}',
      title: track.title,
      artist: track.artist,
      duration: Duration(milliseconds: track.durationMs ?? 0),
      artUri: track.artworkUrl.isNotEmpty ? Uri.parse(track.artworkUrl) : null,
      extras: {
        'filePath': '',
        'streamUrl': track.previewUrl,
      },
    );

    await box.put(
      mediaItem.id,
      MediaItemModel.fromMediaItem(mediaItem),
    );
    await widget.audioHandler.addQueueItem(mediaItem);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${track.title} adicionada')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Adicionar músicas'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Dispositivo'),
              Tab(text: 'Online'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _loadingDevice
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchOnline(),
                    decoration: InputDecoration(
                      hintText: 'Pesquisar músicas na internet',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _searchOnline,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_loadingOnline) const LinearProgressIndicator(),
                  if (_onlineError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        _onlineError!,
                        style: TextStyle(color: Colors.red.shade200),
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _onlineResults.length,
                      itemBuilder: (context, index) {
                        final track = _onlineResults[index];
                        return ListTile(
                          leading: track.artworkUrl.isNotEmpty
                              ? Image.network(track.artworkUrl, width: 50, height: 50, fit: BoxFit.cover)
                              : const Icon(Icons.music_note),
                          title: Text(track.title),
                          subtitle: Text(track.artist),
                          trailing: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => _addOnlineTrack(track),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnlineTrack {
  final String id;
  final String title;
  final String artist;
  final String previewUrl;
  final String artworkUrl;
  final int? durationMs;

  const OnlineTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.previewUrl,
    required this.artworkUrl,
    required this.durationMs,
  });

  factory OnlineTrack.fromJson(Map<String, dynamic> json) {
    return OnlineTrack(
      id: (json['trackId'] ?? json['collectionId'] ?? json['artistId']).toString(),
      title: (json['trackName'] ?? 'Sem título').toString(),
      artist: (json['artistName'] ?? 'Artista desconhecido').toString(),
      previewUrl: (json['previewUrl'] ?? '').toString(),
      artworkUrl: (json['artworkUrl100'] ?? '').toString(),
      durationMs: json['trackTimeMillis'] as int?,
    );
  }
}
