import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // Pour compute (optimisation)
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:dio/dio.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:archive/archive_io.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'video_editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

final AudioPlayer globalAudioPlayer = AudioPlayer();
QuranAudioHandler? globalAudioHandler;

/// Gestionnaire audio natif (iOS MPNowPlayingInfoCenter / MPRemoteCommandCenter & Android MediaSession)
/// Garantit que les boutons Suivant/Précédent/Pause et la Timeline restent actifs en permanence
/// sans saturer la mémoire avec une playlist vidéo complète ni bloquer le thread principal iOS.
class QuranAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player;
  Future<void> Function()? onSkipToNext;
  Future<void> Function()? onSkipToPrevious;

  QuranAudioHandler(this.player) {
    player.playbackEventStream.listen(
      (_) => _broadcastState(),
      onError: (Object e, StackTrace st) {
        debugPrint('PlaybackEvent error: $e');
      },
    );
    player.playerStateStream.listen((_) => _broadcastState());
    player.durationStream.listen((duration) {
      final currentItem = mediaItem.value;
      if (currentItem != null &&
          duration != null &&
          duration > Duration.zero &&
          currentItem.duration != duration) {
        mediaItem.add(currentItem.copyWith(duration: duration));
      }
      _broadcastState();
    });
  }

  void updateCurrentMediaItem(MediaItem item) {
    mediaItem.add(item);
    _broadcastState();
  }

  void refreshState() => _broadcastState();

  void _broadcastState() {
    final playing = player.playing;
    final procState = const {
      ProcessingState.idle: AudioProcessingState.idle,
      ProcessingState.loading: AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready: AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    }[player.processingState] ?? AudioProcessingState.idle;

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.playPause,
        MediaAction.stop,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: procState,
      playing: playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: 0,
    ));
  }

  @override
  Future<void> play() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (_) {}
    await player.play();
    _broadcastState();
  }

  @override
  Future<void> pause() async {
    await player.pause();
    _broadcastState();
  }

  @override
  Future<void> seek(Duration position) async {
    await player.seek(position);
    _broadcastState();
  }

  @override
  Future<void> stop() async {
    await player.pause();
    await player.seek(Duration.zero);
    _broadcastState();
  }

  @override
  Future<void> skipToNext() async {
    if (onSkipToNext != null) {
      await onSkipToNext!();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (onSkipToPrevious != null) {
      await onSkipToPrevious!();
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  } else {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      globalAudioHandler = await AudioService.init(
        builder: () => QuranAudioHandler(globalAudioPlayer),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.muhammad.luhaidan.app',
          androidNotificationChannelName: 'Quran Library',
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: false,
          androidNotificationIcon: 'mipmap/ic_launcher',
        ),
      );
    } catch (e) {
      debugPrint("AudioService init error: $e");
    }
  }
  runApp(const QuranLibraryApp());
}

class ProxyServer {
  static HttpServer? _server;
  static int? port;
  static final Map<String, _CachedUrl> _urlCache = {};
  
  static Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = _server!.port;
    _server!.listen((HttpRequest request) async {
      try {
        final targetUrl = request.uri.queryParameters['url'];
        if (targetUrl != null) {
          _cleanCache();
          if (_urlCache.containsKey(targetUrl) && _urlCache[targetUrl]!.isValid) {
            try { await request.response.redirect(Uri.parse(_urlCache[targetUrl]!.url), status: HttpStatus.movedTemporarily); } catch (_) {}
            return;
          }
          
          final streamUrl = await MediaExtractor.getDownloadUrl(targetUrl);
          if (streamUrl != null) {
            _urlCache[targetUrl] = _CachedUrl(streamUrl);
            try { await request.response.redirect(Uri.parse(streamUrl), status: HttpStatus.movedTemporarily); } catch (_) {}
          } else {
            try { request.response.statusCode = 404; } catch (_) {}
          }
          return;
        }
      } catch (_) {
        try { request.response.statusCode = 500; } catch (_) {}
      } finally {
        try { await request.response.close(); } catch (_) {}
      }
    });
  }

  static void _cleanCache() {
    _urlCache.removeWhere((key, value) => !value.isValid);
  }

  static String getProxyUrl(String originalUrl) => 'http://127.0.0.1:$port/?url=${Uri.encodeComponent(originalUrl)}';
}

class _CachedUrl {
  final String url;
  final DateTime expiresAt;
  _CachedUrl(this.url) : expiresAt = DateTime.now().add(const Duration(hours: 2));
  bool get isValid => DateTime.now().isBefore(expiresAt);
}

const List<Map<String, dynamic>> ALL_SURAHS = [
  {"num": 1, "name": "Al-Fatiha"}, {"num": 2, "name": "Al-Baqarah"}, {"num": 3, "name": "Al-Imran"}, {"num": 4, "name": "An-Nisa"},
  {"num": 5, "name": "Al-Maidah"}, {"num": 6, "name": "Al-An'am"}, {"num": 7, "name": "Al-A'raf"}, {"num": 8, "name": "Al-Anfal"},
  {"num": 9, "name": "At-Tawbah"}, {"num": 10, "name": "Yunus"}, {"num": 11, "name": "Hud"}, {"num": 12, "name": "Yusuf"},
  {"num": 13, "name": "Ar-Ra'd"}, {"num": 14, "name": "Ibrahim"}, {"num": 15, "name": "Al-Hijr"}, {"num": 16, "name": "An-Nahl"},
  {"num": 17, "name": "Al-Isra"}, {"num": 18, "name": "Al-Kahf"}, {"num": 19, "name": "Maryam"}, {"num": 20, "name": "Ta-Ha"},
  {"num": 21, "name": "Al-Anbiya"}, {"num": 22, "name": "Al-Hajj"}, {"num": 23, "name": "Al-Mu'minun"}, {"num": 24, "name": "An-Nur"},
  {"num": 25, "name": "Al-Furqan"}, {"num": 26, "name": "Ash-Shu'ara"}, {"num": 27, "name": "An-Naml"}, {"num": 28, "name": "Al-Qasas"},
  {"num": 29, "name": "Al-'Ankabut"}, {"num": 30, "name": "Ar-Rum"}, {"num": 31, "name": "Luqman"}, {"num": 32, "name": "As-Sajdah"},
  {"num": 33, "name": "Al-Ahzab"}, {"num": 34, "name": "Saba"}, {"num": 35, "name": "Fatir"}, {"num": 36, "name": "Ya-Sin"},
  {"num": 37, "name": "As-Saffat"}, {"num": 38, "name": "Sad"}, {"num": 39, "name": "Az-Zumar"}, {"num": 40, "name": "Ghafir"},
  {"num": 41, "name": "Fussilat"}, {"num": 42, "name": "Ash-Shura"}, {"num": 43, "name": "Az-Zukhruf"}, {"num": 44, "name": "Ad-Dukhan"},
  {"num": 45, "name": "Al-Jathiyah"}, {"num": 46, "name": "Al-Ahqaf"}, {"num": 47, "name": "Muhammad"}, {"num": 48, "name": "Al-Fath"},
  {"num": 49, "name": "Al-Hujurat"}, {"num": 50, "name": "Qaf"}, {"num": 51, "name": "Adh-Dhariyat"}, {"num": 52, "name": "At-Tur"},
  {"num": 53, "name": "An-Najm"}, {"num": 54, "name": "Al-Qamar"}, {"num": 55, "name": "Ar-Rahman"}, {"num": 56, "name": "Al-Waqi'ah"},
  {"num": 57, "name": "Al-Hadid"}, {"num": 58, "name": "Al-Mujadila"}, {"num": 59, "name": "Al-Hashr"}, {"num": 60, "name": "Al-Mumtahanah"},
  {"num": 61, "name": "As-Saf"}, {"num": 62, "name": "Al-Jumu'ah"}, {"num": 63, "name": "Al-Munafiqun"}, {"num": 64, "name": "At-Taghabun"},
  {"num": 65, "name": "At-Talaq"}, {"num": 66, "name": "At-Tahrim"}, {"num": 67, "name": "Al-Mulk"}, {"num": 68, "name": "Al-Qalam"},
  {"num": 69, "name": "Al-Haqqah"}, {"num": 70, "name": "Al-Ma'arij"}, {"num": 71, "name": "Nuh"}, {"num": 72, "name": "Al-Jinn"},
  {"num": 73, "name": "Al-Muzzammil"}, {"num": 74, "name": "Al-Muddaththir"}, {"num": 75, "name": "Al-Qiyamah"}, {"num": 76, "name": "Al-Insan"},
  {"num": 77, "name": "Al-Mursalat"}, {"num": 78, "name": "An-Naba"}, {"num": 79, "name": "An-Nazi'at"}, {"num": 80, "name": "Abasa"},
  {"num": 81, "name": "At-Takwir"}, {"num": 82, "name": "Al-Infitar"}, {"num": 83, "name": "Al-Mutaffifin"}, {"num": 84, "name": "Al-Inshiqaq"},
  {"num": 85, "name": "Al-Buruj"}, {"num": 86, "name": "At-Tariq"}, {"num": 87, "name": "Al-A'la"}, {"num": 88, "name": "Al-Ghashiyah"},
  {"num": 89, "name": "Al-Fajr"}, {"num": 90, "name": "Al-Balad"}, {"num": 91, "name": "Ash-Shams"}, {"num": 92, "name": "Al-Layl"},
  {"num": 93, "name": "Ad-Duha"}, {"num": 94, "name": "Ash-Sharh"}, {"num": 95, "name": "At-Tin"}, {"num": 96, "name": "Al-'Alaq"},
  {"num": 97, "name": "Al-Qadr"}, {"num": 98, "name": "Al-Bayyinah"}, {"num": 99, "name": "Az-Zalzalah"}, {"num": 100, "name": "Al-'Adiyat"},
  {"num": 101, "name": "Al-Qari'ah"}, {"num": 102, "name": "At-Takathur"}, {"num": 103, "name": "Al-'Asr"}, {"num": 104, "name": "Al-Humazah"},
  {"num": 105, "name": "Al-Fil"}, {"num": 106, "name": "Quraysh"}, {"num": 107, "name": "Al-Ma'un"}, {"num": 108, "name": "Al-Kawthar"},
  {"num": 109, "name": "Al-Kafirun"}, {"num": 110, "name": "An-Nasr"}, {"num": 111, "name": "Al-Masad"}, {"num": 112, "name": "Al-Ikhlas"},
  {"num": 113, "name": "Al-Falaq"}, {"num": 114, "name": "An-Nas"},
];

enum LoopModeState { off, autoplay, one }

bool isRemoteMediaUrl(String? path) {
  if (path == null || path.trim().isEmpty) return false;
  final s = path.trim().toLowerCase();
  return s.startsWith('http://') ||
      s.startsWith('https://') ||
      s.contains('://') ||
      s.contains('youtube.com') ||
      s.contains('youtu.be') ||
      s.contains('instagram.com') ||
      s.contains('instagr.am') ||
      s.contains('tiktok.com') ||
      s.contains('twitter.com') ||
      s.contains('x.com') ||
      s.contains('facebook.com') ||
      s.contains('fb.watch');
}

