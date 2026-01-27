import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'audio_handler.dart';
import 'dart:ui';
import 'dart:async';
import 'add_song_screen.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'media_item_model.dart';

// --- Função Principal da Aplicação ---
void main() async {
  // Garante que o Flutter está pronto
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(MediaItemModelAdapter());
  await Hive.openBox<MediaItemModel>('mediaItems');
  

  // Agora, inicializa o serviço de áudio
  final audioHandler = await initAudioService();
  
  // Inicia a aplicação
  runApp(MyApp(audioHandler: audioHandler));
}

// --- Classe Principal da Aplicação ---
class MyApp extends StatelessWidget {
  final AudioHandler audioHandler;
  const MyApp({super.key, required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flame Sound',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 0, 0, 0),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: MusicListScreen(audioHandler: audioHandler),
    );
  }
}

// --- Ecrã Principal (Lista de Músicas) ---
class MusicListScreen extends StatefulWidget {
  final AudioHandler audioHandler;
  const MusicListScreen({super.key, required this.audioHandler});

  @override
  State<MusicListScreen> createState() => _MusicListScreenState();
}

class _MusicListScreenState extends State<MusicListScreen> {

  late StreamSubscription<List<MediaItem>> _queueSubscription;
  String _searchQuery = '';
  List<MediaItem> _allMediaItems = [];

void _loadFromHive() async {
  final box = Hive.box<MediaItemModel>('mediaItems');

  if (box.isEmpty) return;

  final items = box.values.map((e) => e.toMediaItem()).toList();

  await widget.audioHandler.updateQueue(items);
}


  @override
  void initState() {
    super.initState();
    _loadFromHive();

    _queueSubscription = widget.audioHandler.queue.listen((queue) {
      setState(() {
        _allMediaItems = queue;
      });
    });
  }

  @override
  void dispose() {
    _queueSubscription.cancel();
    super.dispose();
  }

