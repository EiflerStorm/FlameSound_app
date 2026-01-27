import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

Future<AudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.app_flame_sound.channel.audio',
      androidNotificationChannelName: 'Music playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();

  ConcatenatingAudioSource? _playlist;

  final _processingStateController =
      BehaviorSubject<AudioProcessingState>.seeded(AudioProcessingState.idle);

  List<MediaItem> _originalQueue = [];
  bool _isUpdatingQueue = false;

  MyAudioHandler() {
    _player.playbackEventStream.listen((event) {
      playbackState.add(_transformEvent(event));
    });

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  AudioSource _audioSourceForMediaItem(MediaItem item) {
    final streamUrl = item.extras?['streamUrl'];
    if (streamUrl != null && streamUrl.toString().isNotEmpty) {
      return AudioSource.uri(Uri.parse(streamUrl.toString()), tag: item);
    }

    final path = item.extras?['filePath'];
    if (path == null || path.isEmpty) {
      throw Exception('Fonte de áudio ausente no MediaItem');
    }
    return AudioSource.file(path, tag: item);
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _player.currentIndex,
    );
  }

  // ---------------------------
  // FILA
  // ---------------------------
  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    _isUpdatingQueue = true;

    _originalQueue = List.from(mediaItems);
    queue.add(mediaItems);

    _playlist = ConcatenatingAudioSource(
      children: mediaItems.map((item) {
        return _audioSourceForMediaItem(item);
      }).toList(),
    );

    await _player.setAudioSource(_playlist!);

    _isUpdatingQueue = false;
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    if (_playlist == null) {
      await addQueueItems([mediaItem]);
      return;
    }

    _isUpdatingQueue = true;
    final updatedQueue = [...queue.value, mediaItem];
    queue.add(updatedQueue);
    _originalQueue = List.from(updatedQueue);
    await _playlist!.add(_audioSourceForMediaItem(mediaItem));
    _isUpdatingQueue = false;
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (_isUpdatingQueue) return;
    if (index < 0 || index >= queue.value.length) return;

    mediaItem.add(queue.value[index]);
    await _player.seek(Duration.zero, index: index);
    play();
  }

  // ---------------------------
  // CONTROLES
  // ---------------------------
  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
      mediaItem.add(queue.value[_player.currentIndex!]);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
      mediaItem.add(queue.value[_player.currentIndex!]);
    }
  }

  // ---------------------------
  // SHUFFLE / REPEAT
  // ---------------------------
  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    await _player.setShuffleModeEnabled(enabled);

    if (enabled) {
      await _player.shuffle();
    }

    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    LoopMode loopMode = LoopMode.off;

    if (repeatMode == AudioServiceRepeatMode.one) {
      loopMode = LoopMode.one;
    } else if (repeatMode == AudioServiceRepeatMode.all) {
      loopMode = LoopMode.all;
    }

    await _player.setLoopMode(loopMode);
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  // ---------------------------
  // ATUALIZA FILA
  // ---------------------------
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    _isUpdatingQueue = true;
    queue.add(newQueue);
    _originalQueue = List.from(newQueue);

    _playlist = ConcatenatingAudioSource(
      children: newQueue.map((item) {
        return _audioSourceForMediaItem(item);
      }).toList(),
    );

    await _player.setAudioSource(_playlist!);
    _isUpdatingQueue = false;
  }

  @override
  Future<void> stop() async {
    await _player.stop();
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'dispose') {
      await _player.dispose();
      super.stop();
    }
  }
}