class QuranLibraryApp extends StatelessWidget {
  const QuranLibraryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        primaryColor: const Color(0xFF7EB8C9),
        useMaterial3: true,
      ),
      home: const LibraryScreen(),
    );
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with WidgetsBindingObserver {
  List<dynamic> allRecitations = [];
  List<dynamic> displayedRecitations = [];
  final AudioPlayer _player = globalAudioPlayer;
  StreamSubscription? _positionSubscription; // NOUVEAU : Le garde-fou de la mémoire
  StreamSubscription? _playerStateSubscription;
  Map<String, dynamic>? currentRecitation;
  int _playRequestId = 0; // Fix race conditions during track change
  
  double volume = 0.8;
  LoopModeState loopMode = LoopModeState.off;
  int? selectedYearFilter;
  Database? _db;
  bool _isDownloading = false;
  bool _isSwitchingTrack = false;
  bool _isInBackground = false;
  bool _isExtractingAudioBg = false;
  String? _appDirPath;
  Map<int, double> _activeDownloads = {}; 

  Timer? _sleepTimer;
  Timer? _countdownTimer;
  DateTime? _timerEndTime;
  int _selectedTimerMinutes = 15;
  
  int? _playingIndex;
  int _lastPos = 0;
  int _lastDuration = 0;
  DateTime _lastWakeUp = DateTime.now(); // NOUVEAU : Le chronomètre de réveil

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // On allume le radar
    globalAudioHandler?.onSkipToNext = () async => _playNext();
    globalAudioHandler?.onSkipToPrevious = () async => _playPrevious();

    _initApp();
    _player.setVolume(volume);
    
    // On n'utilise PLUS le loop natif pour éviter les coupures audio ("hiccups") lors du toggle.
    _player.setLoopMode(LoopMode.off);

    _positionSubscription?.cancel();
    _positionSubscription = _player.positionStream.listen((pos) {
      int currentMs = pos.inMilliseconds;
      int durationMs = _player.duration?.inMilliseconds ?? 0;

      // FILTRE ANTI-HOQUET : On ignore les bonds temporels absurdes dans la seconde qui suit le réveil de l'app
      if (DateTime.now().difference(_lastWakeUp).inMilliseconds < 1000) return;

      _lastPos = currentMs;
      _lastDuration = durationMs;
    });

    _playerStateSubscription?.cancel();
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && !_isSwitchingTrack) {
        if (loopMode == LoopModeState.off) {
          _player.pause();
          _player.seek(Duration.zero);
          globalAudioHandler?.refreshState();
        } else if (loopMode == LoopModeState.one) {
          _player.seek(Duration.zero);
          _player.play();
          globalAudioHandler?.refreshState();
        } else {
          if (_playingIndex != null && _playingIndex! < displayedRecitations.length - 1) {
            _play(displayedRecitations[_playingIndex! + 1]);
          } else if (_playingIndex != null && _playingIndex! == displayedRecitations.length - 1 && loopMode == LoopModeState.autoplay) {
            _play(displayedRecitations[0]);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // On éteint le radar
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _sleepTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _initApp() async {
    try {
      // 1. On récupère le chemin personnalisé
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString('custom_storage_path');

      if (customPath != null && Directory(customPath).existsSync()) {
        _appDirPath = customPath;
      } else {
        final dir = await getApplicationDocumentsDirectory();
        _appDirPath = dir.path;
      }

      await ProxyServer.start(); 

      final path = p.join(_appDirPath!, 'luhaidan.db');
      
      // SÉCURITÉ : Si le fichier de BDD fait 0 octet (copie ratée), on le supprime pour éviter le crash
      final dbFile = File(path);
      if (await dbFile.exists() && await dbFile.length() == 0) {
        await dbFile.delete();
      }

      // 2. Ouverture sécurisée de la base de données
      _db = await openDatabase(
        path,
        version: 3, 
        onCreate: (db, version) => db.execute(
          'CREATE TABLE recitations(id INTEGER PRIMARY KEY AUTOINCREMENT, sourate_num INTEGER, sourate_name TEXT, annee INTEGER, annee_g INTEGER, fichier TEXT, versets TEXT, thumbnail TEXT, duration TEXT)'
        ),
        onUpgrade: (db, oldV, newV) {
          if (oldV < 2) {
            db.execute('ALTER TABLE recitations ADD COLUMN thumbnail TEXT');
            db.execute('ALTER TABLE recitations ADD COLUMN duration TEXT');
          }
          if (oldV < 3) {
            try { db.execute('ALTER TABLE recitations ADD COLUMN annee_g INTEGER'); } catch (_) {}
          }
        }
      );
      
      await _fetch();
      try { await _cleanupOrphans(); } catch (_) {}
      
      if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
        _checkPermissionsAndConnectivity();
        _ensureAudioFilesExtracted();
      }
      
    } catch (e) {
      // CELLULE DE SECOURS : Si le dossier personnalisé ou la BDD crashe, on réinitialise tout par défaut
      debugPrint("Mode secours activé : $e");
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('custom_storage_path'); // On oublie le mauvais dossier
      
      final dir = await getApplicationDocumentsDirectory();
      _appDirPath = dir.path;
      
      final fallbackPath = p.join(_appDirPath!, 'luhaidan.db');
      _db = await openDatabase(fallbackPath, version: 3);
      await _fetch();
    }
  }

  /// Recherche un fichier média local déjà présent sur le disque (priorise le fichier .m4a léger pour le lecteur audio)
  Future<File?> _findLocalMediaFile(Map<String, dynamic> rec, {bool preferAudioOnly = true}) async {
    if (_appDirPath == null) return null;
    final int? id = rec['id'] is int ? rec['id'] as int : int.tryParse(rec['id']?.toString() ?? '');
    final String fileStr = (rec['fichier'] ?? "").toString().trim();

    final List<String> candidates = [];
    if (preferAudioOnly && id != null) {
      candidates.add(p.join(_appDirPath!, "audio_$id.m4a"));
    }
    if (fileStr.isNotEmpty && !isRemoteMediaUrl(fileStr)) {
      candidates.add(_resolvePath(fileStr));
    }
    if (id != null) {
      candidates.add(p.join(_appDirPath!, "yt_$id.mp4"));
      candidates.add(p.join(_appDirPath!, "yt_$id.m4a"));
      candidates.add(p.join(_appDirPath!, "yt_$id.mp3"));
      if (!preferAudioOnly) {
        candidates.add(p.join(_appDirPath!, "audio_$id.m4a"));
      }
    }

    for (final candidatePath in candidates) {
      final f = File(candidatePath);
      if (await f.exists()) {
        final len = await f.length();
        if (len > 1024) {
          return f;
        }
      }
    }

    // Fallback : vérifier dans getApplicationDocumentsDirectory() si différent de _appDirPath
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      if (docsDir.path != _appDirPath) {
        final List<String> docCandidates = [];
        if (preferAudioOnly && id != null) {
          docCandidates.add(p.join(docsDir.path, "audio_$id.m4a"));
        }
        if (fileStr.isNotEmpty && !isRemoteMediaUrl(fileStr)) {
          docCandidates.add(p.join(docsDir.path, p.basename(fileStr)));
        }
        if (id != null) {
          docCandidates.add(p.join(docsDir.path, "yt_$id.mp4"));
        }
        for (final cPath in docCandidates) {
          final f = File(cPath);
          if (await f.exists() && await f.length() > 1024) {
            return f;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Extrait une piste audio pure (.m4a avec +faststart) à partir d'un fichier vidéo .mp4
  /// Réduit la consommation RAM de 95%, élimine le temps de chargement et stabilise le seek sur iOS.
  Future<File?> _extractFastAudio(File sourceVideo, int id) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS || _appDirPath == null) return null;
    if (!await sourceVideo.exists() || await sourceVideo.length() <= 1024) return null;

    final outPath = p.join(_appDirPath!, "audio_$id.m4a");
    final tempOutPath = p.join(_appDirPath!, "audio_${id}_temp.m4a");
    final tempOutFile = File(tempOutPath);

    try {
      if (await tempOutFile.exists()) await tempOutFile.delete();

      // 1. Essai ultra-rapide par copie directe du flux audio AAC (-vn -c:a copy -movflags +faststart)
      final copyCmd = "-y -i '${sourceVideo.path}' -vn -c:a copy -movflags +faststart '$tempOutPath'";
      final session1 = await FFmpegKit.execute(copyCmd);
      final rc1 = await session1.getReturnCode();

      if (ReturnCode.isSuccess(rc1) && await tempOutFile.exists() && await tempOutFile.length() > 1024) {
        final finalFile = File(outPath);
        if (await finalFile.exists()) await finalFile.delete();
        await tempOutFile.rename(outPath);
        return finalFile;
      }

      // 2. Fallback transcodage AAC (si le flux source était Opus / MP3 dans un conteneur MP4/WebM)
      if (await tempOutFile.exists()) await tempOutFile.delete();
      final aacCmd = "-y -i '${sourceVideo.path}' -vn -c:a aac -b:a 128k -movflags +faststart '$tempOutPath'";
      final session2 = await FFmpegKit.execute(aacCmd);
      final rc2 = await session2.getReturnCode();

      if (ReturnCode.isSuccess(rc2) && await tempOutFile.exists() && await tempOutFile.length() > 1024) {
        final finalFile = File(outPath);
        if (await finalFile.exists()) await finalFile.delete();
        await tempOutFile.rename(outPath);
        return finalFile;
      }
    } catch (e) {
      debugPrint("Erreur extraction audio rapide ($id): $e");
    } finally {
      try {
        if (await tempOutFile.exists()) await tempOutFile.delete();
      } catch (_) {}
    }
    return null;
  }

  /// Génère en arrière-plan les fichiers audio .m4a pour les récitations vidéo déjà téléchargées
  Future<void> _ensureAudioFilesExtracted() async {
    if (_isExtractingAudioBg || _appDirPath == null) return;
    _isExtractingAudioBg = true;
    try {
      await Future.delayed(const Duration(seconds: 2));
      final recsCopy = List<dynamic>.from(allRecitations);
      for (final rec in recsCopy) {
        if (!mounted) break;
        final int? id = rec['id'];
        if (id == null) continue;
        final audioFile = File(p.join(_appDirPath!, "audio_$id.m4a"));
        if (await audioFile.exists() && await audioFile.length() > 1024) continue;

        final videoFile = await _findLocalMediaFile(rec, preferAudioOnly: false);
        if (videoFile != null &&
            (videoFile.path.toLowerCase().endsWith('.mp4') || videoFile.path.toLowerCase().endsWith('.mov'))) {
          await _extractFastAudio(videoFile, id);
          await Future.delayed(const Duration(milliseconds: 250));
        }
      }
    } catch (_) {
    } finally {
      _isExtractingAudioBg = false;
    }
  }

  Future<void> _checkPermissionsAndConnectivity() async {
    // Demande dynamique des permissions
    await [
      Permission.storage,
      Permission.videos,
      Permission.audio,
    ].request();

    // Lancer la vérification des téléchargements manquants en arrière-plan
    _checkMissingDownloads();
  }

  Future<void> _checkMissingDownloads() async {
    if (_appDirPath == null) return;
    
    // Laisser le temps à l'application de s'afficher avant de solliciter le réseau
    await Future.delayed(const Duration(seconds: 3));
    
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) return; // Pas de connexion internet

    final recsCopy = List<dynamic>.from(allRecitations);
    for (var rec in recsCopy) {
      if (!mounted) break;
      String path = (rec['fichier'] ?? "").toString().trim();
      if (path.isEmpty || !isRemoteMediaUrl(path)) continue;

      final existingLocal = await _findLocalMediaFile(rec, preferAudioOnly: false);
      if (existingLocal == null) {
        final int id = rec['id'];
        if (!_activeDownloads.containsKey(id)) {
          try {
            final localFile = File(p.join(_appDirPath!, "yt_$id.mp4"));
            // Téléchargement séquentiel (await) pour ne jamais saturer la mémoire vive
            await _startDownload(id, path, localFile, deleteRecordOnFailure: false);
          } catch (e) {
            debugPrint("Auto-download failed for $id: $e");
          }
        }
      }
    }
  }

  Future<void> _cleanupOrphans() async {
    if (_appDirPath == null) return;
    final dir = Directory(_appDirPath!);
    final files = dir.listSync();
    
    // NOUVEAU : On récupère le chemin du brouillon pour le protéger
    final prefs = await SharedPreferences.getInstance();
    final draftPath = prefs.getString('draft_video_path');

    Set<String> validFiles = {'luhaidan.db', 'luhaidan.db-wal', 'luhaidan.db-shm'};
    if (draftPath != null) validFiles.add(p.basename(draftPath)); // Bouclier activé !

    for (var rec in allRecitations) {
      if (rec['fichier'] != null) validFiles.add(p.basename(rec['fichier']));
      if (rec['thumbnail'] != null) validFiles.add(p.basename(rec['thumbnail']));
      validFiles.add("yt_${rec['id']}.mp4");
      validFiles.add("yt_${rec['id']}.m4a");
      validFiles.add("yt_${rec['id']}.mp3");
      validFiles.add("audio_${rec['id']}.m4a");
      validFiles.add("thumb_yt_${rec['id']}.jpg");
      validFiles.add("temp_edit_${rec['id']}.mp4"); // Bouclier pour les fichiers en cours de montage !
    }
    
    for (var f in files) {
      if (f is File) {
        final basename = p.basename(f.path);
        if (basename.endsWith('.tmp')) {
          try { await f.delete(); } catch (_) {}
        } else if ((basename.endsWith('.mp4') || basename.endsWith('.m4a') || basename.endsWith('.jpg') || basename.endsWith('.mp3')) && !validFiles.contains(basename)) {
          try { await f.delete(); } catch (_) {}
        }
      }
    }
  }

  Future<void> _fetch() async {
    final res = await _db?.query('recitations', orderBy: 'sourate_num ASC');
    
    // NOUVEAU: Charger la dernière récitation écoutée AVANT d'appliquer les filtres
    final prefs = await SharedPreferences.getInstance();
    final lastPlayedId = prefs.getInt('last_played_id');

    setState(() {
      allRecitations = res ?? [];
      _applyFilters();
    });

    if (lastPlayedId != null && allRecitations.isNotEmpty && currentRecitation == null) {
      int idx = displayedRecitations.indexWhere((r) => r['id'] == lastPlayedId);
      if (idx != -1) {
        final candidate = displayedRecitations[idx];
        final localFile = await _findLocalMediaFile(candidate);
        if (localFile != null) {
          _play(candidate, autoPlay: false);
        } else {
          setState(() {
            currentRecitation = candidate;
            _playingIndex = idx;
          });
        }
      }
    }
    
    // NOUVEAU : Lance la réparation automatique en arrière-plan
    _checkMissingThumbnails(res ?? []);
  }

  Future<void> _checkMissingThumbnails(List<dynamic> recs) async {
    if (_appDirPath == null) return;
    bool hasUpdates = false;
    
    for (var rec in recs) {
      String thumb = (rec['thumbnail'] ?? "").toString();
      bool needsThumb = false;
      
      // On regarde s'il manque une miniature locale (ou si c'est encore un lien http distant qui bloque le mode hors-ligne)
      if (thumb.isEmpty || thumb.startsWith('http')) {
        needsThumb = true;
      } else {
        final thumbFile = File(p.join(_appDirPath!, thumb));
        if (!await thumbFile.exists() || await thumbFile.length() < 100) needsThumb = true;
      }

      // Si oui, on télécharge ou extrait une image locale sur le disque
      if (needsThumb) {
        String? savedThumbName;
        if (thumb.startsWith('http')) {
          try {
            final candidateName = "thumb_${rec['id']}.jpg";
            final dest = p.join(_appDirPath!, candidateName);
            await Dio().download(thumb, dest, options: Options(receiveTimeout: const Duration(seconds: 8)));
            if (await File(dest).exists() && await File(dest).length() > 100) {
              savedThumbName = candidateName;
            }
          } catch (_) {}
        }

        if (savedThumbName == null && !Platform.isWindows) {
          final videoFile = await _findLocalMediaFile(rec, preferAudioOnly: false);
          if (videoFile != null && videoFile.existsSync() && !videoFile.path.endsWith('.m4a') && !videoFile.path.endsWith('.mp3')) {
            try {
              final thumbData = await VideoThumbnail.thumbnailData(
                video: videoFile.path,
                imageFormat: ImageFormat.JPEG,
                maxWidth: 300,
                quality: 50,
              );
              if (thumbData != null && thumbData.isNotEmpty) {
                savedThumbName = "thumb_${rec['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg";
                await File(p.join(_appDirPath!, savedThumbName)).writeAsBytes(thumbData);
              }
            } catch (_) {}
          }
        }

        if (savedThumbName != null) {
          await _db?.update('recitations', {'thumbnail': savedThumbName}, where: 'id = ?', whereArgs: [rec['id']]);
          hasUpdates = true;
        }
      }
    }
    
    // Si on a réparé des choses, on met à jour l'écran tout seul !
    if (hasUpdates && mounted) {
      final updatedRes = await _db?.query('recitations', orderBy: 'sourate_num ASC');
      setState(() {
        allRecitations = updatedRes ?? [];
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    int? currentId = currentRecitation?['id']; // Sauvegarde l'ID unique de la piste en cours

    setState(() {
      if (selectedYearFilter == null) {
        displayedRecitations = allRecitations;
      } else if (selectedYearFilter == -1) {
        displayedRecitations = allRecitations.where((r) => r['annee'] == null).toList();
      } else {
        displayedRecitations = allRecitations.where((r) => r['annee'] == selectedYearFilter).toList();
      }

      // LE CORRECTIF ULTRA-ROBUSTE (Valable pour Ajout, Modif, Suppression et Filtres)
      if (currentId != null) {
        int newIndex = displayedRecitations.indexWhere((r) => r['id'] == currentId);
        if (newIndex != -1) {
          _playingIndex = newIndex;
          currentRecitation = displayedRecitations[newIndex];
        } else {
          // Sécurité : Si la récitation en cours a été supprimée ou est masquée par un filtre d'année
          _playingIndex = null;
          currentRecitation = null;
          _player.stop();
        }
      }
    });
  }

  MediaItem _createMediaItem(Map<String, dynamic> r) {
    Duration? exactDur;
    if (r['duration'] != null && r['duration'].toString().contains(':')) {
      try {
        final parts = r['duration'].toString().split(':');
        if (parts.length == 3) {
          exactDur = Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1]), seconds: int.parse(parts[2]));
        } else if (parts.length == 2) {
          exactDur = Duration(minutes: int.parse(parts[0]), seconds: int.parse(parts[1]));
        }
      } catch (_) {}
    }
    
    // CRITIQUE : Ne JAMAIS passer une URL http distante dans artUri car iOS (AudioServicePlugin)
    // appelle [NSData dataWithContentsOfURL:] de façon synchrone sur le thread principal,
    // ce qui bloque le lecteur hors-ligne et fige l'ouverture de l'application depuis l'écran verrouillé !
    Uri? artUri;
    if (r['thumbnail'] != null && r['thumbnail'].toString().isNotEmpty) {
      String resolved = _resolvePath(r['thumbnail'].toString());
      if (!resolved.startsWith('http')) {
        final f = File(resolved);
        if (f.existsSync()) {
          artUri = Uri.file(resolved);
        }
      }
    }
    return MediaItem(
      id: "recitation_${r['id']}",
      album: "Muhammad Al-Luhaidan",
      title: "${r['sourate_num'].toString().padLeft(3, '0')} - ${r['sourate_name']}",
      artist: "Muhammad Al-Luhaidan",
      artUri: artUri,
      duration: exactDur,
    );
  }

  String _resolvePath(String pathStr) {
    if (pathStr.startsWith('http')) return pathStr;
    if (pathStr.startsWith('/') || pathStr.contains(':\\')) return pathStr;
    return _appDirPath != null ? p.join(_appDirPath!, pathStr) : pathStr;
  }

  Future<void> _startDownload(int id, String rawUrl, File localFile, {bool deleteRecordOnFailure = true}) async {
    if (_activeDownloads.containsKey(id)) return;
    final cleanUrl = MediaExtractor.extractCleanUrl(rawUrl);

    if (mounted) setState(() => _activeDownloads[id] = 0.0);
    YoutubeExplode? yt;
    final tempFile = File("${localFile.path}.tmp");

    try {
      if (await tempFile.exists()) {
        try { await tempFile.delete(); } catch (_) {}
      }

      int expectedTotal = -1;
      int lastUpdateValue = 0;
      bool downloaded = false;
      String? remoteThumbUrl;
      Duration? extractedDuration;

      // 1. Si c'est un lien YouTube, on tente d'abord le flux natif YoutubeExplode (ultra-rapide sans bridage 403)
      if (MediaExtractor.isYouTubeUrl(cleanUrl)) {
        try {
          yt = YoutubeExplode();
          final video = await yt.videos.get(cleanUrl).timeout(const Duration(seconds: 15));
          extractedDuration = video.duration;
          remoteThumbUrl = video.thumbnails.mediumResUrl;

          final manifest = await yt.videos.streamsClient.getManifest(video.id).timeout(const Duration(seconds: 15));
          StreamInfo? streamInfo;
          final mp4Muxed = manifest.muxed.where((s) => s.container.name == 'mp4');
          if (mp4Muxed.isNotEmpty) {
            streamInfo = mp4Muxed.withHighestBitrate();
          } else if (manifest.muxed.isNotEmpty) {
            streamInfo = manifest.muxed.withHighestBitrate();
          } else {
            final mp4Audio = manifest.audioOnly.where((s) => s.container.name == 'mp4');
            streamInfo = mp4Audio.isNotEmpty ? mp4Audio.withHighestBitrate() : manifest.audioOnly.withHighestBitrate();
          }

          expectedTotal = streamInfo.size.totalBytes;
          final stream = yt.videos.streamsClient.get(streamInfo);
          final sink = tempFile.openWrite();
          int received = 0;

          await for (final chunk in stream) {
            sink.add(chunk);
            received += chunk.length;
            if (expectedTotal > 0) {
              int percentage = ((received / expectedTotal) * 100).clamp(0, 100).toInt();
              if (percentage != lastUpdateValue) {
                lastUpdateValue = percentage;
                if (mounted) setState(() => _activeDownloads[id] = percentage / 100.0);
              }
            } else {
              int step = (received / 250000).toInt();
              if (step != lastUpdateValue) {
                lastUpdateValue = step;
                if (mounted) setState(() => _activeDownloads[id] = -(received.toDouble()));
              }
            }
          }
          await sink.flush();
          await sink.close();
          if (await tempFile.exists() && await tempFile.length() > 5000) {
            downloaded = true;
          }
        } catch (e) {
          debugPrint("Fallback extracteur universel pour YouTube ($e)");
        } finally {
          yt?.close();
          yt = null;
        }
      }

      // 2. Extracteur Universel Multi-Sources ("Black Hole Splitter" engine : Instagram, TikTok, X, Facebook, YouTube fallback, Web...)
      if (!downloaded) {
        final extracted = await MediaExtractor.extractMedia(cleanUrl);
        if (extracted == null || extracted.url.isEmpty) {
          throw Exception("Impossible d'extraire la vidéo ou l'audio depuis ce lien (Lien privé ou protégé).");
        }

        remoteThumbUrl ??= extracted.thumbnailUrl;
        extractedDuration ??= extracted.duration;

        if (extracted.isHls || extracted.url.contains('.m3u8')) {
          // Flux HLS (.m3u8) -> Téléchargement et assemblage direct via FFmpegKit
          final cmd = "-y -i '${extracted.url}' -c copy -bsf:a aac_adtstoasc -movflags +faststart '${tempFile.path}'";
          final session = await FFmpegKit.execute(cmd);
          final rc = await session.getReturnCode();
          if (!ReturnCode.isSuccess(rc) || !await tempFile.exists() || await tempFile.length() < 5000) {
            throw Exception("Échec de l'assemblage du flux vidéo.");
          }
          downloaded = true;
        } else {
          expectedTotal = -1;
          lastUpdateValue = 0;
          await Dio().download(
            extracted.url,
            tempFile.path,
            options: Options(
              headers: extracted.headers,
              receiveTimeout: const Duration(seconds: 60),
              sendTimeout: const Duration(seconds: 20),
              followRedirects: true,
              maxRedirects: 8,
            ),
            onReceiveProgress: (received, total) {
              if (total > 0) {
                expectedTotal = total;
                int percentage = ((received / total) * 100).clamp(0, 100).toInt();
                if (percentage != lastUpdateValue) {
                  lastUpdateValue = percentage;
                  if (mounted) setState(() => _activeDownloads[id] = percentage / 100.0);
                }
              } else {
                int megabyteStep = (received / 250000).toInt();
                if (megabyteStep != lastUpdateValue) {
                  lastUpdateValue = megabyteStep;
                  if (mounted) setState(() => _activeDownloads[id] = -(received.toDouble()));
                }
              }
            },
          );

          // Si Reddit ou flux adaptatif possède une piste audio séparée, on fusionne vidéo + audio avec FFmpeg
          if (extracted.audioUrl != null && extracted.audioUrl!.isNotEmpty && !Platform.isWindows) {
            try {
              final tempAudio = File("${localFile.path}_audio.tmp");
              final tempMerged = File("${localFile.path}_merged.mp4");
              await Dio().download(extracted.audioUrl!, tempAudio.path, options: Options(headers: extracted.headers));
              if (await tempAudio.exists() && await tempAudio.length() > 1000) {
                final mergeCmd = "-y -i '${tempFile.path}' -i '${tempAudio.path}' -c:v copy -c:a aac -movflags +faststart '${tempMerged.path}'";
                final session = await FFmpegKit.execute(mergeCmd);
                if (ReturnCode.isSuccess(await session.getReturnCode()) && await tempMerged.exists()) {
                  await tempFile.delete();
                  await tempMerged.rename(tempFile.path);
                }
              }
              if (await tempAudio.exists()) await tempAudio.delete();
              if (await tempMerged.exists()) await tempMerged.delete();
            } catch (_) {}
          }
          downloaded = true;
        }
      }

      if (downloaded && await tempFile.exists() && await tempFile.length() > 2048) {
        if (expectedTotal > 0 && await tempFile.length() < (expectedTotal * 0.9)) {
          throw Exception("Téléchargement incomplet (le fichier a été coupé).");
        }

        if (await localFile.exists()) await localFile.delete();
        await tempFile.rename(localFile.path);

        // Extraction immédiate de la piste audio pure (.m4a +faststart) pour une lecture instantanée sans saturer la RAM
        await _extractFastAudio(localFile, id);

        String newDur = "--:--";
        if (extractedDuration != null && extractedDuration.inSeconds > 0) {
          newDur = _formatDuration(extractedDuration);
        }

        String newThumb = "";
        final thumbFileName = "thumb_yt_$id.jpg";
        final thumbFilePath = p.join(localFile.parent.path, thumbFileName);

        if (!Platform.isWindows) {
          try {
            final metadata = await MetadataRetriever.fromFile(localFile);
            if (metadata.trackDuration != null && metadata.trackDuration! > 0) {
              final d = Duration(milliseconds: metadata.trackDuration!);
              newDur = _formatDuration(d);
            }
          } catch (e) {
            debugPrint("Info metadata: $e");
          }

          try {
            final thumbData = await VideoThumbnail.thumbnailData(
              video: localFile.path,
              imageFormat: ImageFormat.JPEG,
              maxWidth: 300,
              quality: 60,
            );
            if (thumbData != null && thumbData.isNotEmpty) {
              await File(thumbFilePath).writeAsBytes(thumbData);
              newThumb = thumbFileName;
            }
          } catch (_) {}
        }

        // Fallback miniature depuis l'URL distante si VideoThumbnail n'a rien extrait
        if (newThumb.isEmpty && remoteThumbUrl != null && remoteThumbUrl.startsWith('http')) {
          try {
            await Dio().download(remoteThumbUrl, thumbFilePath, options: Options(receiveTimeout: const Duration(seconds: 8)));
            if (await File(thumbFilePath).exists() && await File(thumbFilePath).length() > 100) {
              newThumb = thumbFileName;
            }
          } catch (_) {}
        }

        final Map<String, Object?> updates = {};
        if (newDur != "--:--") updates['duration'] = newDur;
        if (newThumb.isNotEmpty) updates['thumbnail'] = newThumb;
        if (updates.isNotEmpty) {
          await _db?.update('recitations', updates, where: 'id = ?', whereArgs: [id]);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Récitation prête pour l'écoute hors-ligne !", style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
        await _fetch();
      } else {
        throw Exception("Fichier corrompu ou illisible.");
      }
    } catch (e) {
      debugPrint("Erreur téléchargement: $e");
      if (await tempFile.exists()) {
        try { await tempFile.delete(); } catch (_) {}
      }

      if (deleteRecordOnFailure && !await localFile.exists()) {
        await _db?.delete('recitations', where: 'id = ?', whereArgs: [id]);
        if (mounted) await _fetch();
      }

      String errorMsg = e.toString();
      if (errorMsg.contains("Exception:")) {
        errorMsg = errorMsg.split("Exception:").last.trim();
      } else {
        errorMsg = "Échec (${errorMsg.split('\n')[0]})";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ $errorMsg"), backgroundColor: Colors.red, duration: const Duration(seconds: 6)),
        );
      }
    } finally {
      yt?.close();
      if (mounted) setState(() => _activeDownloads.remove(id));
    }
  }

  Future<void> _play(Map<String, dynamic> rec, {bool autoPlay = true}) async {
    int index = displayedRecitations.indexWhere((r) => r['id'] == rec['id']);
    if (index == -1) return;

    final reqId = ++_playRequestId;
    final int recId = rec['id'];
    String path = (rec['fichier'] ?? "").toString().trim();
    Uri uri;

    try {
      // 1. PRIORITÉ ABSOLUE AU FICHIER LOCAL (zéro attente réseau, lecture instantanée hors-ligne)
      final localFile = await _findLocalMediaFile(rec, preferAudioOnly: true);

      if (localFile != null) {
        uri = Uri.file(localFile.path);
        // Si on lit encore un .mp4, on lance l'extraction .m4a en tâche de fond pour la prochaine écoute
        if (localFile.path.toLowerCase().endsWith('.mp4')) {
          Future.microtask(() => _extractFastAudio(localFile, recId));
        }
      } else if (isRemoteMediaUrl(path)) {
        // Fichier non encore téléchargé sur l'appareil
        final connectivityResult = await (Connectivity().checkConnectivity());
        if (connectivityResult.contains(ConnectivityResult.none)) {
          if (mounted && autoPlay) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("⚠️ Récitation non téléchargée hors-ligne. Connectez-vous à Internet pour la télécharger."),
              backgroundColor: Colors.orange,
            ));
          }
          return;
        }
        // On lance son téléchargement local immédiatement pour qu'elle soit disponible hors-ligne
        if (_appDirPath != null && !_activeDownloads.containsKey(recId)) {
          final targetVideo = File(p.join(_appDirPath!, "yt_$recId.mp4"));
          _startDownload(recId, path, targetVideo, deleteRecordOnFailure: false);
        }
        if (!autoPlay) return;
        uri = Uri.parse(ProxyServer.getProxyUrl(path));
      } else {
        if (mounted && autoPlay) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("❌ Fichier introuvable sur le disque. Veuillez retélécharger la récitation."),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }

      if (reqId != _playRequestId) return; // A newer request was made

      _isSwitchingTrack = true;
      if (mounted) {
        setState(() {
          currentRecitation = rec;
          _playingIndex = index;
        });
      } else {
        currentRecitation = rec;
        _playingIndex = index;
      }

      final tag = _createMediaItem(rec);
      globalAudioHandler?.updateCurrentMediaItem(tag);

      if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS && autoPlay) {
        try {
          final session = await AudioSession.instance;
          await session.setActive(true);
        } catch (_) {}
      }

      final baseSource = AudioSource.uri(uri, tag: tag);
      final loadFuture = _player.setAudioSource(baseSource);
      if (autoPlay) {
        _player.play(); // Queues playback to start automatically once loaded
      }
      final loadedDuration = await loadFuture;

      if (loadedDuration != null && loadedDuration > Duration.zero) {
        globalAudioHandler?.updateCurrentMediaItem(tag.copyWith(duration: loadedDuration));
        // Mise à jour automatique de la durée en BDD si elle était inconnue ("--:--")
        if (rec['duration'] == null || rec['duration'] == "--:--" || rec['duration'].toString().isEmpty) {
          final formattedDur = _formatDuration(loadedDuration);
          await _db?.update('recitations', {'duration': formattedDur}, where: 'id = ?', whereArgs: [recId]);
        }
      } else {
        globalAudioHandler?.refreshState();
      }

      final prefs = await SharedPreferences.getInstance();
      prefs.setInt('last_played_id', recId);

    } catch (e) {
      if (reqId != _playRequestId) return; // Ignore errors from cancelled requests
      
      if (e.toString().contains('interrupted') || e.toString().contains('Interruption') || e.toString().contains('abort')) {
        debugPrint("Chargement interrompu pour changer de piste (Ignoré).");
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Erreur de lecture : $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (reqId == _playRequestId) {
        _isSwitchingTrack = false;
        globalAudioHandler?.refreshState();
      }
    }
  }

  void _playNext() {
    if (displayedRecitations.isEmpty) return;
    int index = displayedRecitations.indexWhere((r) => r['id'] == currentRecitation?['id']);
    _play(displayedRecitations[(index + 1) % displayedRecitations.length]);
  }

  void _playPrevious() {
    if (displayedRecitations.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      _player.seek(Duration.zero);
      globalAudioHandler?.refreshState();
      return;
    }
    int index = displayedRecitations.indexWhere((r) => r['id'] == currentRecitation?['id']);
    _play(displayedRecitations[(index - 1 + displayedRecitations.length) % displayedRecitations.length]);
  }

  void _toggleLoop() {
    setState(() {
      if (loopMode == LoopModeState.off) {
        loopMode = LoopModeState.autoplay;
      } else if (loopMode == LoopModeState.autoplay) {
        loopMode = LoopModeState.one;
      } else {
        loopMode = LoopModeState.off;
      }
    });
  }

  void _cancelTimer() {
    _sleepTimer?.cancel();
    _countdownTimer?.cancel();
    _sleepTimer = null;
    _countdownTimer = null;
    _timerEndTime = null;
    if (mounted) setState(() {});
  }

  String _formatCountdown(Duration d) {
    if (d.isNegative) return "00:00";
    String mm = d.inMinutes.toString().padLeft(2, '0');
    String ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      String hh = d.inHours.toString().padLeft(2, '0');
      return "$hh:$mm:$ss";
    }
    return "$mm:$ss";
  }

  void _showTimerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: 300,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    "Minuteur de mise en veille", 
                    style: TextStyle(color: Color(0xFF7EB8C9), fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: CupertinoTheme(
                      data: const CupertinoThemeData(
                        textTheme: CupertinoTextThemeData(
                          dateTimePickerTextStyle: TextStyle(color: Colors.white, fontSize: 22)
                        ),
                      ),
                      child: CupertinoPicker(
                        itemExtent: 40,
                        scrollController: FixedExtentScrollController(initialItem: _selectedTimerMinutes - 1),
                        onSelectedItemChanged: (idx) {
                          setModalState(() => _selectedTimerMinutes = idx + 1);
                        },
                        children: List.generate(60, (index) => Center(child: Text("${index + 1} min"))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (_timerEndTime != null)
                        TextButton(
                          onPressed: () {
                            _cancelTimer();
                            Navigator.pop(context);
                          },
                          child: const Text("Désactiver", style: TextStyle(color: Colors.red)),
                        ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A8FA3)),
                        onPressed: () {
                          _cancelTimer(); 
                          _timerEndTime = DateTime.now().add(Duration(minutes: _selectedTimerMinutes));
                          
                          _sleepTimer = Timer(Duration(minutes: _selectedTimerMinutes), () {
                            _player.pause();
                            _cancelTimer();
                          });

                          _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
                            if (_timerEndTime != null) {
                              if (DateTime.now().isAfter(_timerEndTime!)) {
                                _cancelTimer();
                              } else {
                                if (mounted) setState(() {});
                              }
                            }
                          });

                          if (mounted) setState(() {}); 
                          Navigator.pop(context);
                        },
                        child: const Text("Démarrer", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return "0:00";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    if (d.inHours > 0) {
      return "${d.inHours}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
    }
    return "${d.inMinutes}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  Widget _buildFallbackThumb() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF1A262B),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.graphic_eq, color: Color(0xFF7EB8C9), size: 26),
    );
  }

  Widget _buildThumbnail(String? thumbPath) {
    if (thumbPath == null || thumbPath.isEmpty) {
      return _buildFallbackThumb();
    }

    String resolvedPath = _resolvePath(thumbPath);
    if (resolvedPath.startsWith('http')) {
      return Image.network(
        resolvedPath,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        cacheWidth: 150,
        errorBuilder: (_, __, ___) => _buildFallbackThumb(),
      );
    } else {
      final file = File(resolvedPath);
      if (!file.existsSync()) return _buildFallbackThumb();
      return Image.file(
        file,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        cacheWidth: 150,
        errorBuilder: (_, __, ___) => _buildFallbackThumb(),
      );
    }
  }

  // --- OPTIMISATION EXPORT/IMPORT ---

  void _showLoading(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false, // Empêche l'utilisateur de fermer la boîte en cliquant à côté
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: Color(0xFF7EB8C9)),
          const SizedBox(height: 20),
          Text(msg, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
        ]),
      )
    );
  }

  Future<void> _exportLibrary() async {
    _showLoading("Création de la sauvegarde...\nNe fermez pas l'application.");
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      await _player.stop();
      await _db?.close(); 
      await Future.delayed(const Duration(milliseconds: 500));

      final dir = Directory(_appDirPath!);
      final zipPath = p.join(dir.path, "QuranLibrary_Backup.zip");

      final oldZip = File(zipPath);
      if (await oldZip.exists()) await oldZip.delete();

      // CORRECTIF 2A : Un nom unique pour ne jamais subir de conflit avec un vieux dossier
      final tempDir = Directory(p.join(dir.path, "temp_export_${DateTime.now().millisecondsSinceEpoch}"));
      await tempDir.create();

      final originalDb = File(p.join(dir.path, 'luhaidan.db'));
      if (await originalDb.exists()) {
        await originalDb.copy(p.join(tempDir.path, 'luhaidan.db')); 
      }

      final files = dir.listSync();
      for (var f in files) {
        if (f is File &&
            (f.path.endsWith('.mp4') ||
             f.path.endsWith('.m4a') ||
             f.path.endsWith('.mp3') ||
             f.path.endsWith('.mov') ||
             f.path.endsWith('.jpg'))) {
          await f.copy(p.join(tempDir.path, p.basename(f.path))); 
        }
      }

      final encoder = ZipFileEncoder();
      encoder.zipDirectory(tempDir, filename: zipPath);

      // CORRECTIF 2B : On laisse Windows souffler, et on ignore l'erreur si la suppression est bloquée
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {
        debugPrint("Dossier temporaire verrouillé par Windows, ignoré.");
      }
      
      await _initApp(); 

      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Sauvegarde créée avec succès !"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Erreur d'exportation : $e"), backgroundColor: Colors.red));
      await _initApp();
    }
  }

  Future<void> _importLibrary() async {
    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
    if (result == null) return;

    _showLoading("Restauration en cours...\nNe fermez pas l'application.");
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final zipFile = File(result.files.single.path!);
      final dir = Directory(_appDirPath!);
      
      final tempDir = Directory(p.join(dir.path, 'temp_restore'));
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      await tempDir.create();

      File? extractedDb;
      File? extractedWal;
      File? extractedShm;
      List<File> extractedMedia = [];

      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (var file in archive) {
        final filename = file.name;
        final safeName = filename.split(RegExp(r'[/\\]')).last;
        
        if (!file.isFile || filename.contains('__MACOSX') || safeName.startsWith('._') || safeName.isEmpty) {
          continue;
        }

        final cleanName = safeName.toLowerCase();
        final destPath = p.join(tempDir.path, safeName);
        
        final extractedFile = File(destPath);
        final content = file.content as List<int>;
        await extractedFile.writeAsBytes(content);

        // LE CORRECTIF EST ICI : Noms stricts pour ne jamais confondre avec une vidéo !
        if (cleanName == 'luhaidan.db') {
          extractedDb = extractedFile;
        } else if (cleanName == 'luhaidan.db-wal') {
          extractedWal = extractedFile;
        } else if (cleanName == 'luhaidan.db-shm') {
          extractedShm = extractedFile;
        } else if (cleanName.endsWith('.mp4') ||
                   cleanName.endsWith('.m4a') ||
                   cleanName.endsWith('.mp3') ||
                   cleanName.endsWith('.jpg') ||
                   cleanName.endsWith('.mov')) {
          extractedMedia.add(extractedFile);
        }
      }

      if (extractedDb == null) {
        throw Exception("Fichier luhaidan.db introuvable. Assurez-vous que le ZIP contient bien la base de données.");
      }

      await _player.stop();
      await _db?.close();
      _db = null; 
      
      final realDbPath = p.join(dir.path, 'luhaidan.db');
      final realWalPath = p.join(dir.path, 'luhaidan.db-wal');
      final realShmPath = p.join(dir.path, 'luhaidan.db-shm');

      // Nettoyage de l'ancienne base et de ses caches
      if (await File(realDbPath).exists()) await File(realDbPath).delete(); 
      if (await File(realWalPath).exists()) await File(realWalPath).delete(); 
      if (await File(realShmPath).exists()) await File(realShmPath).delete(); 
      
      // Copie de la nouvelle base (et de ses caches manuels s'ils existent)
      await extractedDb.copy(realDbPath);
      if (extractedWal != null) await extractedWal.copy(realWalPath);
      if (extractedShm != null) await extractedShm.copy(realShmPath);

      for (var mediaFile in extractedMedia) {
        final newPath = p.join(dir.path, p.basename(mediaFile.path));
        if (await File(newPath).exists()) await File(newPath).delete();
        await mediaFile.copy(newPath);
      }

      await tempDir.delete(recursive: true);
      await _initApp(); 

      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Bibliothèque restaurée avec succès !"), backgroundColor: Colors.green));
      
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Erreur de restauration : $e"), backgroundColor: Colors.red));
      await _initApp(); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quran Library", style: TextStyle(color: Color(0xFF7EB8C9))),
        backgroundColor: const Color(0xFF111111),
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${displayedRecitations.length} récitations", 
                  style: const TextStyle(color: Color(0xFF6A7A82), fontSize: 13)
                ),
                if (selectedYearFilter != null)
                  Text(
                    selectedYearFilter == -1 ? "Année inconnue" : "$selectedYearFilter H", 
                    style: const TextStyle(color: Color(0xFF7EB8C9), fontWeight: FontWeight.bold)
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  itemCount: displayedRecitations.length,
                  itemBuilder: (context, i) {
                    final rec = displayedRecitations[i];
                    return ListTile(
                      selected: currentRecitation?['id'] == rec['id'],
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6), 
                        child: _buildThumbnail(rec['thumbnail'])
                      ),
                      title: Text("${rec['sourate_num'].toString().padLeft(3, '0')} - ${rec['sourate_name']}"),
                      subtitle: Text("${rec['annee'] ?? '??'} H / ${rec['annee_g'] ?? '??'} G • Versets: ${rec['versets']}"),
                      trailing: _activeDownloads.containsKey(rec['id'])
                          ? SizedBox(
                              width: 44, height: 44,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: _activeDownloads[rec['id']]! >= 0 ? _activeDownloads[rec['id']] : null,
                                    backgroundColor: Colors.white24, 
                                    color: const Color(0xFF7EB8C9), 
                                    strokeWidth: 3,
                                  ),
                                  Text(
                                    _activeDownloads[rec['id']]! >= 0 
                                      ? "${(_activeDownloads[rec['id']]! * 100).toInt()}%"
                                      : "${(-_activeDownloads[rec['id']]! / 1024 / 1024).toStringAsFixed(1)}M", 
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)
                                  ),
                                ],
                              ),
                            )
                          : Text(rec['duration'] ?? "--:--", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      onTap: () => _play(rec),
                      onLongPress: () => _showOptions(rec),
                    );
                  },
                ),
                Positioned(
                  bottom: 16, 
                  right: 24, 
                  child: FloatingActionButton(
                    onPressed: () => _showForm(), 
                    backgroundColor: const Color(0xFF4A8FA3), 
                    child: const Icon(Icons.add, color: Colors.white, size: 30)
                  )
                ),
              ],
            ),
          ),
          if (currentRecitation != null) _buildPlayerUI(),
        ],
      ),
    );
  }

  Widget _buildPlayerUI() {
    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 12,
            child: _isDownloading 
                ? const Padding(
                    padding: EdgeInsets.only(bottom: 8.0), 
                    child: LinearProgressIndicator(color: Color(0xFF7EB8C9))
                  )
                : null,
          ),
            
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${currentRecitation!['sourate_num'].toString().padLeft(3, '0')} - ${currentRecitation!['sourate_name']}", 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                    Text(
                      "${currentRecitation!['annee'] ?? '??'} H / ${currentRecitation!['annee_g'] ?? '??'} G • Versets: ${currentRecitation!['versets']}", 
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6A7A82))
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: _showTimerDialog,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _timerEndTime != null ? Icons.timer : Icons.timer_outlined, 
                        color: _timerEndTime != null ? const Color(0xFF7EB8C9) : Colors.grey,
                        size: 24
                      ),
                      SizedBox(
                        height: 14,
                        child: _timerEndTime != null
                            ? Text(
                                _formatCountdown(_timerEndTime!.difference(DateTime.now())),
                                style: const TextStyle(color: Color(0xFF7EB8C9), fontSize: 11, fontWeight: FontWeight.bold)
                              )
                            : null,
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 6),
          
          // Barre de timeline style iOS (glissement relatif amorti + stabilisation anti-saut au relâchement)
          StreamBuilder<Duration>(
            stream: _isInBackground ? const Stream<Duration>.empty() : _player.positionStream,
            builder: (context, snapshot) {
              final pos = snapshot.data ?? _player.position;
              final dur = _player.duration ?? Duration.zero;
              return _IosTimelineScrubber(
                position: pos,
                duration: dur,
                formatDuration: _formatDuration,
                onSeek: (target) async {
                  await _player.seek(target);
                  globalAudioHandler?.refreshState();
                },
              );
            },
          ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(
                  loopMode == LoopModeState.off ? Icons.repeat : (loopMode == LoopModeState.autoplay ? Icons.repeat_on : Icons.repeat_one_on), 
                  color: loopMode == LoopModeState.off ? Colors.grey : const Color(0xFF7EB8C9)
                ), 
                onPressed: _toggleLoop
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 34), 
                onPressed: _playPrevious
              ),
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snapshot) {
                  final state = snapshot.data;
                  final playing = state?.playing ?? false;
                  
                  if (state?.processingState == ProcessingState.loading || state?.processingState == ProcessingState.buffering) {
                    return const SizedBox(
                      width: 76, 
                      height: 76, 
                      child: Center(
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(color: Color(0xFF7EB8C9))
                        )
                      )
                    );
                  }
                  
                  bool showPlayIcon = !playing || state?.processingState == ProcessingState.completed;
                  return IconButton(
                    iconSize: 60, 
                    icon: Icon(showPlayIcon ? Icons.play_circle : Icons.pause_circle, color: const Color(0xFF7EB8C9)), 
                    onPressed: () async {
                      if (showPlayIcon) {
                        if (state?.processingState == ProcessingState.completed) {
                          await _player.seek(Duration.zero);
                        }
                        _player.play();
                      } else {
                        _player.pause();
                      }
                      globalAudioHandler?.refreshState();
                    }
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, size: 34), 
                onPressed: _playNext
              ),
              IconButton(
                icon: const Icon(Icons.stop, size: 30, color: Colors.grey), 
                onPressed: () {
                  _player.pause(); 
                  _player.seek(Duration.zero);
                  globalAudioHandler?.refreshState();
                }
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final years = allRecitations.map((r) => r['annee']).whereType<int>().toSet().toList()..sort((a, b) => b.compareTo(a));
    return Drawer(
      backgroundColor: const Color(0xFF0A0A0A),
      child: ListView(
        children: [
          const DrawerHeader(
            child: Center(
              child: Text("Quran Library", style: TextStyle(color: Color(0xFF7EB8C9), fontSize: 24, fontWeight: FontWeight.bold))
            )
          ),
          
          // BOUCLIER WINDOWS : On cache les outils strictement mobiles
          if (!Platform.isWindows) ...[
            ListTile(
              leading: const Icon(Icons.movie_edit, color: Color(0xFF7EB8C9)),
              title: const Text("Éditeur Vidéo", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context); 
                _showVideoEditorMenu(); 
              },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.language, color: Color(0xFF7EB8C9)),
              title: const Text("Navigateur YouTube", style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => YoutubeBrowserScreen(
                      db: _db,
                      onSave: _fetch,
                      appDirPath: _appDirPath,
                      onDownload: (id, url, file) => _startDownload(id, url, file),
                    ),
                  ),
                );
              },
            ),
            const Divider(color: Colors.white24),
          ],
          
          ListTile(
            leading: const Icon(Icons.upload_file, color: Colors.white70),
            title: const Text("Exporter la bibliothèque"),
            onTap: () { 
              Navigator.pop(context); 
              _exportLibrary(); 
            }
          ),
          ListTile(
            leading: const Icon(Icons.download_for_offline, color: Colors.white70),
            title: const Text("Restaurer une sauvegarde"),
            onTap: () { 
              Navigator.pop(context); 
              _importLibrary(); 
            }
          ),

          const Divider(color: Colors.white24),
          
          ListTile(
            leading: const Icon(Icons.folder_special, color: Colors.orange),
            title: const Text("Dossier de stockage"),
            subtitle: Text(_appDirPath ?? "Par défaut", style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () {
              Navigator.pop(context);
              _changeStorageDirectory();
            }
          ),
          
          const Divider(color: Colors.white24),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text("Filtres", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          
          ListTile(
            title: const Text("Toutes les récitations"), 
            selected: selectedYearFilter == null,
            onTap: () { 
              setState(() => selectedYearFilter = null); 
              _applyFilters(); 
              Navigator.pop(context); 
            }
          ),
          ListTile(
            title: const Text("Année inconnue"), 
            selected: selectedYearFilter == -1,
            onTap: () { 
              setState(() => selectedYearFilter = -1); 
              _applyFilters(); 
              Navigator.pop(context); 
            }
          ),
          const Divider(color: Colors.white24),
          ...years.map((y) => ListTile(
            title: Text("$y H"), 
            selected: selectedYearFilter == y,
            onTap: () { 
              setState(() => selectedYearFilter = y); 
              _applyFilters(); 
              Navigator.pop(context); 
            }
          )),
        ],
      ),
    );
  }

  void _showOptions(Map<String, dynamic> rec) {
    showModalBottomSheet(
      context: context, 
      backgroundColor: const Color(0xFF111111), 
      builder: (bottomSheetContext) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Color(0xFF7EB8C9)), 
            title: const Text("Modifier"), 
            onTap: () { 
              Navigator.pop(bottomSheetContext); 
              _showForm(rec: rec); 
            }
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red), 
            title: const Text("Supprimer"), 
            onTap: () {
              Navigator.pop(bottomSheetContext); // Ferme le menu du bas
              _confirmDelete(rec); // Ouvre la boîte de confirmation
            }
          ),
        ]
      )
    );
  }

  // NOUVELLE FONCTION : Confirmation et Nettoyage Extrême
  void _confirmDelete(Map<String, dynamic> rec) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text("Confirmer la suppression", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text("Voulez-vous vraiment supprimer « ${rec['sourate_name']} » ?\n\nCette action supprimera également les fichiers médias associés de votre téléphone pour libérer de l'espace."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Annuler", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext); // Ferme la boîte de confirmation

              // 1. FIX DU FANTÔME : Si c'est la piste en cours de lecture
              if (currentRecitation?['id'] == rec['id']) {
                await _player.stop(); // On coupe le son brutalement
                setState(() {
                  currentRecitation = null; // On fait disparaître le lecteur de l'interface
                  _playingIndex = null;
                });
              }

              // 2. SUPPRESSION DE LA BASE DE DONNÉES
              await _db?.delete('recitations', where: 'id = ?', whereArgs: [rec['id']]);

              // 3. NETTOYAGE PHYSIQUE ANTI-DOUBLONS (Fichiers & Miniatures)
              try {
                final baseDirPath = _appDirPath ?? (await getApplicationDocumentsDirectory()).path;
                final id = rec['id'];

                for (final candidate in [
                  "yt_$id.mp4",
                  "yt_$id.m4a",
                  "yt_$id.mp3",
                  "audio_$id.m4a",
                ]) {
                  final f = File(p.join(baseDirPath, candidate));
                  if (await f.exists()) await f.delete();
                }

                // B. Supprimer le fichier vidéo/audio Local (si existant)
                String fileStr = (rec['fichier'] ?? "").toString();
                if (!isRemoteMediaUrl(fileStr) && fileStr.isNotEmpty) {
                  final localFile = File(p.join(baseDirPath, p.basename(fileStr)));
                  if (await localFile.exists()) await localFile.delete();
                }

                // C. Supprimer la miniature associée (si elle est téléchargée localement)
                String thumbStr = (rec['thumbnail'] ?? "").toString();
                if (thumbStr.isNotEmpty && !thumbStr.startsWith('http')) {
                  final thumbFile = File(p.join(baseDirPath, p.basename(thumbStr)));
                  if (await thumbFile.exists()) await thumbFile.delete();
                }
              } catch (e) {
                debugPrint("Erreur lors de la suppression des fichiers : $e");
              }

              // 4. RAFRAÎCHIR L'INTERFACE
              _fetch(); 
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.white)) 
          )
        ],
      )
    );
  }

  void _showForm({Map<String, dynamic>? rec, String? initialUrl}) {
    showDialog(
      context: context, 
      builder: (context) => FormDialog(
        rec: rec, 
        onSave: _fetch, 
        db: _db, 
        appDirPath: _appDirPath,
        initialUrl: initialUrl,
        onDownload: (id, url, file) => _startDownload(id, url, file),
        onEdit: _launchEditorAndSave,
      )
    );
  }

  // --- LANCEUR ET SAUVEGARDE DE L'ÉDITEUR ---
  Future<void> _launchEditorAndSave(File videoFile, Map<String, dynamic> metadata) async {
    await _player.stop(); // CRITIQUE : Stop complet pour forcer l'iPhone à vider le cache de l'ancienne vidéo
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoEditorScreen(videoFile: videoFile, recitationData: metadata),
      ),
    );

    if (result != null && result is Map) {
      File editedFile = result['file'];
      Map<String, dynamic> meta = Map<String, dynamic>.from(result['metadata']);
      final baseDirPath = _appDirPath ?? (await getApplicationDocumentsDirectory()).path;
      
      if (meta.containsKey('id') && meta['id'] != null) {
        // CAS 1 : MODIFICATION
        int id = meta['id'];
        String newFileName = "edited_${id}_${DateTime.now().millisecondsSinceEpoch}.mp4"; 
        File finalDest = File(p.join(baseDirPath, newFileName));
        
        await editedFile.copy(finalDest.path);

        // Régénère immédiatement la piste audio pure .m4a correspondant à la vidéo rognée
        final oldAudio = File(p.join(baseDirPath, "audio_$id.m4a"));
        if (await oldAudio.exists()) {
          try { await oldAudio.delete(); } catch (_) {}
        }
        await _extractFastAudio(finalDest, id);

        try {
           final newMetadata = await MetadataRetriever.fromFile(finalDest);
           String newDur = meta['duration'] ?? "--:--"; 
           if (newMetadata.trackDuration != null) {
              final d = Duration(milliseconds: newMetadata.trackDuration!);
              newDur = "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
           }
           
           String newThumb = "thumb_${id}_${DateTime.now().millisecondsSinceEpoch}.jpg";
           final thumbData = await VideoThumbnail.thumbnailData(video: finalDest.path, imageFormat: ImageFormat.JPEG, maxWidth: 300, quality: 50);
           if (thumbData != null) {
             await File(p.join(baseDirPath, newThumb)).writeAsBytes(thumbData);
           } else {
             newThumb = meta['thumbnail'] ?? "";
           }
           
           await _db?.update('recitations', {'fichier': newFileName, 'duration': newDur, 'thumbnail': newThumb}, where: 'id = ?', whereArgs: [id]);
        } catch (_) {}
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Récitation modifiée avec succès !"), backgroundColor: Colors.green));
      } else {
        // CAS 2 : NOUVELLE VIDÉO
        String newFileName = "local_${DateTime.now().millisecondsSinceEpoch}.mp4";
        File finalDest = File(p.join(baseDirPath, newFileName));
        await editedFile.copy(finalDest.path);
        
        meta['fichier'] = newFileName;
        final insertedId = await _db?.insert('recitations', meta);
        if (insertedId != null) {
          await _extractFastAudio(finalDest, insertedId);
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Nouvelle vidéo enregistrée et rognée !"), backgroundColor: Colors.green));
      }
      
      setState(() {
        currentRecitation = null;
        _playingIndex = null;
      });

      await _fetch();

      if (await editedFile.exists()) await editedFile.delete();
      if (meta.containsKey('id')) {
        final tempEdit = File(p.join(baseDirPath, "temp_edit_${meta['id']}.mp4"));
        if (await tempEdit.exists()) await tempEdit.delete();
      }
    }
  }

  // --- NOUVEAU MENU : ÉDITEUR VIDÉO ---
  Future<void> _showVideoEditorMenu() async {
    final prefs = await SharedPreferences.getInstance();
    final hasDraft = prefs.getString('draft_video_path') != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      builder: (sheetContext) => Wrap(
        children: [
          if (hasDraft)
            ListTile(
              leading: const Icon(Icons.restore, color: Colors.orange),
              title: const Text("Reprendre le brouillon en cours"),
              onTap: () async {
                Navigator.pop(sheetContext);
                final draftPath = prefs.getString('draft_video_path');
                final draftMetaStr = prefs.getString('draft_metadata');
                if (draftPath != null && File(draftPath).existsSync()) {
                    Map<String, dynamic> meta = draftMetaStr != null ? jsonDecode(draftMetaStr) : {};
                    _launchEditorAndSave(File(draftPath), meta);
                } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Brouillon introuvable.")));
                }
           },
            ),
          ListTile(
            leading: const Icon(Icons.video_file, color: Color(0xFF7EB8C9)),
            title: const Text("Importer une nouvelle récitation"),
            onTap: () {
             Navigator.pop(sheetContext);
             _showForm(); // Réutilise ton formulaire existant !
           },
          ),
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.green),
            title: const Text("Modifier une récitation existante"),
            onTap: () {
              Navigator.pop(sheetContext);
              _showRecitationPickerForEditor();
            },
          ),
        ],
      ),
    );
  }

  // --- SÉLECTEUR DE RÉCITATIONS POUR L'ÉDITEUR ---
  void _showRecitationPickerForEditor() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      isScrollControlled: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.8,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Choisir la récitation à modifier", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: allRecitations.length,
                itemBuilder: (context, index) {
                  final rec = allRecitations[index];
                  final id = rec['id'];
                  final fileName = rec['fichier']?.toString() ?? "";
                  
                  // LOGIQUE DE DÉTECTION ROBUSTE :
                  // 1. Soit c'est un fichier téléchargé (stocké en yt_ID.mp4)
                  // 2. Soit c'est un import local (stocké avec son nom d'origine)
                  final File ytFile = File(p.join(_appDirPath!, "yt_$id.mp4"));
                  final File localFile = File(p.join(_appDirPath!, p.basename(fileName)));

                  bool exists = ytFile.existsSync() || (fileName.isNotEmpty && localFile.existsSync() && !isRemoteMediaUrl(fileName));

                  if (!exists) return const SizedBox.shrink(); // On cache si le fichier n'est pas sur le téléphone
                  
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: _buildThumbnail(rec['thumbnail'])
                    ),
                    title: Text("${rec['sourate_num']} - ${rec['sourate_name']}", style: const TextStyle(color: Colors.white)),
                    subtitle: Text(rec['duration'] ?? "Vidéo", style: const TextStyle(color: Colors.grey)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      _prepareExistingVideoForEditor(rec);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CRÉATION DE LA COPIE DE TRAVAIL NON-DESTRUCTIVE ---
  Future<void> _prepareExistingVideoForEditor(Map<String, dynamic> rec) async {
    _showLoading("Préparation de la copie de travail...");
    try {
      final baseDirPath = _appDirPath ?? (await getApplicationDocumentsDirectory()).path;
      File sourceFile;
      
      final id = rec['id'];
      final fileName = rec['fichier']?.toString() ?? "";
      final File ytFile = File(p.join(baseDirPath, "yt_$id.mp4"));
      final File localFile = File(p.join(baseDirPath, p.basename(fileName)));

      // On détermine quel fichier utiliser
      if (ytFile.existsSync()) {
        sourceFile = ytFile;
      } else if (fileName.isNotEmpty && !isRemoteMediaUrl(fileName) && localFile.existsSync()) {
        sourceFile = localFile;
      } else {
        throw Exception("Fichier vidéo (.mp4) introuvable sur l'appareil.");
      }

      // Création de la copie temporaire pour l'éditeur
      final tempFile = File(p.join(baseDirPath, "temp_edit_${rec['id']}.mp4"));
      if (await tempFile.exists()) await tempFile.delete();
      await sourceFile.copy(tempFile.path);

      if (mounted) Navigator.pop(context); // Ferme le chargement

      _launchEditorAndSave(tempFile, rec);

    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Erreur : $e"), backgroundColor: Colors.red));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lastWakeUp = DateTime.now();
      if (_isInBackground) {
        _isInBackground = false;
        if (mounted) setState(() {});
      }
      // Resynchronise immédiatement le Centre de Contrôle iOS et l'interface au retour dans l'application
      globalAudioHandler?.refreshState();
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.hidden ||
               state == AppLifecycleState.detached) {
      _isInBackground = true;
    }
  }

  Future<void> _changeStorageDirectory() async {
    // Ouvre l'explorateur Windows pour choisir un dossier
    String? newPath = await FilePicker.getDirectoryPath(dialogTitle: "Sélectionnez le nouveau dossier de stockage");
    
    if (newPath == null || newPath == _appDirPath) return;

    _showLoading("Transfert des données vers le nouveau dossier...\nNe fermez pas l'application.");
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      await _player.stop();
      await _db?.close();
      _db = null;
      await Future.delayed(const Duration(milliseconds: 500));

      final oldDir = Directory(_appDirPath!);
      final files = oldDir.listSync();

      // On déplace physiquement tous les fichiers
      for (var f in files) {
        if (f is File) {
          final name = p.basename(f.path);
          if (name.startsWith('luhaidan.db') ||
              name.endsWith('.mp4') ||
              name.endsWith('.m4a') ||
              name.endsWith('.mp3') ||
              name.endsWith('.jpg') ||
              name.endsWith('.mov')) {
            final newFile = File(p.join(newPath, name));
            await f.copy(newFile.path); // On copie (sécurisé entre différents disques durs)
            await f.delete(); // On supprime l'original
          }
        }
      }

      // On sauvegarde le nouveau chemin dans les paramètres
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_storage_path', newPath);

      await _initApp(); // On relance la machine sur le nouveau dossier
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Transfert réussi !"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Erreur lors du transfert : $e"), backgroundColor: Colors.red));
      await _initApp(); // Sécurité : on relance quand même
    }
  }
}