  void _showDeleteConfirmation(BuildContext context, MediaItem mediaItem) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2c2c2c),
          title: const Text("Remover Música"),
          content: Text("Tem a certeza de que quer remover '${mediaItem.title}' da sua biblioteca?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Fecha o diálogo
              },
            ),
            TextButton(
              child: Text("Remover", style: TextStyle(color: Colors.red.shade300)),
              onPressed: () async {
                final box = Hive.box<MediaItemModel>('mediaItems');

                await box.delete(mediaItem.id);
                await widget.audioHandler.removeQueueItem(mediaItem);

                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredMediaItems = _searchQuery.isEmpty
        ? _allMediaItems
        : _allMediaItems.where((item) {
            final titleMatches = item.title.toLowerCase().startsWith(_searchQuery);
            final artistMatches = item.artist?.toLowerCase().startsWith(_searchQuery) ?? false;
            return titleMatches || artistMatches;
          }).toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 83, 20, 1).withOpacity(0.5),
        elevation: 0,
        toolbarHeight: 180, // Aumentado para caber o botão
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('FlameSound'),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Procurar faixas ou artistas...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: GestureDetector(
                onTap: () async {
                  final shuffled = [..._allMediaItems]..shuffle();
                  await widget.audioHandler.updateQueue(shuffled);
                  await widget.audioHandler.skipToQueueItem(0);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.shuffle,
                      color: Colors.white,
                    )
                  )
                ),
              ),
            ),
          ],
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color.fromARGB(255, 65, 37, 6), Colors.black],
          ),
        ),
         child: _allMediaItems.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : filteredMediaItems.isEmpty
                ? const Center(child: Text('Nenhum resultado encontrado.'))
                : ListView.builder(
                    itemCount: filteredMediaItems.length,
                    itemBuilder: (context, index) {
                      final mediaItem = filteredMediaItems[index];
                      return StreamBuilder<MediaItem?>(
                        stream: widget.audioHandler.mediaItem,
                        builder: (context, currentItemSnapshot) {
                          final currentMediaItem = currentItemSnapshot.data;
                          final isCurrentlyPlayingSong = mediaItem.id == currentMediaItem?.id;

                          return ListTile(
                            // 2. O 'leading' agora depende se a música está a tocar
                            leading: _buildLeadingIcon(mediaItem, isCurrentlyPlayingSong),
                            title: Text(
                              mediaItem.title,
                              style: TextStyle(
                                color: isCurrentlyPlayingSong ? Color.fromARGB(253, 255, 230, 7) : Colors.white,
                                fontWeight: isCurrentlyPlayingSong ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(mediaItem.artist ?? '', style: TextStyle(color: Colors.grey.shade400)),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.grey.shade600),
                              onPressed: () {
                                _showDeleteConfirmation(context, mediaItem);
                              },
                            ),
                            onTap: () async {
                              final queue = widget.audioHandler.queue.value;

                              if (queue.isEmpty) {
                                print("Fila ainda está sendo carregada...");
                                return; // ou exiba um snackbar, por exemplo
                              }

                              await widget.audioHandler.skipToQueueItem(index);
                            },
                          );
                        },
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddSongScreen(audioHandler: widget.audioHandler)),
          );
        },
        backgroundColor: Colors.orange.shade800,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: _buildMiniPlayer(),
    );
  }

  void _shuffleAndPlay() async {
  if (_allMediaItems.isEmpty) return;

  final shuffled = List<MediaItem>.from(_allMediaItems)..shuffle();
  await widget.audioHandler.updateQueue(shuffled);
  await Future.delayed(const Duration(milliseconds: 100));
  await widget.audioHandler.skipToQueueItem(0);
}

  Widget _buildLeadingIcon(MediaItem mediaItem, bool isCurrentlyPlayingSong) {
    if (isCurrentlyPlayingSong) {
      return StreamBuilder<PlaybackState>(
        stream: widget.audioHandler.playbackState,
        builder: (context, playbackStateSnapshot) {
          final playing = playbackStateSnapshot.data?.playing ?? false;
          if (playing) {
            // CORREÇÃO: Usar Image.asset para mostrar o GIF animado
            return CircleAvatar(
              backgroundColor: Colors.transparent,
              child: Image.asset(
                'assets/images/equalizador.gif',
                width: 24,
                height: 24,
              ),
            );
          } else {
            return const CircleAvatar(
              backgroundColor: Colors.transparent,
              child: Icon(Icons.pause, color: Colors.white),
            );
          }
        },
      );
    } else {
      return CircleAvatar(
        backgroundImage: null,
        child: const Icon(Icons.music_note, color: Colors.white),
      );
    }
  }

  Widget _buildMiniPlayer() {
    return StreamBuilder<MediaItem?>(
      stream: widget.audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlayerScreen(audioHandler: widget.audioHandler),
              ),
            );
          },
          child: Container(
            height: 65,
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4)),
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(mediaItem.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
                            Text(mediaItem.artist ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade400), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      StreamBuilder<PlaybackState>(
                        stream: widget.audioHandler.playbackState,
                        builder: (context, snapshot) {
                          final playing = snapshot.data?.playing ?? false;
                          return IconButton(
                            icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white),
                            iconSize: 32.0,
                            onPressed: playing ? widget.audioHandler.pause : widget.audioHandler.play,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- Ecrã Completo do Leitor ---
class PlayerScreen extends StatelessWidget {
  final AudioHandler audioHandler;
  const PlayerScreen({super.key, required this.audioHandler});

  String _formatDuration(Duration? d) {
    if (d == null) return "--:--";
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return const SizedBox.shrink();

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [const Color.fromARGB(255, 3, 2, 0), Colors.black],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      mediaItem.artUri?.toString() ?? 'https://placehold.co/600x600/2a0a59/FFFFFF?text=Capa',
                      height: MediaQuery.of(context).size.width * 0.8,
                      width: MediaQuery.of(context).size.width * 0.8,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Image.network('https://placehold.co/600x600/2a0a59/FFFFFF?text=Capa'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(mediaItem.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(mediaItem.artist ?? '', style: TextStyle(fontSize: 18, color: Colors.grey.shade400)),
                  const SizedBox(height: 32),
                  _buildProgressBar(audioHandler, mediaItem.duration),
                  const SizedBox(height: 16),
                  _buildControlButtons(audioHandler),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  

  Widget _buildProgressBar(AudioHandler audioHandler, Duration? mediaDuration) {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snapshot) {
        final playbackState = snapshot.data;
        final position = playbackState?.position ?? Duration.zero;
        final totalDuration = mediaDuration ?? Duration.zero;

        final sliderValue = position.inSeconds.toDouble().clamp(0.0, totalDuration.inSeconds.toDouble());
        final sliderMax = totalDuration.inSeconds.toDouble() > 0 ? totalDuration.inSeconds.toDouble() : 1.0;

        return Column(
          children: [
            Slider(
              value: sliderValue,
              max: sliderMax,
              onChanged: (value) {
                audioHandler.seek(Duration(seconds: value.toInt()));
              },
              activeColor: Colors.white,
              inactiveColor: Colors.white.withOpacity(0.3),
            ),
            // 3. Adicionamos a linha com os tempos
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(position), style: const TextStyle(color: Colors.white70)),
                  Text(_formatDuration(totalDuration), style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlButtons(AudioHandler audioHandler) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround, // 4. Melhorar o espaçamento
      children: [
        // 5. Botão de Shuffle
        StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (context, snapshot) {
            final shuffleMode = snapshot.data?.shuffleMode ?? AudioServiceShuffleMode.none;
            final isEnabled = shuffleMode == AudioServiceShuffleMode.all;
            return IconButton(
              icon: Icon(Icons.shuffle, color: isEnabled ? Colors.white : Colors.grey.shade400),
              onPressed: () {
                final newMode = isEnabled ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all;
                audioHandler.setShuffleMode(newMode);
              },
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous, color: Colors.white, size: 40),
          onPressed: audioHandler.skipToPrevious,
        ),
        StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (context, snapshot) {
            final playing = snapshot.data?.playing ?? false;
            return Container(
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: IconButton(
                icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.deepPurple),
                iconSize: 48.0,
                onPressed: playing ? audioHandler.pause : audioHandler.play,
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.skip_next, color: Colors.white, size: 40),
          onPressed: audioHandler.skipToNext,
        ),
        // 6. Botão de Repeat
        StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (context, snapshot) {
            final repeatMode = snapshot.data?.repeatMode ?? AudioServiceRepeatMode.none;
            const icons = {
              AudioServiceRepeatMode.none: Icon(Icons.repeat),
              AudioServiceRepeatMode.one: Icon(Icons.repeat_one),
              AudioServiceRepeatMode.all: Icon(Icons.repeat),
              AudioServiceRepeatMode.group: Icon(Icons.repeat),
            };
            const cycle = [
              AudioServiceRepeatMode.none,
              AudioServiceRepeatMode.all,
              AudioServiceRepeatMode.one,
            ];
            final index = cycle.indexOf(repeatMode);
            final nextIndex = (index + 1) % cycle.length;
            final newMode = cycle[nextIndex];
            return IconButton(
              icon: icons[repeatMode]!,
              color: repeatMode == AudioServiceRepeatMode.none ? Colors.grey.shade400 : Colors.white,
              onPressed: () {
                audioHandler.setRepeatMode(newMode);
              },
            );
          },
        ),
      ],
    );
  }
}