/// Barre de timeline reproduisant fidèlement le comportement du lecteur natif iOS (Apple Music / Lock Screen) :
/// 1. Glissement horizontal RELATIF (pas de saut brusque au toucher, pas de déplacement involontaire sur un simple tap).
/// 2. Sensibilité amortie sur les longues récitations + précision accrue en glissant verticalement vers le bas.
/// 3. Stabilisation au relâchement (fenêtre de 90 ms anti-"thumb-roll") empêchant tout bond de plusieurs minutes quand on lève le doigt.
class _IosTimelineScrubber extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final Future<void> Function(Duration target) onSeek;
  final String Function(Duration d) formatDuration;

  const _IosTimelineScrubber({
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.formatDuration,
  });

  @override
  State<_IosTimelineScrubber> createState() => _IosTimelineScrubberState();
}

class _DragHistoryPoint {
  final int timestampMs;
  final double positionMs;
  const _DragHistoryPoint(this.timestampMs, this.positionMs);
}

class _IosTimelineScrubberState extends State<_IosTimelineScrubber> {
  bool _isDragging = false;
  bool _isSeeking = false;
  double _dragPositionMs = 0.0;
  double _lastDragX = 0.0;
  double _dragStartY = 0.0;
  double _verticalPrecisionFactor = 1.0;
  String? _precisionLabel;
  final List<_DragHistoryPoint> _history = [];

  double get _maxDurationMs {
    final ms = widget.duration.inMilliseconds.toDouble();
    return ms > 0 ? ms : 1.0;
  }

  void _recordPoint(double posMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _history.add(_DragHistoryPoint(now, posMs));
    // On conserve uniquement les ~400 dernières millisecondes d'historique
    _history.removeWhere((p) => now - p.timestampMs > 400);
  }

  /// Retourne la position stable enregistrée ~90 ms avant le relâchement du doigt
  /// afin d'éliminer totalement le glissement parasite de la pulpe du pouce à la levée.
  double _getStabilizedReleaseMs() {
    if (_history.isEmpty) return _dragPositionMs;
    final now = DateTime.now().millisecondsSinceEpoch;
    final targetTime = now - 90;
    _DragHistoryPoint? best;
    for (int i = _history.length - 1; i >= 0; i--) {
      final pt = _history[i];
      if (pt.timestampMs <= targetTime) {
        best = pt;
        break;
      }
    }
    best ??= _history.first;
    // Si la dérive finale au lever du doigt dépasse un petit seuil, on verrouille sur le point stable
    if ((_dragPositionMs - best.positionMs).abs() > 250) {
      return best.positionMs.clamp(0.0, _maxDurationMs);
    }
    return _dragPositionMs.clamp(0.0, _maxDurationMs);
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = _maxDurationMs;
    final currentMs = (_isDragging || _isSeeking)
        ? _dragPositionMs.clamp(0.0, maxMs)
        : widget.position.inMilliseconds.toDouble().clamp(0.0, maxMs);
    final progress = (currentMs / maxMs).clamp(0.0, 1.0);
    final remainingMs = (maxMs - currentMs).clamp(0.0, maxMs);

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = (constraints.maxWidth - 16.0).clamp(120.0, 2000.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isDragging && _precisionLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Text(
                  _precisionLabel!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF7EB8C9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (details) {
                final startMs = widget.position.inMilliseconds.toDouble().clamp(0.0, maxMs);
                _history.clear();
                _recordPoint(startMs);
                setState(() {
                  _isDragging = true;
                  _dragPositionMs = startMs;
                  _lastDragX = details.localPosition.dx;
                  _dragStartY = details.localPosition.dy;
                  _verticalPrecisionFactor = 1.0;
                  _precisionLabel = null;
                });
              },
              onHorizontalDragUpdate: (details) {
                if (!_isDragging) return;
                final dx = details.localPosition.dx - _lastDragX;
                _lastDragX = details.localPosition.dx;

                // Ignorer le micro-tremblement capacitif (< 0.4 px)
                if (dx.abs() < 0.4) {
                  _recordPoint(_dragPositionMs);
                  return;
                }

                // Précision verticale style iOS : glisser le doigt vers le bas ou le haut affine la vitesse
                final dy = (details.localPosition.dy - _dragStartY).abs();
                if (dy > 110) {
                  _verticalPrecisionFactor = 0.12;
                  _precisionLabel = "Scrubbing de précision (×1/8)";
                } else if (dy > 65) {
                  _verticalPrecisionFactor = 0.25;
                  _precisionLabel = "Quart de vitesse (×1/4)";
                } else if (dy > 30) {
                  _verticalPrecisionFactor = 0.5;
                  _precisionLabel = "Demi-vitesse (×1/2)";
                } else {
                  _verticalPrecisionFactor = 1.0;
                  _precisionLabel = null;
                }

                // Sur les longues récitations (> 10 min), on plafonne la sensibilité de base
                // pour qu'un mouvement horizontal normal reste doux et précis comme sur iOS
                const tenMinutesMs = 10.0 * 60.0 * 1000.0;
                final effectiveSpanMs = maxMs > tenMinutesMs
                    ? tenMinutesMs + (maxMs - tenMinutesMs) * 0.42
                    : maxMs;

                final msPerPixel = (effectiveSpanMs / trackWidth) * _verticalPrecisionFactor;
                final nextMs = (_dragPositionMs + dx * msPerPixel).clamp(0.0, maxMs);

                _recordPoint(nextMs);
                setState(() {
                  _dragPositionMs = nextMs;
                });
              },
              onHorizontalDragEnd: (_) async {
                if (!_isDragging) return;
                final targetMs = _getStabilizedReleaseMs();
                setState(() {
                  _isDragging = false;
                  _isSeeking = true;
                  _dragPositionMs = targetMs;
                  _precisionLabel = null;
                });
                try {
                  await widget.onSeek(Duration(milliseconds: targetMs.round()));
                } finally {
                  if (mounted) {
                    setState(() {
                      _isSeeking = false;
                    });
                  }
                }
              },
              onHorizontalDragCancel: () {
                if (!_isDragging) return;
                setState(() {
                  _isDragging = false;
                  _precisionLabel = null;
                });
              },
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  height: _isDragging ? 11.0 : 5.5,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(_isDragging ? 0.26 : 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isDragging ? Colors.white : const Color(0xFF7EB8C9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.formatDuration(Duration(milliseconds: currentMs.round())),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: _isDragging ? FontWeight.bold : FontWeight.normal,
                      color: _isDragging ? Colors.white : Colors.grey,
                    ),
                  ),
                  Text(
                    "-${widget.formatDuration(Duration(milliseconds: remainingMs.round()))}",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: _isDragging ? FontWeight.bold : FontWeight.normal,
                      color: _isDragging ? Colors.white : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class YoutubeBrowserScreen extends StatefulWidget {
  final Database? db;
  final VoidCallback onSave;
  final String? appDirPath;
  final Function(int, String, File)? onDownload; 

  const YoutubeBrowserScreen({super.key, required this.db, required this.onSave, this.appDirPath, this.onDownload});

  @override
  State<YoutubeBrowserScreen> createState() => _YoutubeBrowserScreenState();
}

class _YoutubeBrowserScreenState extends State<YoutubeBrowserScreen> {
  late final WebViewController _controller;
  String _currentUrl = "";

  @override
  void initState() {
    super.initState();
    
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // SCRIPT AGRESSIF : Force TOUTES les vidéos de la page à rester alignées
            _controller.runJavaScript("""
              const observer = new MutationObserver(() => {
                document.querySelectorAll('video').forEach(v => {
                  if (v.getAttribute('playsinline') !== '1') {
                    v.setAttribute('playsinline', '1');
                    v.setAttribute('webkit-playsinline', '1'); // La clé pour iOS !
                  }
                });
              });
              observer.observe(document.body, { childList: true, subtree: true });
            """);
          },
          onUrlChange: (UrlChange change) {
            if (mounted) setState(() => _currentUrl = change.url ?? "");
          },
        ),
      )
      ..loadRequest(Uri.parse('https://m.youtube.com/'));
  }

  bool get _isVideoPage {
    return _currentUrl.contains('watch?v=') || _currentUrl.contains('youtu.be') || _currentUrl.contains('/shorts/');
  }

  Future<bool> _handleBack() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false; 
    }
    return true; 
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope( // Restaure le "Swipe Back" naturel d'Apple sans bloquer l'écran !
      onWillPop: _handleBack,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Navigateur YouTube", style: TextStyle(color: Color(0xFF7EB8C9))),
          backgroundColor: const Color(0xFF111111),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _controller.canGoBack()) {
                _controller.goBack();
              } else {
                if (mounted) Navigator.pop(context);
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _controller.reload(),
            )
          ],
        ),
        body: WebViewWidget(controller: _controller), // 100% de la largeur pour scroller !
        floatingActionButton: _isVideoPage
            ? FloatingActionButton.extended(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogContext) => FormDialog(
                      db: widget.db,
                      appDirPath: widget.appDirPath,
                      onSave: () {
                        widget.onSave();
                        Navigator.pop(context); 
                      },
                      initialUrl: _currentUrl,
                      onDownload: widget.onDownload, 
                    )
                  );
                },
                backgroundColor: const Color(0xFF4A8FA3),
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text("Télécharger", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            : null,
      ),
    );
  }
}

class FormDialog extends StatefulWidget {
  final Map<String, dynamic>? rec;
  final VoidCallback onSave;
  final Database? db;
  final String? appDirPath;
  final String? initialUrl; 
  final Function(int, String, File)? onDownload;
  final Function(File, Map<String, dynamic>)? onEdit;
  
  const FormDialog({
    super.key,
    this.rec,
    required this.onSave,
    this.db,
    this.appDirPath,
    this.initialUrl,
    this.onDownload,
    this.onEdit,
  });
  
  @override 
  State<FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<FormDialog> {
  int? selectedNum = 1;
  String? selectedName = "Al-Fatiha";
  
  late TextEditingController _yearInput, _file, _ytUrl, _vStart, _vEnd;
  String _sourceType = "local"; // "local" ou "link" (Bouton unique "Lien" universel)
  bool isFull = true;

  @override
  void initState() {
    super.initState();
    
    // Auto-détection du type de source (Local vs Lien universel)
    if (widget.rec != null) {
      String f = widget.rec!['fichier']?.toString() ?? "";
      if (isRemoteMediaUrl(f)) {
        _sourceType = "link";
      } else {
        _sourceType = "local";
      }
    } else if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _sourceType = "link"; 
    }
    
    if (widget.rec != null) {
      selectedNum = widget.rec!['sourate_num'];
      selectedName = widget.rec!['sourate_name'];
      isFull = widget.rec!['versets'] == "complet";
    }
    
    _yearInput = TextEditingController(text: widget.rec?['annee']?.toString() ?? "");
    _file = TextEditingController(text: (widget.rec != null && _sourceType == "local") ? widget.rec!['fichier'] : "");
    _ytUrl = TextEditingController(text: widget.initialUrl ?? ((widget.rec != null && _sourceType == "link") ? widget.rec!['fichier'] : ""));
    
    _vStart = TextEditingController(); 
    _vEnd = TextEditingController();
    
    if (widget.rec != null && !isFull) {
      List<String> parts = widget.rec!['versets'].toString().split('-');
      if (parts.length == 2) { 
        _vStart.text = parts[0]; 
        _vEnd.text = parts[1]; 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF111111),
      title: Text(widget.rec == null ? "Ajouter" : "Modifier", style: const TextStyle(color: Color(0xFF7EB8C9))),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownMenu<Map<String, dynamic>>(
              initialSelection: widget.rec != null
                  ? ALL_SURAHS.firstWhere((s) => s['num'] == widget.rec!['sourate_num'], orElse: () => ALL_SURAHS[0])
                  : ALL_SURAHS[0],
              width: 280,
              label: const Text("Sourate"),
              enableSearch: true,
              dropdownMenuEntries: ALL_SURAHS.map((s) => DropdownMenuEntry(value: s, label: "${s['num']} - ${s['name']}")).toList(),
              onSelected: (s) { 
                selectedNum = s?['num']; 
                selectedName = s?['name']; 
              },
            ),
            const SizedBox(height: 10),
            
            TextField(
              controller: _yearInput, 
              keyboardType: TextInputType.number, 
              decoration: const InputDecoration(labelText: "Année (ex: 1445 ou 2024)", hintStyle: TextStyle(color: Colors.grey, fontSize: 12))
            ),
            
            const SizedBox(height: 10),
            Row(
              children: [
                Radio(value: true, groupValue: isFull, onChanged: (v) => setState(() => isFull = v!)), 
                const Text("Complet"),
                Radio(value: false, groupValue: isFull, onChanged: (v) => setState(() => isFull = v!)), 
                const Text("Partiel"),
              ]
            ),
            if (!isFull) Row(
              children: [
                Expanded(child: TextField(controller: _vStart, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Début"))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _vEnd, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Fin"))),
              ]
            ),
            const SizedBox(height: 15),

            // --- Sélection unifiée : Local ou Lien (toutes plateformes) ---
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.folder_open, size: 16, color: Colors.white),
                  label: const Text("Local", style: TextStyle(fontSize: 13)), 
                  selected: _sourceType == "local", 
                  onSelected: (v) => setState(() => _sourceType = "local"),
                  selectedColor: const Color(0xFF4A8FA3),
                  showCheckmark: false,
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.link, size: 16, color: Colors.white),
                  label: const Text("Lien", style: TextStyle(fontSize: 13)), 
                  selected: _sourceType == "link", 
                  onSelected: (v) => setState(() => _sourceType = "link"),
                  selectedColor: const Color(0xFF4A8FA3),
                  showCheckmark: false,
                ),
              ]
            ),

            const SizedBox(height: 15),
            if (_sourceType == "local") 
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], foregroundColor: Colors.white),
                onPressed: () async {
                  FilePickerResult? result = await FilePicker.pickFiles(type: FileType.any); 
                  if (result != null) {
                    final file = result.files.single;
                    final baseDirPath = widget.appDirPath ?? (await getApplicationDocumentsDirectory()).path;
                    await File(file.path!).copy(p.join(baseDirPath, file.name));
                    setState(() => _file.text = file.name);
                  }
                }, 
                child: Text(_file.text.isEmpty ? "Choisir un fichier .mp4 / .mp3 / .m4a" : _file.text, overflow: TextOverflow.ellipsis)
              )
            else 
              TextField(
                controller: _ytUrl, 
                decoration: InputDecoration(
                  labelText: "Lien (YouTube, TikTok, Instagram, X, Web...)",
                  hintText: "https://...",
                  suffixIcon: IconButton(
                    tooltip: "Coller depuis le presse-papiers",
                    icon: const Icon(Icons.content_paste, color: Color(0xFF7EB8C9), size: 20),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null && data!.text!.trim().isNotEmpty) {
                        setState(() => _ytUrl.text = data.text!.trim());
                      }
                    },
                  ),
                )
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler", style: TextStyle(color: Colors.grey))),
        
        // Le bouton s'affiche UNIQUEMENT si on vient de choisir un fichier vidéo local
        if (_sourceType == "local" && _file.text.isNotEmpty && (_file.text.endsWith('.mp4') || _file.text.endsWith('.mov')))
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              // 1. On prépare les métadonnées saisies
              int? inputYear = int.tryParse(_yearInput.text);
              int? anneeH, anneeG;
              if (inputYear != null) {
                if (inputYear > 1500) {
                  anneeG = inputYear;
                  anneeH = inputYear - 622 + ((inputYear - 622) ~/ 32);
                } else {
                  anneeH = inputYear;
                  anneeG = inputYear - (inputYear ~/ 33) + 622;
                }
              }
              
              final meta = {
                if (widget.rec != null) "id": widget.rec!['id'], // Vital si c'est une modification
                "sourate_num": selectedNum, 
                "sourate_name": selectedName,
                "annee": anneeH, 
                "annee_g": anneeG, 
                "fichier": _file.text,
                "versets": isFull ? "complet" : "${_vStart.text}-${_vEnd.text}",
              };

              // 2. On localise la vidéo et on ferme le formulaire
              final baseDirPath = widget.appDirPath ?? (await getApplicationDocumentsDirectory()).path;
              final videoFile = File(p.join(baseDirPath, _file.text));
              
              if (mounted) Navigator.pop(context);
              
              // 3. On lance l'éditeur !
              widget.onEdit?.call(videoFile, meta);
            }, 
            child: const Text("Rogner", style: TextStyle(color: Colors.white))
          ),

        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A8FA3)),
          onPressed: () async {
            // --- VIGILE ANTI-BUG (Empêche l'enregistrement sans fichier/lien) ---
            if (_sourceType == "local" && _file.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Veuillez choisir un fichier média."), backgroundColor: Colors.red));
              return;
            }
            if (_sourceType == "link" && _ytUrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Veuillez coller un lien."), backgroundColor: Colors.red));
              return;
            }
            // --------------------------------------------------------------------
            
            try {
              String thumb = widget.rec?['thumbnail'] ?? "";
              String dur = widget.rec?['duration'] ?? "--:--";
              if (dur.isEmpty) dur = "--:--";
              
              int? inputYear = int.tryParse(_yearInput.text);
              int? anneeH;
              int? anneeG;
              
              if (inputYear != null) {
                if (inputYear > 1500) {
                  anneeG = inputYear;
                  anneeH = inputYear - 622 + ((inputYear - 622) ~/ 32);
                } else {
                  anneeH = inputYear;
                  anneeG = inputYear - (inputYear ~/ 33) + 622;
                }
              }

              final baseDirPath = widget.appDirPath ?? (await getApplicationDocumentsDirectory()).path;
              final String cleanUrl = MediaExtractor.extractCleanUrl(_ytUrl.text.trim());

              if (_sourceType == "local" && _file.text.isNotEmpty) {
                final localFilePath = p.join(baseDirPath, _file.text);
                
                if (!Platform.isWindows) {
                  try {
                    final metadata = await MetadataRetriever.fromFile(File(localFilePath));
                    if (metadata.trackDuration != null) {
                      final d = Duration(milliseconds: metadata.trackDuration!);
                      dur = "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
                    }
                    if (metadata.albumArt != null) {
                      final thumbName = "thumb_${_file.text}.jpg";
                      await File(p.join(baseDirPath, thumbName)).writeAsBytes(metadata.albumArt!);
                      thumb = thumbName;
                    }
                  } catch (e) { debugPrint("Erreur metadata: $e"); }
                }
              }
              
              final data = {
                "sourate_num": selectedNum, 
                "sourate_name": selectedName,
                "annee": anneeH, 
                "annee_g": anneeG, 
                "fichier": _sourceType == "local" ? _file.text : cleanUrl,
                "versets": isFull ? "complet" : "${_vStart.text}-${_vEnd.text}",
                "thumbnail": thumb, 
                "duration": dur,
              };
              
              int recordId = widget.rec == null ? await widget.db!.insert('recitations', data) : widget.rec!['id'];
              if (widget.rec != null) await widget.db!.update('recitations', data, where: 'id = ?', whereArgs: [recordId]);
              
              if (_sourceType == "link" && cleanUrl.isNotEmpty) {
                final localAudioFile = File(p.join(baseDirPath, "yt_$recordId.mp4"));
                final prevUrl = widget.rec?['fichier']?.toString() ?? "";
                if (prevUrl != cleanUrl && await localAudioFile.exists()) {
                  try { await localAudioFile.delete(); } catch (_) {}
                }
                if (!await localAudioFile.exists()) {
                  widget.onDownload?.call(recordId, cleanUrl, localAudioFile);
                }
              }
              
              widget.onSave(); 
              if (mounted) Navigator.pop(context);

            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Erreur : $e"), backgroundColor: Colors.red));
              }
            }
          }, 
          child: const Text("Enregistrer", style: TextStyle(color: Colors.white))
        )
      ],
    );
  }
}

/// Modèle de média résolu par le moteur d'extraction universel (type Black Hole Splitter)
class ExtractedMedia {
  final String url;
  final String? audioUrl;
  final Map<String, String> headers;
  final bool isHls;
  final String? thumbnailUrl;
  final Duration? duration;

  const ExtractedMedia({
    required this.url,
    this.audioUrl,
    this.headers = const {},
    this.isHls = false,
    this.thumbnailUrl,
    this.duration,
  });
}

/// Moteur d'extraction universel multi-couches inspiré de Black Hole Splitter :
/// Permet de télécharger depuis n'importe quelle source (YouTube, TikTok, Instagram, X/Twitter,
/// Facebook, Threads, Reddit, SoundCloud, liens directs .mp4/.m4a/.mp3/.m3u8 ou pages web quelconques)
/// en contournant les blocages de serveurs grâce à une cascade d'extracteurs locaux et d'intercepteurs.
class MediaExtractor {
  static const String _mobileUA =
      "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1";
  static const String _desktopUA =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

  static Dio _createDio({Map<String, String>? headers, int timeoutSec = 15}) {
    return Dio(
      BaseOptions(
        connectTimeout: Duration(seconds: timeoutSec),
        receiveTimeout: Duration(seconds: timeoutSec),
        followRedirects: true,
        maxRedirects: 8,
        validateStatus: (status) => status != null && status < 500,
        headers: {
          "User-Agent": _desktopUA,
          "Accept": "*/*",
          "Accept-Language": "fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7",
          if (headers != null) ...headers,
        },
      ),
    );
  }

  /// Extrait proprement la première URL présente dans un texte copié-collé (ex: texte de partage TikTok/Instagram)
  static String extractCleanUrl(String rawInput) {
    final trimmed = rawInput.trim();
    final match = RegExp(r'https?:\/\/[^\s"<>]+', caseSensitive: false).firstMatch(trimmed);
    if (match != null) {
      return match.group(0)!.replaceAll(RegExp(r'[.,;!?)\]]+$'), '');
    }
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://') && trimmed.contains('.')) {
      return 'https://$trimmed';
    }
    return trimmed;
  }

  static bool isYouTubeUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('youtube.com') || lower.contains('youtu.be');
  }

  static bool _isDirectMediaUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.mp4') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.m3u8');
  }

  /// Point d'entrée de compatibilité (utilisé par ProxyServer)
  static Future<String?> getDownloadUrl(String targetUrl) async {
    final extracted = await resolveMedia(targetUrl);
    return extracted?.url;
  }

  /// Alias vers resolveMedia pour _startDownload
  static Future<ExtractedMedia?> extractMedia(String rawUrl) => resolveMedia(rawUrl);

  /// Résout n'importe quel lien vers un flux média téléchargeable avec ses en-têtes HTTP associés
  static Future<ExtractedMedia?> resolveMedia(String rawUrl) async {
    final String cleanUrl = extractCleanUrl(rawUrl);
    if (cleanUrl.isEmpty) return null;

    // 1. Lien direct vers un fichier média ou flux HLS (.m3u8)
    if (_isDirectMediaUrl(cleanUrl)) {
      return ExtractedMedia(
        url: cleanUrl,
        isHls: cleanUrl.toLowerCase().contains('.m3u8'),
      );
    }

    final lower = cleanUrl.toLowerCase();

    // 2. YouTube (extraction native multi-clients : iOS, AndroidVR, Safari, TV, MWeb)
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      final ytRes = await _extractYouTube(cleanUrl);
      if (ytRes != null) return ytRes;
    }

    // 3. TikTok (Cascade : TikWM -> Page Mobile Rehydration JSON -> VXTikTok -> TikMate)
    if (lower.contains('tiktok.com')) {
      final ttRes = await _extractTikTok(cleanUrl);
      if (ttRes != null) return ttRes;
    }

    // 4. Instagram (Cascade : Embed Direct -> DDInstagram/VX -> GraphQL Mobile -> SnapInsta JS Unpacker -> IGDownloader)
    if (lower.contains('instagram.com') || lower.contains('instagr.am')) {
      final igRes = await _extractInstagram(cleanUrl);
      if (igRes != null) return igRes;
    }

    // 5. X / Twitter (Cascade : API FxTwitter / VxTwitter -> Syndication API)
    if (lower.contains('twitter.com') || lower.contains('x.com') || lower.contains('t.co/')) {
      final xRes = await _extractTwitterX(cleanUrl);
      if (xRes != null) return xRes;
    }

    // 6. Facebook / FB Watch / Reels
    if (lower.contains('facebook.com') || lower.contains('fb.watch') || lower.contains('fb.gg')) {
      final fbRes = await _extractFacebook(cleanUrl);
      if (fbRes != null) return fbRes;
    }

    // 7. Reddit
    if (lower.contains('reddit.com') || lower.contains('redd.it')) {
      final rdRes = await _extractReddit(cleanUrl);
      if (rdRes != null) return rdRes;
    }

    // 8. Cascade multi-instances Cobalt (V10 & V7) compatible toutes plateformes (SoundCloud, Threads, Vimeo, Dailymotion, Bilibili, etc.)
    final cobaltRes = await _extractViaCobaltWaterfall(cleanUrl);
    if (cobaltRes != null) return cobaltRes;

    // 9. Extracteur universel HTML / OpenGraph / JSON-LD / Regex (style Black Hole Splitter)
    final genericRes = await _extractGenericWebMedia(cleanUrl);
    if (genericRes != null) return genericRes;

    // 10. Dernier recours sur mobile : Sniffer WebView headless jetable (créé à la demande puis détruit immédiatement pour 0 Mo de RAM au repos)
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      final sniffed = await _sniffMediaViaDisposableWebView(cleanUrl);
      if (sniffed != null) return sniffed;
    }

    return null;
  }

  // --- EXTRACTEUR YOUTUBE MULTI-CLIENTS ---
  static Future<ExtractedMedia?> _extractYouTube(String url) async {
    YoutubeExplode? yt;
    try {
      yt = YoutubeExplode();
      final video = await yt.videos.get(url).timeout(const Duration(seconds: 15));
      final String? thumbUrl = video.thumbnails.highResUrl.isNotEmpty
          ? video.thumbnails.highResUrl
          : video.thumbnails.standardResUrl;
      final Duration? duration = video.duration;

      final clientSets = <List<YoutubeApiClient>>[
        [YoutubeApiClient.ios, YoutubeApiClient.androidVr],
        [YoutubeApiClient.safari, YoutubeApiClient.tv],
        [YoutubeApiClient.mweb, YoutubeApiClient.android],
      ];

      for (final clients in clientSets) {
        try {
          final manifest = await yt.videos.streamsClient
              .getManifest(video.id, ytClients: clients)
              .timeout(const Duration(seconds: 15));

          if (manifest.muxed.isNotEmpty) {
            final muxed = manifest.muxed.withHighestBitrate();
            return ExtractedMedia(
              url: muxed.url.toString(),
              thumbnailUrl: thumbUrl,
              duration: duration,
            );
          }
          if (manifest.audioOnly.isNotEmpty) {
            final audio = manifest.audioOnly.withHighestBitrate();
            return ExtractedMedia(
              url: audio.url.toString(),
              thumbnailUrl: thumbUrl,
              duration: duration,
            );
          }
          if (manifest.hls.isNotEmpty) {
            final hls = manifest.hls.first;
            return ExtractedMedia(
              url: hls.url.toString(),
              isHls: true,
              thumbnailUrl: thumbUrl,
              duration: duration,
            );
          }
        } catch (_) {}
      }

      // Fallback Piped API public si YouTube bloque tous les clients directs
      final pipedInstances = [
        'https://pipedapi.kavin.rocks',
        'https://pipedapi.tokhmi.xyz',
        'https://piped-api.garudalinux.org',
      ];
      for (final instance in pipedInstances) {
        try {
          final res = await _createDio(timeoutSec: 10).get('$instance/streams/${video.id.value}');
          if (res.data is Map) {
            final data = res.data as Map;
            if (data['audioStreams'] is List && (data['audioStreams'] as List).isNotEmpty) {
              final stream = (data['audioStreams'] as List).first;
              if (stream['url'] != null) {
                return ExtractedMedia(
                  url: stream['url'].toString(),
                  thumbnailUrl: thumbUrl,
                  duration: duration,
                );
              }
            }
            if (data['hls'] != null && data['hls'].toString().startsWith('http')) {
              return ExtractedMedia(
                url: data['hls'].toString(),
                isHls: true,
                thumbnailUrl: thumbUrl,
                duration: duration,
              );
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint("Erreur _extractYouTube: $e");
    } finally {
      yt?.close();
    }
    return null;
  }

  // --- EXTRACTEUR TIKTOK MULTI-MOTEURS ---
  static Future<ExtractedMedia?> _extractTikTok(String url) async {
    final dio = _createDio();

    // Moteur 1 : API TikWM (Rapide, sans filigrane, fournit durée + miniature)
    try {
      final res = await dio.post(
        "https://www.tikwm.com/api/",
        data: FormData.fromMap({"url": url, "hd": "1"}),
      );
      if (res.data is Map && res.data['data'] is Map) {
        final data = res.data['data'] as Map;
        String? playUrl = (data['hdplay'] ?? data['play'] ?? data['wmplay'])?.toString();
        if (playUrl != null && playUrl.isNotEmpty) {
          if (playUrl.startsWith('/')) playUrl = 'https://www.tikwm.com$playUrl';
          final int? durSec = data['duration'] is int
              ? data['duration'] as int
              : int.tryParse(data['duration']?.toString() ?? '');
          return ExtractedMedia(
            url: playUrl,
            thumbnailUrl: (data['cover'] ?? data['origin_cover'])?.toString(),
            duration: durSec != null && durSec > 0 ? Duration(seconds: durSec) : null,
          );
        }
      }
    } catch (_) {}

    // Moteur 2 : Extraction directe depuis la page TikTok (__UNIVERSAL_DATA_FOR_REHYDRATION__ / SIGI_STATE) avec transfert de cookies
    try {
      final pageRes = await _createDio(headers: {
        "User-Agent": _desktopUA,
        "Referer": "https://www.tiktok.com/",
      }).get(url, options: Options(responseType: ResponseType.plain));

      final cookies = pageRes.headers['set-cookie']
          ?.map((c) => c.split(';').first)
          .join('; ');
      final html = pageRes.data?.toString() ?? "";

      final playAddrMatch = RegExp(r'"(?:playAddr|downloadAddr)"\s*:\s*"([^"]+)"').firstMatch(html);
      if (playAddrMatch != null) {
        final rawVideoUrl = _unescapeJsonString(playAddrMatch.group(1)!);
        if (rawVideoUrl.startsWith('http')) {
          return ExtractedMedia(
            url: rawVideoUrl,
            headers: {
              "User-Agent": _desktopUA,
              "Referer": "https://www.tiktok.com/",
              if (cookies != null && cookies.isNotEmpty) "Cookie": cookies,
            },
          );
        }
      }
    } catch (_) {}

    // Moteur 3 : API TikMate
    try {
      final res = await dio.post(
        "https://api.tikmate.app/api/lookup",
        data: {"url": url},
        options: Options(headers: {"Content-Type": "application/x-www-form-urlencoded"}),
      );
      if (res.data is Map && res.data['success'] == true) {
        return ExtractedMedia(
          url: "https://tikmate.app/download/${res.data['token']}/${res.data['id']}.mp4",
        );
      }
    } catch (_) {}

    // Moteur 4 : Miroirs d'embed TikTok (tnktok / vxtiktok)
    for (final host in ['tnktok.com', 'vxtiktok.com']) {
      try {
        final mirrorUrl = url.replaceFirst(RegExp(r'(?:www\.|vm\.|vt\.)?tiktok\.com'), host);
        final res = await _createDio(headers: {"User-Agent": "TelegramBot (like TwitterBot)"}).get(
          mirrorUrl,
          options: Options(responseType: ResponseType.plain),
        );
        final html = res.data?.toString() ?? "";
        final ogVideo = _extractMetaProperty(html, ['og:video', 'og:video:secure_url', 'twitter:player:stream']);
        if (ogVideo != null && ogVideo.startsWith('http')) {
          return ExtractedMedia(url: ogVideo);
        }
      } catch (_) {}
    }

    return null;
  }

  // --- EXTRACTEUR INSTAGRAM MULTI-MOTEURS ---
  static Future<ExtractedMedia?> _extractInstagram(String url) async {
    final shortcodeMatch = RegExp(r'instagram\.com\/(?:[^\/]+\/)?(?:p|reel|reels|tv)\/([A-Za-z0-9_-]+)').firstMatch(url);
    final String? shortcode = shortcodeMatch?.group(1);

    // Moteur 1 : Endpoint officiel d'intégration Instagram (/embed/captioned/)
    if (shortcode != null) {
      try {
        final embedUrl = "https://www.instagram.com/p/$shortcode/embed/captioned/";
        final res = await _createDio(headers: {
          "User-Agent": _mobileUA,
          "Referer": "https://www.instagram.com/",
        }).get(embedUrl, options: Options(responseType: ResponseType.plain));

        final html = res.data?.toString() ?? "";
        final videoMatches = [
          RegExp(r'"video_url"\s*:\s*"([^"]+)"').firstMatch(html),
          RegExp(r'\\"video_url\\"\s*:\s*\\"([^\\"]+)\\"').firstMatch(html),
          RegExp(r'class="EmbeddedMediaVideo"[^>]+src="([^"]+)"').firstMatch(html),
        ];
        for (final m in videoMatches) {
          if (m != null) {
            final extractedUrl = _unescapeJsonString(m.group(1)!).replaceAll('&amp;', '&');
            if (extractedUrl.startsWith('http')) {
              final thumbMatch = RegExp(r'"display_url"\s*:\s*"([^"]+)"').firstMatch(html);
              return ExtractedMedia(
                url: extractedUrl,
                thumbnailUrl: thumbMatch != null ? _unescapeJsonString(thumbMatch.group(1)!) : null,
                headers: {"User-Agent": _mobileUA, "Referer": "https://www.instagram.com/"},
              );
            }
          }
        }
      } catch (_) {}

      // Moteur 2 : Requête GraphQL mobile directe d'Instagram (PolarisPostActionLoadPostQueryQuery)
      try {
        final gqlRes = await _createDio(headers: {
          "User-Agent": _mobileUA,
          "X-IG-App-ID": "936619743392459",
          "X-ASBD-ID": "198387",
          "X-IG-WWW-Claim": "0",
          "Origin": "https://www.instagram.com",
          "Referer": "https://www.instagram.com/p/$shortcode/",
          "Content-Type": "application/x-www-form-urlencoded",
        }).post(
          "https://www.instagram.com/graphql/query",
          data: {
            "av": "0",
            "variables": jsonEncode({"shortcode": shortcode}),
            "doc_id": "8845758582119845",
          },
        );
        final rawJson = gqlRes.data is String ? gqlRes.data as String : jsonEncode(gqlRes.data);
        final vMatch = RegExp(r'"video_url"\s*:\s*"([^"]+)"').firstMatch(rawJson);
        if (vMatch != null) {
          final vUrl = _unescapeJsonString(vMatch.group(1)!);
          if (vUrl.startsWith('http')) {
            final tMatch = RegExp(r'"display_url"\s*:\s*"([^"]+)"').firstMatch(rawJson);
            return ExtractedMedia(
              url: vUrl,
              thumbnailUrl: tMatch != null ? _unescapeJsonString(tMatch.group(1)!) : null,
            );
          }
        }
      } catch (_) {}

      // Moteur 3 : Passerelles OpenGraph publiques (ddinstagram / kkinstagram / vxinstagram)
      for (final domain in ['ddinstagram.com', 'kkinstagram.com', 'vxinstagram.com']) {
        try {
          final proxyRes = await _createDio(headers: {
            "User-Agent": "TelegramBot (like TwitterBot)",
          }).get(
            "https://www.$domain/reel/$shortcode",
            options: Options(responseType: ResponseType.plain),
          );
          final html = proxyRes.data?.toString() ?? "";
          final ogVideo = _extractMetaProperty(html, ['og:video', 'og:video:secure_url', 'twitter:player:stream']);
          if (ogVideo != null && ogVideo.startsWith('http')) {
            final fullUrl = ogVideo.startsWith('http') ? ogVideo : 'https://www.$domain$ogVideo';
            final ogThumb = _extractMetaProperty(html, ['og:image']);
            return ExtractedMedia(url: fullUrl, thumbnailUrl: ogThumb);
          }
        } catch (_) {}
      }
    }

    // Moteur 4 : SnapInsta (avec décompresseur du script JS obfusqué eval(function(h,u,n,t,e,r)))
    try {
      final formData = FormData.fromMap({"url": url, "action": "post"});
      final res = await _createDio(headers: {
        "Origin": "https://snapinsta.app",
        "Referer": "https://snapinsta.app/",
        "User-Agent": _desktopUA,
      }).post("https://snapinsta.app/action.php", data: formData, options: Options(responseType: ResponseType.plain));

      final body = res.data?.toString() ?? "";
      final unpacked = _decodeSnapInstaPayload(body) ?? body;
      final mp4Match = RegExp(r'https?:\/\/[^\s"\\<>]+(?:\.mp4|cdninstagram\.com|fbcdn\.net|snapcdn\.app)[^\s"\\<>]*')
          .firstMatch(unpacked);
      if (mp4Match != null) {
        final link = _unescapeJsonString(mp4Match.group(0)!).replaceAll('&amp;', '&');
        if (link.startsWith('http')) return ExtractedMedia(url: link);
      }
    } catch (_) {}

    // Moteur 5 : IGDownloader / FastDL API
    for (final endpoint in [
      "https://v3.igdownloader.net/api/ajaxSearch",
      "https://igdownloader.app/api/ajaxSearch",
    ]) {
      try {
        final formData = FormData.fromMap({"q": url, "t": "media", "lang": "fr"});
        final res = await _createDio(headers: {
          "User-Agent": _desktopUA,
          "Content-Type": "application/x-www-form-urlencoded",
        }).post(endpoint, data: formData);
        if (res.data is Map && res.data['data'] != null) {
          final String html = res.data['data'].toString();
          final match = RegExp(r'href="(https:\/\/[^"]+)"[^>]*class="[^"]*abutton[^"]*"').firstMatch(html) ??
              RegExp(r'href="(https:\/\/[^"]+\.mp4[^"]*)"').firstMatch(html);
          if (match != null) {
            return ExtractedMedia(url: match.group(1)!.replaceAll('&amp;', '&'));
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Décode l'obfuscation JS utilisée par SnapInsta / SaveInsta (`eval(function(h,u,n,t,e,r){...})`)
  static String? _decodeSnapInstaPayload(String js) {
    try {
      final match = RegExp(
        r'\("([A-Za-z0-9]+)",\s*(\d+),\s*"([^"]+)",\s*(\d+),\s*(\d+),\s*(\d+)\)',
      ).firstMatch(js);
      if (match == null) return null;

      final String h = match.group(1)!;
      final String n = match.group(3)!;
      final int t = int.parse(match.group(4)!);
      final int e = int.parse(match.group(5)!);

      const String charset = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ+/";
      int decodeBase(String d, int fromBase, int toBase) {
        final g = charset.substring(0, fromBase);
        int j = 0;
        final reversed = d.split('').reversed.toList();
        for (int idx = 0; idx < reversed.length; idx++) {
          final pos = g.indexOf(reversed[idx]);
          if (pos != -1) {
            j += pos * (BigInt.from(fromBase).pow(idx)).toInt();
          }
        }
        return j;
      }

      final parts = h.split(n[e]);
      final buffer = StringBuffer();
      for (String seg in parts) {
        if (seg.isEmpty) continue;
        for (int j = 0; j < n.length; j++) {
          seg = seg.replaceAll(n[j], j.toString());
        }
        final charCode = decodeBase(seg, e, 10) - t;
        if (charCode > 0 && charCode < 65535) {
          buffer.writeCharCode(charCode);
        }
      }
      return Uri.decodeFull(buffer.toString());
    } catch (_) {
      return null;
    }
  }

  // --- EXTRACTEUR X / TWITTER ---
  static Future<ExtractedMedia?> _extractTwitterX(String url) async {
    final statusMatch = RegExp(r'(?:twitter\.com|x\.com)\/[^\/]+\/status\/(\d+)').firstMatch(url);
    final String? tweetId = statusMatch?.group(1);

    if (tweetId != null) {
      // Moteur 1 : API publique FxTwitter / VxTwitter
      for (final apiBase in [
        'https://api.fxtwitter.com/status/$tweetId',
        'https://api.vxtwitter.com/Twitter/status/$tweetId',
      ]) {
        try {
          final res = await _createDio().get(apiBase);
          if (res.data is Map) {
            final map = res.data as Map;
            // Format FxTwitter
            if (map['tweet'] is Map && map['tweet']['media'] is Map) {
              final media = map['tweet']['media'] as Map;
              if (media['videos'] is List && (media['videos'] as List).isNotEmpty) {
                final vid = (media['videos'] as List).first as Map;
                if (vid['url'] != null) {
                  return ExtractedMedia(
                    url: vid['url'].toString(),
                    thumbnailUrl: vid['thumbnail_url']?.toString(),
                  );
                }
              }
            }
            // Format VxTwitter
            if (map['media_extended'] is List && (map['media_extended'] as List).isNotEmpty) {
              for (final item in (map['media_extended'] as List)) {
                if (item is Map && item['url'] != null && (item['type'] == 'video' || item['type'] == 'gif')) {
                  return ExtractedMedia(
                    url: item['url'].toString(),
                    thumbnailUrl: item['thumbnail_url']?.toString(),
                  );
                }
              }
            }
          }
        } catch (_) {}
      }

      // Moteur 2 : Twitter Syndication API officielle
      try {
        final synRes = await _createDio().get(
          "https://cdn.syndication.twimg.com/tweet-result?id=$tweetId&token=a",
        );
        final raw = synRes.data is String ? synRes.data as String : jsonEncode(synRes.data);
        final mp4Matches = RegExp(r'https:\/\/video\.twimg\.com\/[^\s"\\]+\.mp4[^\s"\\]*')
            .allMatches(raw)
            .map((m) => _unescapeJsonString(m.group(0)!))
            .toList();
        if (mp4Matches.isNotEmpty) {
          return ExtractedMedia(url: mp4Matches.last);
        }
      } catch (_) {}
    }
    return null;
  }

  // --- EXTRACTEUR FACEBOOK ---
  static Future<ExtractedMedia?> _extractFacebook(String url) async {
    try {
      final res = await _createDio(headers: {
        "User-Agent": _desktopUA,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      }).get(url, options: Options(responseType: ResponseType.plain));
      final html = res.data?.toString() ?? "";

      final patterns = [
        RegExp(r'"browser_native_hd_url"\s*:\s*"([^"]+)"'),
        RegExp(r'"playable_url_quality_hd"\s*:\s*"([^"]+)"'),
        RegExp(r'"browser_native_sd_url"\s*:\s*"([^"]+)"'),
        RegExp(r'"playable_url"\s*:\s*"([^"]+)"'),
      ];
      for (final reg in patterns) {
        final m = reg.firstMatch(html);
        if (m != null) {
          final vUrl = _unescapeJsonString(m.group(1)!);
          if (vUrl.startsWith('http')) {
            return ExtractedMedia(url: vUrl);
          }
        }
      }
      final ogVideo = _extractMetaProperty(html, ['og:video', 'og:video:secure_url']);
      if (ogVideo != null && ogVideo.startsWith('http')) {
        return ExtractedMedia(url: ogVideo);
      }
    } catch (_) {}
    return null;
  }

  // --- EXTRACTEUR REDDIT ---
  static Future<ExtractedMedia?> _extractReddit(String url) async {
    try {
      final clean = url.split('?').first.replaceAll(RegExp(r'\/+$'), '');
      final res = await _createDio(headers: {"User-Agent": _desktopUA}).get("$clean.json");
      final raw = res.data is String ? res.data as String : jsonEncode(res.data);

      final hlsMatch = RegExp(r'"hls_url"\s*:\s*"([^"]+)"').firstMatch(raw);
      if (hlsMatch != null) {
        final hlsUrl = _unescapeJsonString(hlsMatch.group(1)!).replaceAll('&amp;', '&');
        if (hlsUrl.startsWith('http')) {
          return ExtractedMedia(url: hlsUrl, isHls: true);
        }
      }
      final fallbackMatch = RegExp(r'"fallback_url"\s*:\s*"([^"]+)"').firstMatch(raw);
      if (fallbackMatch != null) {
        final fbUrl = _unescapeJsonString(fallbackMatch.group(1)!).replaceAll('&amp;', '&');
        if (fbUrl.startsWith('http')) {
          return ExtractedMedia(url: fbUrl);
        }
      }
    } catch (_) {}
    return null;
  }

  // --- CASCADE D'INSTANCES COBALT (V10 & V7) ---
  static Future<ExtractedMedia?> _extractViaCobaltWaterfall(String url) async {
    final endpoints = [
      "https://api.cobalt.tools/",
      "https://cobalt-api.kwiatekmiki.com/",
      "https://cobalt-backend.canine.tools/",
      "https://cobalt.api.timelessnesses.me/",
      "https://cobalt-api.pewpew.nyc/",
      "https://cobalt.qck.ie/",
    ];

    for (final endpoint in endpoints) {
      // Essai format API v10
      try {
        final res = await _createDio(
          timeoutSec: 10,
          headers: {
            "Accept": "application/json",
            "Content-Type": "application/json",
          },
        ).post(endpoint, data: {"url": url, "downloadMode": "auto"});
        if (res.data is Map && res.data['url'] != null) {
          final dlUrl = res.data['url'].toString();
          if (dlUrl.startsWith('http')) {
            return ExtractedMedia(url: dlUrl, isHls: dlUrl.contains('.m3u8'));
          }
        }
      } catch (_) {}

      // Essai format API v7 (/api/json)
      try {
        final base = endpoint.endsWith('/') ? endpoint.substring(0, endpoint.length - 1) : endpoint;
        final resV7 = await _createDio(
          timeoutSec: 8,
          headers: {
            "Accept": "application/json",
            "Content-Type": "application/json",
          },
        ).post("$base/api/json", data: {"url": url});
        if (resV7.data is Map && resV7.data['url'] != null) {
          final dlUrl = resV7.data['url'].toString();
          if (dlUrl.startsWith('http')) {
            return ExtractedMedia(url: dlUrl, isHls: dlUrl.contains('.m3u8'));
          }
        }
      } catch (_) {}
    }
    return null;
  }

  // --- EXTRACTEUR UNIVERSEL HTML / OPENGRAPH / JSON-LD / REGEX (BLACK HOLE SPLITTER) ---
  static Future<ExtractedMedia?> _extractGenericWebMedia(String url) async {
    final userAgents = [_mobileUA, _desktopUA];

    for (final ua in userAgents) {
      try {
        final res = await _createDio(headers: {
          "User-Agent": ua,
          "Referer": url,
        }).get(url, options: Options(responseType: ResponseType.plain));

        // Si la requête a été redirigée directement vers un flux média binaire
        final contentType = (res.headers.value('content-type') ?? '').toLowerCase();
        if (contentType.startsWith('video/') ||
            contentType.startsWith('audio/') ||
            contentType.contains('mpegurl')) {
          final finalUri = res.realUri.toString();
          return ExtractedMedia(
            url: finalUri.isNotEmpty ? finalUri : url,
            isHls: contentType.contains('mpegurl'),
            headers: {"User-Agent": ua, "Referer": url},
          );
        }

        final html = res.data?.toString() ?? "";
        if (html.isEmpty) continue;

        final String? thumb = _extractMetaProperty(html, ['og:image', 'twitter:image']);

        // 1. Balises Meta OpenGraph / Twitter Player
        final metaMedia = _extractMetaProperty(html, [
          'og:video:secure_url',
          'og:video:url',
          'og:video',
          'og:audio:secure_url',
          'og:audio',
          'twitter:player:stream',
        ]);
        if (metaMedia != null && metaMedia.startsWith('http') && !metaMedia.contains('.swf')) {
          return ExtractedMedia(
            url: metaMedia,
            isHls: metaMedia.contains('.m3u8'),
            thumbnailUrl: thumb,
            headers: {"User-Agent": ua, "Referer": url},
          );
        }

        // 2. JSON-LD (contentUrl / embedUrl) et clés JSON courantes (video_url, contentUrl, playable_url, stream_url)
        final jsonUrlPatterns = [
          RegExp(r'"(?:video_url|contentUrl|playable_url_quality_hd|playable_url|hd_src|sd_src|stream_url|audio_url)"\s*:\s*"(https?:[^"]+)"'),
          RegExp(r'<video[^>]+src="([^"]+)"', caseSensitive: false),
          RegExp(r'<audio[^>]+src="([^"]+)"', caseSensitive: false),
          RegExp(r'<source[^>]+src="([^"]+)"', caseSensitive: false),
        ];
        for (final pattern in jsonUrlPatterns) {
          final m = pattern.firstMatch(html);
          if (m != null) {
            String candidate = _unescapeJsonString(m.group(1)!).replaceAll('&amp;', '&');
            if (candidate.startsWith('//')) candidate = 'https:$candidate';
            if (candidate.startsWith('http')) {
              return ExtractedMedia(
                url: candidate,
                isHls: candidate.contains('.m3u8'),
                thumbnailUrl: thumb,
                headers: {"User-Agent": ua, "Referer": url},
              );
            }
          }
        }

        // 3. Recherche directe de flux .mp4 / .m4a / .mp3 / .m3u8 dans le code source de la page
        final rawMediaRegex = RegExp(
          r'https?:\/\/[^\s"\\<>]+?\.(?:mp4|m4a|mp3|m3u8)(?:\?[^\s"\\<>]*)?',
          caseSensitive: false,
        );
        for (final match in rawMediaRegex.allMatches(html)) {
          final candidate = _unescapeJsonString(match.group(0)!).replaceAll('&amp;', '&');
          if (!candidate.contains('blank.mp4') && !candidate.contains('spacer')) {
            return ExtractedMedia(
              url: candidate,
              isHls: candidate.toLowerCase().contains('.m3u8'),
              thumbnailUrl: thumb,
              headers: {"User-Agent": ua, "Referer": url},
            );
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Sniffer WebView jetable (style Black Hole Splitter) :
  /// Lancé uniquement en dernier recours pendant quelques secondes, intercepte les flux `<video>`, `<audio>`,
  /// `fetch`, `XMLHttpRequest` et `performance.getEntriesByType('resource')`, puis est immédiatement détruit.
  static Future<ExtractedMedia?> _sniffMediaViaDisposableWebView(String targetUrl) async {
    final completer = Completer<String?>();
    Timer? pollTimer;
    WebViewController? tempController;

    try {
      tempController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(_mobileUA)
        ..addJavaScriptChannel(
          'MediaSnifferChannel',
          onMessageReceived: (JavaScriptMessage msg) {
            final found = msg.message.trim();
            if (found.startsWith('http') && !found.startsWith('blob:') && !completer.isCompleted) {
              completer.complete(found);
            }
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (req) {
              if (_isDirectMediaUrl(req.url) && !completer.isCompleted) {
                completer.complete(req.url);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        );

      await tempController.loadRequest(Uri.parse(targetUrl));

      pollTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) async {
        if (completer.isCompleted || tempController == null) {
          timer.cancel();
          return;
        }
        try {
          await tempController.runJavaScript('''
            (function() {
              try {
                // 1. Inspection directe des éléments <video>, <audio>, <source>
                const mediaEls = document.querySelectorAll('video, audio, video source, audio source');
                for (const el of mediaEls) {
                  const src = el.currentSrc || el.src || el.getAttribute('src');
                  if (src && src.startsWith('http') && !src.startsWith('blob:')) {
                    MediaSnifferChannel.postMessage(src);
                    return;
                  }
                }
                // 2. Inspection des balises meta OpenGraph
                const og = document.querySelector('meta[property="og:video"], meta[property="og:video:secure_url"], meta[property="og:audio"]');
                if (og && og.content && og.content.startsWith('http')) {
                  MediaSnifferChannel.postMessage(og.content);
                  return;
                }
                // 3. Inspection des ressources réseau chargées (Performance API)
                if (window.performance && window.performance.getEntriesByType) {
                  const entries = window.performance.getEntriesByType('resource');
                  for (const e of entries) {
                    const name = e.name || '';
                    if (/\\.(mp4|m4a|mp3|m3u8)(\\?|\$)/i.test(name) || name.includes('videoplayback') || name.includes('cdninstagram') || name.includes('fbcdn.net')) {
                      if (e.initiatorType === 'video' || e.initiatorType === 'audio' || /\\.(mp4|m4a|mp3|m3u8)/i.test(name)) {
                        MediaSnifferChannel.postMessage(name);
                        return;
                      }
                    }
                  }
                }
              } catch (err) {}
            })();
          ''');
        } catch (_) {}
      });

      final String? mediaUrl = await completer.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => null,
      );

      if (mediaUrl != null && mediaUrl.startsWith('http')) {
        return ExtractedMedia(
          url: mediaUrl,
          isHls: mediaUrl.toLowerCase().contains('.m3u8'),
          headers: {"User-Agent": _mobileUA, "Referer": targetUrl},
        );
      }
    } catch (e) {
      debugPrint("Sniffer WebView jetable ignoré: $e");
    } finally {
      pollTimer?.cancel();
      try {
        await tempController?.loadRequest(Uri.parse('about:blank'));
      } catch (_) {}
      tempController = null;
    }
    return null;
  }

  static String? _extractMetaProperty(String html, List<String> properties) {
    for (final prop in properties) {
      final r1 = RegExp(
        '<meta[^>]+(?:property|name)=["\']$prop["\'][^>]+content=["\']([^"\']+)["\']',
        caseSensitive: false,
      ).firstMatch(html);
      if (r1 != null) return r1.group(1)!.replaceAll('&amp;', '&');

      final r2 = RegExp(
        '<meta[^>]+content=["\']([^"\']+)["\'][^>]+(?:property|name)=["\']$prop["\']',
        caseSensitive: false,
      ).firstMatch(html);
      if (r2 != null) return r2.group(1)!.replaceAll('&amp;', '&');
    }
    return null;
  }

  static String _unescapeJsonString(String raw) {
    return raw
        .replaceAll(r'\/', '/')
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\u002F', '/')
        .replaceAll(r'\u003D', '=')
        .replaceAll(r'\u0025', '%')
        .replaceAll(r'\\&', '&')
        .replaceAll('&amp;', '&');
  }
}