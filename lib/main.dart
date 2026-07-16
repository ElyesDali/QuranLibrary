import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // Pour compute (optimisation)
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  } else {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.muhammad.luhaidan.app',
      androidNotificationChannelName: 'Quran Library',
      androidNotificationOngoing: true,
    );
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
        final ytUrl = request.uri.queryParameters['url'];
        if (ytUrl != null) {
          _cleanCache();
          if (_urlCache.containsKey(ytUrl) && _urlCache[ytUrl]!.isValid) {
            try { await request.response.redirect(Uri.parse(_urlCache[ytUrl]!.url), status: HttpStatus.movedTemporarily); } catch (_) {}
            return;
          }
          
          if (ytUrl.contains('instagram') || ytUrl.contains('tiktok')) {
            // L'APPEL AU NOUVEAU RÉSEAU DE SERVEURS
            final streamUrl = await MediaExtractor.getDownloadUrl(ytUrl);
            if (streamUrl != null) {
              _urlCache[ytUrl] = _CachedUrl(streamUrl);
              try { await request.response.redirect(Uri.parse(streamUrl), status: HttpStatus.movedTemporarily); } catch (_) {}
            } else {
              try { request.response.statusCode = 404; } catch (_) {}
            }
            return;
          } else {
            var yt = YoutubeExplode();
            var manifest = await yt.videos.streamsClient.getManifest(ytUrl);
            var streamInfo = manifest.muxed.withHighestBitrate();
            yt.close();
            _urlCache[ytUrl] = _CachedUrl(streamInfo.url.toString());
            try { await request.response.redirect(streamInfo.url, status: HttpStatus.movedTemporarily); } catch (_) {}
            return;
          }
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
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription? _positionSubscription; // NOUVEAU : Le garde-fou de la mémoire
  Map<String, dynamic>? currentRecitation;
  int _playRequestId = 0; // Fix race conditions during track change
  
  double volume = 0.8;
  LoopModeState loopMode = LoopModeState.off;
  int? selectedYearFilter;
  Database? _db;
  bool _isDownloading = false;
  double? _dragValue;
  bool _isSwitchingTrack = false;
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
    WebScraper.init(); // Initialisation du navigateur invisible
    WidgetsBinding.instance.addObserver(this); // On allume le radar
    _initApp();
    _player.setVolume(volume);
    
    _player.setLoopMode(loopMode == LoopModeState.one ? LoopMode.one : LoopMode.off);

    _positionSubscription?.cancel(); 
    _positionSubscription = _player.positionStream.listen((pos) {
      int currentMs = pos.inMilliseconds;
      int durationMs = _player.duration?.inMilliseconds ?? 0;

      // FILTRE ANTI-HOQUET : On ignore les bonds temporels absurdes dans la seconde qui suit le réveil de l'app
      if (DateTime.now().difference(_lastWakeUp).inMilliseconds < 1000) return;

      _lastPos = currentMs;
      _lastDuration = durationMs;
    });

    _player.currentIndexStream.listen((index) async {
      // CORRECTIF 1 : On coupe ce radar sur Windows, car on n'utilise plus de playlist !
      if (Platform.isWindows || index == null || _isSwitchingTrack) return;
      
      if (mounted && index < displayedRecitations.length) {
         if (loopMode == LoopModeState.off && _playingIndex != null && index != _playingIndex) {
            // Si la piste précédente s'est terminée normalement (position près de la durée), on met en pause.
            if (_lastPos >= _lastDuration - 1000) {
               _player.pause();
               _player.seek(Duration.zero, index: _playingIndex);
               return;
            }
         }
         
         _playingIndex = index;
         setState(() => currentRecitation = displayedRecitations[index]);
         final prefs = await SharedPreferences.getInstance();
         prefs.setInt('last_played_id', displayedRecitations[index]['id']);
      }
    });

    // CORRECTIF 2 : Le passage automatique à la piste suivante sur Windows
    if (Platform.isWindows) {
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (loopMode == LoopModeState.off) {
            _player.pause();
            _player.seek(Duration.zero);
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // On éteint le radar
    _positionSubscription?.cancel();
    _sleepTimer?.cancel();
    _countdownTimer?.cancel();
    _player.dispose();
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
    
    // Laisser le temps à l'application de s'afficher avant de bloquer le réseau
    await Future.delayed(const Duration(seconds: 3));
    
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) return; // Pas de connexion internet

    for (var rec in allRecitations) {
      if (!mounted) break;
      String path = rec['fichier'] ?? "";
      if (path.isEmpty || path.startsWith('http')) continue;

      if (path.contains('youtube') || path.contains('youtu.be') || path.contains('shorts') || path.contains('instagram') || path.contains('tiktok')) {
        final localFile = File(p.join(_appDirPath!, "yt_${rec['id']}.mp4"));
        if (!await localFile.exists() || await localFile.length() < 50000) {
          if (!_activeDownloads.containsKey(rec['id'])) {
             try {
                // On télécharge silencieusement en arrière-plan
                _startDownload(rec['id'], path, localFile);
             } catch (e) {
                debugPrint("Auto-download failed for ${rec['id']}: $e");
             }
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
      validFiles.add("thumb_yt_${rec['id']}.jpg");
      validFiles.add("temp_edit_${rec['id']}.mp4"); // Bouclier pour les fichiers en cours de montage !
    }
    
    for (var f in files) {
      if (f is File) {
        final basename = p.basename(f.path);
        if (basename.endsWith('.tmp')) {
          try { await f.delete(); } catch (_) {}
        } else if ((basename.endsWith('.mp4') || basename.endsWith('.jpg') || basename.endsWith('.mp3')) && !validFiles.contains(basename)) {
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
      
      if (lastPlayedId != null && allRecitations.isNotEmpty && currentRecitation == null) {
         int idx = allRecitations.indexWhere((r) => r['id'] == lastPlayedId);
         if (idx != -1) {
            currentRecitation = allRecitations[idx];
         }
      }

      _applyFilters();
    });
    
    // NOUVEAU : Lance la réparation automatique en arrière-plan
    _checkMissingThumbnails(res ?? []);
  }

  Future<void> _checkMissingThumbnails(List<dynamic> recs) async {
    if (_appDirPath == null) return;
    bool hasUpdates = false;
    
    for (var rec in recs) {
      String thumb = rec['thumbnail'] ?? "";
      String fileStr = rec['fichier'] ?? "";
      bool needsThumb = false;
      
      // On regarde s'il manque une miniature locale
      if (thumb.isEmpty) {
         needsThumb = true;
      } else if (!thumb.startsWith('http')) {
         final thumbFile = File(p.join(_appDirPath!, thumb));
         if (!await thumbFile.exists()) needsThumb = true;
      }

      // Si oui, on extrait une nouvelle image de la vidéo
      if (needsThumb) {
         File? videoFile;
         if (fileStr.contains('youtube') || fileStr.contains('tiktok') || fileStr.contains('instagram')) {
            videoFile = File(p.join(_appDirPath!, "yt_${rec['id']}.mp4"));
         } else {
            videoFile = File(p.join(_appDirPath!, fileStr));
         }
         
         if (videoFile.existsSync()) {
            try {
               final thumbData = await VideoThumbnail.thumbnailData(video: videoFile.path, imageFormat: ImageFormat.JPEG, maxWidth: 300, quality: 50);
               if (thumbData != null) {
                 String newThumb = "thumb_${rec['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg";
                 await File(p.join(_appDirPath!, newThumb)).writeAsBytes(thumbData);
                 await _db?.update('recitations', {'thumbnail': newThumb}, where: 'id = ?', whereArgs: [rec['id']]);
                 hasUpdates = true;
               }
            } catch (_) {}
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
    _updateFullPlaylist(); 
  }

  Future<void> _updateFullPlaylist() async {
    // Cette fonction n'est désormais appelée que sur Mobile pour stabiliser le PC
    if (Platform.isWindows) return;

    List<AudioSource> sources = [];

    final futures = displayedRecitations.map((rec) async {
      String path = rec['fichier'] ?? "";
      Uri uri;

      if (path.contains('youtube.com') || path.contains('youtu.be') || path.contains('shorts') || path.contains('instagram') || path.contains('tiktok')) {
        final localFile = File(p.join(_appDirPath!, "yt_${rec['id']}.mp4"));
        if (await localFile.exists()) {
          uri = Uri.file(localFile.path);
        } else {
          uri = Uri.parse(ProxyServer.getProxyUrl(path)); 
        }
      } else {
        String resolved = _resolvePath(path);
        if (resolved.startsWith('http') || resolved.startsWith('https')) {
          uri = Uri.parse(resolved); // Correctif crucial : allocation réseau propre
        } else {
          uri = Uri.file(resolved);
        }
      }
      return {'rec': rec, 'uri': uri};
    }).toList();

    final results = await Future.wait(futures);

    for (var res in results) {
      final rec = res['rec'] as Map<String, dynamic>;
      final uri = res['uri'] as Uri;
      
      final tag = _createMediaItem(rec);
      final baseSource = AudioSource.uri(uri, tag: tag);
      
      if (rec['duration'] != null && rec['duration'].toString().contains(':')) {
         try {
           final parts = rec['duration'].toString().split(':');
           if (parts.length == 2) {
             final dur = Duration(minutes: int.parse(parts[0]), seconds: int.parse(parts[1]));
             sources.add(ClippingAudioSource(child: baseSource, end: dur, tag: tag));
             continue;
           }
         } catch (_) {}
      }
      sources.add(baseSource);
    }

    if (sources.isNotEmpty) {
      final newPlaylist = ConcatenatingAudioSource(children: sources);
      try {
        await _player.setAudioSource(newPlaylist, initialIndex: _playingIndex ?? 0);
      } catch (_) {}
    }
  }

  MediaItem _createMediaItem(Map<String, dynamic> r) {
    Duration? exactDur;
    if (r['duration'] != null && r['duration'].toString().contains(':')) {
      // Le même bouclier s'applique ici pour le lecteur en arrière-plan
      try {
        final parts = r['duration'].toString().split(':');
        if (parts.length == 2) {
           exactDur = Duration(minutes: int.parse(parts[0]), seconds: int.parse(parts[1]));
        }
      } catch (_) {}
    }
    
    Uri? artUri;
    if (r['thumbnail'] != null && r['thumbnail'].toString().isNotEmpty) {
      String resolved = _resolvePath(r['thumbnail'].toString());
      artUri = resolved.startsWith('http') ? Uri.parse(resolved) : Uri.file(resolved);
    }
    return MediaItem(
      id: "${r['id']}_${DateTime.now().millisecondsSinceEpoch}",
      album: "Muhammad",
      title: "${r['sourate_num'].toString().padLeft(3, '0')} - ${r['sourate_name']}",
      artist: "Muhammad",
      artUri: artUri,
      duration: exactDur,
    );
  }

  String _resolvePath(String pathStr) {
    if (pathStr.startsWith('http')) return pathStr;
    if (pathStr.startsWith('/')) return pathStr; 
    return _appDirPath != null ? p.join(_appDirPath!, pathStr) : pathStr;
  }

  Future<void> _startDownload(int id, String cleanUrl, File localFile) async {
    if (_activeDownloads.containsKey(id)) return; 
    
    setState(() => _activeDownloads[id] = 0.0);
    YoutubeExplode? yt;
    final tempFile = File("${localFile.path}.tmp"); 
    
    try {
      String downloadUrl = "";
      
      if (cleanUrl.contains('instagram') || cleanUrl.contains('tiktok')) {
        final extracted = await MediaExtractor.getDownloadUrl(cleanUrl);
        if (extracted == null) throw Exception("Impossible de trouver la vidéo (Lien privé ou invalide).");
        downloadUrl = extracted;
      } else {
        yt = YoutubeExplode();
        var manifest = await yt.videos.streamsClient.getManifest(cleanUrl);
        var mp4Muxed = manifest.muxed.where((s) => s.container.name == 'mp4');
        var streamInfo = mp4Muxed.isNotEmpty 
            ? mp4Muxed.withHighestBitrate() 
            : manifest.audioOnly.where((s) => s.container.name == 'mp4').withHighestBitrate();
        downloadUrl = streamInfo.url.toString();
      }
      
      int expectedTotal = -1;
      int lastUpdateValue = 0;
      
      await Dio().download(
        downloadUrl,
        tempFile.path,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
            // CRITIQUE : AUCUN REFERER ICI. On laisse Instagram penser qu'on navigue normalement.
          },
          receiveTimeout: const Duration(seconds: 30),
          followRedirects: true, 
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            expectedTotal = total;
            int percentage = ((received / total) * 100).toInt();
            if (percentage != lastUpdateValue) {
              lastUpdateValue = percentage;
              if (mounted) setState(() => _activeDownloads[id] = percentage / 100.0);
            }
          } else {
            int megabyteStep = (received / 500000).toInt(); 
            if (megabyteStep != lastUpdateValue) {
              lastUpdateValue = megabyteStep;
              if (mounted) setState(() => _activeDownloads[id] = -(received.toDouble()));
            }
          }
        },
      );
      
      if (await tempFile.exists() && await tempFile.length() > 50000) { 
        if (expectedTotal != -1 && await tempFile.length() < expectedTotal) {
           throw Exception("Téléchargement incomplet (le fichier a été coupé).");
        }

        if (await localFile.exists()) await localFile.delete(); 
        await tempFile.rename(localFile.path); 
        
        if (cleanUrl.contains('instagram') || cleanUrl.contains('tiktok')) {
          if (!Platform.isWindows) { // <-- PROTECTION WINDOWS
            try {
               final metadata = await MetadataRetriever.fromFile(localFile);
               if (metadata.trackDuration == null || metadata.trackDuration == 0) {
                  throw Exception("Fichier corrompu (pas de durée audio valide).");
               }
               
               String newDur = "--:--";
               final d = Duration(milliseconds: metadata.trackDuration!);
               newDur = "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
               
               String newThumb = "thumb_yt_$id.jpg";
               final thumbData = await VideoThumbnail.thumbnailData(
                 video: localFile.path,
                 imageFormat: ImageFormat.JPEG,
                 maxWidth: 300, 
                 quality: 50,
               );
               
               if (thumbData != null) {
                 final thumbFile = File(p.join(localFile.parent.path, newThumb));
                 await thumbFile.writeAsBytes(thumbData);
               } else {
                 newThumb = ""; 
               }

               if (newDur != "--:--" || newThumb.isNotEmpty) {
                  await _db?.update('recitations', {'duration': newDur, 'thumbnail': newThumb}, where: 'id = ?', whereArgs: [id]);
               }
            } catch (e) {
               if (e.toString().contains("Fichier corrompu")) rethrow;
               debugPrint("Erreur métadonnées: $e");
            }
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Vidéo prête pour le hors-ligne !", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green, duration: Duration(seconds: 3))
          );
        }
        _fetch(); 
        _updateFullPlaylist(); 
      } else {
        throw Exception("Fichier corrompu ou illisible.");
      }
    } catch (e) {
      debugPrint("Erreur téléchargement: $e");
      if (await tempFile.exists()) {
         try { await tempFile.delete(); } catch (_) {}
      }
      
      if (!await localFile.exists()) {
          await _db?.delete('recitations', where: 'id = ?', whereArgs: [id]);
          if (mounted) _fetch(); 
      }

      // AFFICHAGE DYNAMIQUE DE L'ERREUR
      String errorMsg = e.toString();
      if (errorMsg.contains("Exception:")) {
         errorMsg = errorMsg.split("Exception:").last.trim();
      } else {
         errorMsg = "Échec (${errorMsg.split('\n')[0]})"; 
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ $errorMsg"), backgroundColor: Colors.red, duration: const Duration(seconds: 6))
        );
      }
    } finally {
      yt?.close();
      if (mounted) setState(() => _activeDownloads.remove(id)); 
    }
  }

  Future<void> _play(Map<String, dynamic> rec) async {
    int index = displayedRecitations.indexWhere((r) => r['id'] == rec['id']);
    if (index == -1) return;

    final reqId = ++_playRequestId;

    String path = rec['fichier'] ?? "";
    Uri uri;

    try {
      if (path.contains('youtube') || path.contains('youtu.be') || path.contains('shorts') || path.contains('instagram') || path.contains('tiktok')) {
        final localFile = File(p.join(_appDirPath!, "yt_${rec['id']}.mp4"));
        if (await localFile.exists()) {
          if (await localFile.length() < 50000) {
            await localFile.delete(); 
            uri = Uri.parse(ProxyServer.getProxyUrl(path));
          } else {
            uri = Uri.file(localFile.path);
          }
        } else {
          uri = Uri.parse(ProxyServer.getProxyUrl(path));
        }
      } else {
        String resolved = _resolvePath(path);
        if (resolved.startsWith('http') || resolved.startsWith('https')) {
          uri = Uri.parse(resolved);
        } else {
          final f = File(resolved);
          if (await f.exists() && await f.length() < 1000) {
            await f.delete(); 
          }
          if (!await f.exists()) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("❌ Fichier introuvable sur le disque. Veuillez retélécharger la récitation."), 
                backgroundColor: Colors.red
              ));
            }
            return; 
          }
          uri = Uri.file(resolved);
        }
      }

      if (reqId != _playRequestId) return; // A newer request was made

      _isSwitchingTrack = true;
      setState(() {
        currentRecitation = rec;
        _playingIndex = index;
      });

      if (Platform.isWindows) {
        final tag = _createMediaItem(rec);
        var loadFuture = _player.setAudioSource(AudioSource.uri(uri, tag: tag));
        _player.play(); // Queues playback to start automatically once loaded
        await loadFuture;
      } else {
        await _updateFullPlaylist(); 
        if (reqId != _playRequestId) return;
        
        var seekFuture = _player.seek(Duration.zero, index: index);
        _player.play();
        await seekFuture;
      }

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
    int index = displayedRecitations.indexWhere((r) => r['id'] == currentRecitation?['id']);
    _play(displayedRecitations[(index - 1 + displayedRecitations.length) % displayedRecitations.length]);
  }

  void _toggleLoop() {
    setState(() {
      if (loopMode == LoopModeState.off) {
        loopMode = LoopModeState.autoplay;
        _player.setLoopMode(LoopMode.off); // Laisse avancer à la suivante
      } else if (loopMode == LoopModeState.autoplay) {
        loopMode = LoopModeState.one;
        _player.setLoopMode(LoopMode.one); // Boucle native parfaite
      } else {
        loopMode = LoopModeState.off;
        _player.setLoopMode(LoopMode.off); // CORRECTION: Rétablir LoopMode.off pour réparer les boutons Next/Prev d'AirPlay
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
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  Widget _buildThumbnail(String? thumbPath) {
    if (thumbPath == null || thumbPath.isEmpty) {
      return Image.asset(
        'assets/logo.jpg', 
        width: 50, 
        height: 50, 
        fit: BoxFit.cover, 
        errorBuilder: (_, __, ___) => const Icon(Icons.mic, size: 40)
      );
    }
    
    String resolvedPath = _resolvePath(thumbPath);
    if (resolvedPath.startsWith('http')) {
      return Image.network(
        resolvedPath, 
        width: 50, 
        height: 50, 
        fit: BoxFit.cover, 
        errorBuilder: (_, __, ___) => const Icon(Icons.mic, size: 40)
      );
    } else {
      return Image.file(
        File(resolvedPath), 
        width: 50, 
        height: 50, 
        fit: BoxFit.cover, 
        errorBuilder: (_, __, ___) => const Icon(Icons.mic, size: 40)
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
        if (f is File && (f.path.endsWith('.mp4') || f.path.endsWith('.jpg'))) {
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
        } else if (cleanName.endsWith('.mp4') || cleanName.endsWith('.jpg') || cleanName.endsWith('.mov')) {
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
                // Navigateur invisible pour le scraping
                Positioned(
                  left: -1000,
                  top: -1000,
                  width: 100,
                  height: 100,
                  child: WebScraper.controller != null 
                      ? WebViewWidget(controller: WebScraper.controller!) 
                      : const SizedBox(),
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
          
          const SizedBox(height: 4),
          
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, snapshot) {
              final pos = snapshot.data ?? Duration.zero;
              final dur = _player.duration ?? Duration.zero;
              double maxDur = dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0;
              double sliderVal = _dragValue ?? pos.inSeconds.toDouble().clamp(0, maxDur);
              
              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0), 
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0)
                    ),
                    child: Slider(
                      activeColor: const Color(0xFF7EB8C9), 
                      inactiveColor: Colors.white24,
                      value: sliderVal, 
                      max: maxDur,
                      onChanged: (v) => setState(() => _dragValue = v),
                      onChangeEnd: (v) {
                        // CORRECTIF 3 : On retire l'index pour cibler la piste unique !
                        _player.seek(Duration(seconds: v.toInt()));
                        setState(() => _dragValue = null);
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                    children: [
                      Text(
                        _formatDuration(Duration(seconds: sliderVal.toInt())), 
                        style: const TextStyle(fontSize: 11, color: Colors.grey)
                      ), 
                      Text(
                        _formatDuration(dur), 
                        style: const TextStyle(fontSize: 11, color: Colors.grey)
                      )
                    ]
                  ),
                ],
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
                          await _player.seek(Duration.zero, index: _playingIndex);
                        }
                        _player.play();
                      } else {
                        _player.pause();
                      }
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
                  _player.seek(Duration.zero, index: _playingIndex);
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
                final dir = await getApplicationDocumentsDirectory();
                
                // A. Supprimer la vidéo YouTube (si existante)
                final ytFile = File(p.join(dir.path, "yt_${rec['id']}.mp4"));
                if (await ytFile.exists()) await ytFile.delete();

                // B. Supprimer le fichier vidéo Local (si existant)
                String fileStr = rec['fichier'] ?? "";
                if (!fileStr.contains('youtu') && fileStr.isNotEmpty) {
                  final localFile = File(p.join(dir.path, fileStr));
                  if (await localFile.exists()) await localFile.delete();
                }

                // C. Supprimer la miniature associée (si elle est téléchargée localement)
                String thumbStr = rec['thumbnail'] ?? "";
                if (thumbStr.isNotEmpty && !thumbStr.startsWith('http')) {
                  final thumbFile = File(p.join(dir.path, thumbStr));
                  if (await thumbFile.exists()) await thumbFile.delete();
                }
              } catch (e) {
                debugPrint("Erreur lors de la suppression des fichiers : $e");
              }

              // 4. RAFRAÎCHIR L'INTERFACE ET LA PLAYLIST AIRPLAY
              _fetch(); 
            },
            // LA LIGNE MANQUANTE EST JUSTE ICI :
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
        initialUrl: initialUrl,
        onDownload: (id, url, file) => _startDownload(id, url, file),
        onEdit: _launchEditorAndSave, // NOUVEAU : On connecte l'éditeur au formulaire !
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
      Map<String, dynamic> meta = result['metadata'];
      final dir = await getApplicationDocumentsDirectory();
      
      if (meta.containsKey('id') && meta['id'] != null) {
        // CAS 1 : MODIFICATION
        int id = meta['id'];
        String newFileName = "edited_${id}_${DateTime.now().millisecondsSinceEpoch}.mp4"; 
        File finalDest = File(p.join(dir.path, newFileName));
        
        await editedFile.copy(finalDest.path);

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
             await File(p.join(dir.path, newThumb)).writeAsBytes(thumbData);
           } else {
             newThumb = meta['thumbnail'] ?? "";
           }
           
           await _db?.update('recitations', {'fichier': newFileName, 'duration': newDur, 'thumbnail': newThumb}, where: 'id = ?', whereArgs: [id]);
        } catch (_) {}
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Récitation modifiée avec succès !"), backgroundColor: Colors.green));
      } else {
        // CAS 2 : NOUVELLE VIDÉO
        String newFileName = "local_${DateTime.now().millisecondsSinceEpoch}.mp4";
        File finalDest = File(p.join(dir.path, newFileName));
        await editedFile.copy(finalDest.path);
        
        meta['fichier'] = newFileName;
        await _db?.insert('recitations', meta);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Nouvelle vidéo enregistrée et rognée !"), backgroundColor: Colors.green));
      }
      
      setState(() {
        currentRecitation = null;
        _playingIndex = null;
      });

      await _fetch(); // C'EST TOUT ! Ne rajoute SURTOUT PAS _updateFullPlaylist() après !

      if (await editedFile.exists()) await editedFile.delete();
      if (meta.containsKey('id')) {
        final tempEdit = File(p.join(dir.path, "temp_edit_${meta['id']}.mp4"));
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
                  // 1. Soit c'est un fichier YouTube/Insta (stocké en yt_ID.mp4)
                  // 2. Soit c'est un import local (stocké avec son nom d'origine)
                  final File ytFile = File(p.join(_appDirPath!, "yt_$id.mp4"));
                  final File localFile = File(p.join(_appDirPath!, fileName));

                  bool exists = ytFile.existsSync() || (fileName.isNotEmpty && localFile.existsSync() && !fileName.startsWith('http'));

                  if (!exists) return const SizedBox.shrink(); // On cache si le fichier n.est pas sur le téléphone
                  
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
      final dir = await getApplicationDocumentsDirectory();
      File sourceFile;
      
      final id = rec['id'];
      final fileName = rec['fichier']?.toString() ?? "";
      final File ytFile = File(p.join(dir.path, "yt_$id.mp4"));
      final File localFile = File(p.join(dir.path, fileName));

      // On détermine quel fichier utiliser
      if (ytFile.existsSync()) {
        sourceFile = ytFile;
      } else if (localFile.existsSync()) {
        sourceFile = localFile;
      } else {
        throw Exception("Fichier introuvable sur l'appareil.");
      }

      // Création de la copie temporaire pour l'éditeur
      final tempFile = File(p.join(dir.path, "temp_edit_${rec['id']}.mp4"));
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
      _lastWakeUp = DateTime.now(); // On note l'heure du réveil
      
      // Resynchronisation AirPlay en douceur : 
      // Si rien ne joue quand on rouvre l'app, on recharge la mémoire iOS
      if (!_player.playing) {
        _updateFullPlaylist();
      }
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
          if (name.startsWith('luhaidan.db') || name.endsWith('.mp4') || name.endsWith('.jpg') || name.endsWith('.mov')) {
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

class YoutubeBrowserScreen extends StatefulWidget {
  final Database? db;
  final VoidCallback onSave;
  final Function(int, String, File)? onDownload; 

  const YoutubeBrowserScreen({super.key, required this.db, required this.onSave, this.onDownload});

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
  final String? initialUrl; 
  final Function(int, String, File)? onDownload;
  final Function(File, Map<String, dynamic>)? onEdit; // <-- LIGNE AJOUTÉE
  
  const FormDialog({super.key, this.rec, required this.onSave, this.db, this.initialUrl, this.onDownload, this.onEdit});
  
  @override 
  State<FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<FormDialog> {
  int? selectedNum = 1;
  String? selectedName = "Al-Fatiha";
  
  late TextEditingController _yearInput, _file, _ytUrl, _vStart, _vEnd;
  String _sourceType = "local"; // NOUVEAU : Gère 4 états
  bool isFull = true;

  @override
  void initState() {
    super.initState();
    
    // Auto-détection du lien
    if (widget.rec != null) {
      String f = widget.rec!['fichier']?.toString() ?? "";
      if (f.contains('youtu')) _sourceType = "youtube";
      else if (f.contains('instagram')) _sourceType = "instagram";
      else if (f.contains('tiktok')) _sourceType = "tiktok";
      else _sourceType = "local";
    } else if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _sourceType = "youtube"; 
    }
    
    if (widget.rec != null) {
      selectedNum = widget.rec!['sourate_num'];
      selectedName = widget.rec!['sourate_name'];
      isFull = widget.rec!['versets'] == "complet";
    }
    
    _yearInput = TextEditingController(text: widget.rec?['annee']?.toString() ?? "");
    _file = TextEditingController(text: (widget.rec != null && _sourceType == "local") ? widget.rec!['fichier'] : "");
    _ytUrl = TextEditingController(text: widget.initialUrl ?? ((widget.rec != null && _sourceType != "local") ? widget.rec!['fichier'] : ""));
    
    _vStart = TextEditingController(); 
    _vEnd = TextEditingController();
    
    if (widget.rec != null && !isFull) {
      List<String> parts = widget.rec!['versets'].split('-');
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
              initialSelection: widget.rec != null ? ALL_SURAHS.firstWhere((s) => s['num'] == widget.rec!['sourate_num']) : ALL_SURAHS[0],
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

            // --- NOUVEAUTÉ : Les 4 puces de sélection rapides ---
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text("Local", style: TextStyle(fontSize: 12)), 
                  selected: _sourceType == "local", 
                  onSelected: (v) => setState(() => _sourceType = "local"),
                  selectedColor: const Color(0xFF4A8FA3),
                  showCheckmark: false,
                ),
                ChoiceChip(
                  label: const Text("YouTube", style: TextStyle(fontSize: 12)), 
                  selected: _sourceType == "youtube", 
                  onSelected: (v) => setState(() => _sourceType = "youtube"),
                  selectedColor: const Color(0xFF4A8FA3),
                  showCheckmark: false,
                ),
                ChoiceChip(
                  label: const Text("Instagram", style: TextStyle(fontSize: 12)), 
                  selected: _sourceType == "instagram", 
                  onSelected: (v) => setState(() => _sourceType = "instagram"),
                  selectedColor: const Color(0xFF4A8FA3),
                  showCheckmark: false,
                ),
                ChoiceChip(
                  label: const Text("TikTok", style: TextStyle(fontSize: 12)), 
                  selected: _sourceType == "tiktok", 
                  onSelected: (v) => setState(() => _sourceType = "tiktok"),
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
                    final dir = await getApplicationDocumentsDirectory();
                    await File(file.path!).copy(p.join(dir.path, file.name));
                    setState(() => _file.text = file.name);
                  }
                }, 
                child: const Text("Choisir un fichier .mp4 / .mp3")
              )
            else 
              TextField(
                controller: _ytUrl, 
                decoration: InputDecoration(
                  labelText: _sourceType == "youtube" 
                    ? "Lien YouTube" 
                    : (_sourceType == "instagram" ? "Lien du Reel (Instagram)" : "Lien de la vidéo (TikTok)")
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
              final dir = await getApplicationDocumentsDirectory();
              final videoFile = File(p.join(dir.path, _file.text));
              
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Veuillez choisir un fichier vidéo."), backgroundColor: Colors.red));
              return;
            }
            if (_sourceType != "local" && _ytUrl.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Veuillez coller un lien."), backgroundColor: Colors.red));
              return;
            }
            // --------------------------------------------------------------------
            
            try {
              String thumb = widget.rec?['thumbnail'] ?? "";
              String dur = widget.rec?['duration'] ?? "";
              
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

              // --- Logique de récupération initiale ---
              if (_sourceType == "youtube" && _ytUrl.text.isNotEmpty) {
                var yt = YoutubeExplode();
                var video = await yt.videos.get(_ytUrl.text);
                dur = "${video.duration?.inMinutes}:${((video.duration?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')}";
                
                try {
                   final dir = await getApplicationDocumentsDirectory();
                   final thumbName = "thumb_yt_${video.id}.jpg";
                   await Dio().download(video.thumbnails.highResUrl, p.join(dir.path, thumbName));
                   thumb = thumbName;
                } catch (_) { 
                   thumb = video.thumbnails.standardResUrl; 
                }
                yt.close();
              } 
              else if ((_sourceType == "instagram" || _sourceType == "tiktok") && _ytUrl.text.isNotEmpty) {
                dur = "--:--"; 
                thumb = ""; 
              } 
              else if (_sourceType == "local" && _file.text.isNotEmpty) {
                final dir = await getApplicationDocumentsDirectory();
                final localFilePath = p.join(dir.path, _file.text);
                
                if (!Platform.isWindows) { // <-- PROTECTION WINDOWS
                  try {
                    final metadata = await MetadataRetriever.fromFile(File(localFilePath));
                    if (metadata.trackDuration != null) {
                      final d = Duration(milliseconds: metadata.trackDuration!);
                      dur = "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
                    }
                    if (metadata.albumArt != null) {
                      final thumbName = "thumb_${_file.text}.jpg";
                      await File(p.join(dir.path, thumbName)).writeAsBytes(metadata.albumArt!);
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
                "fichier": _sourceType == "local" ? _file.text : _ytUrl.text,
                "versets": isFull ? "complet" : "${_vStart.text}-${_vEnd.text}",
                "thumbnail": thumb, 
                "duration": dur,
              };
              
              int recordId = widget.rec == null ? await widget.db!.insert('recitations', data) : widget.rec!['id'];
              if (widget.rec != null) await widget.db!.update('recitations', data, where: 'id = ?', whereArgs: [recordId]);
              
              if (_sourceType != "local" && _ytUrl.text.isNotEmpty) {
                final cleanUrl = _ytUrl.text;
                final dir = await getApplicationDocumentsDirectory();
                final localAudioFile = File(p.join(dir.path, "yt_$recordId.mp4"));
                if (!await localAudioFile.exists()) {
                  widget.onDownload?.call(recordId, cleanUrl, localAudioFile);
                }
              }
              
              widget.onSave(); 
              if (mounted) Navigator.pop(context);

            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Erreur : Lien invalide ou vidéo privée"), backgroundColor: Colors.red));
              }
            }
          }, 
          child: const Text("Enregistrer", style: TextStyle(color: Colors.white))
        )
      ],
    );
  }
}

// Scraper système D pour Instagram (Contourne les blocages d'API publiques)
class WebScraper {
  static WebViewController? controller;
  static Completer<String?>? _completer;
  static String _currentUrl = "";

  static void init() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;
    try {
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel('ScraperChannel', onMessageReceived: (message) {
           if (_completer != null && !_completer!.isCompleted) {
              String url = message.message;
              if (url.startsWith('http')) {
                 _completer!.complete(url);
              }
           }
        });
    } catch (_) {
      debugPrint("WebScraper init failed");
    }
  }

  static Future<String?> extractInstagram(String igUrl) async {
    if (controller == null) return null;
    
    // Ordre de fallback
    List<String> sites = ['https://fastdl.app/en', 'https://snapinsta.app/fr', 'https://igram.world/'];
    
    for (String site in sites) {
       _completer = Completer<String?>();
       _currentUrl = igUrl;
       
       await controller!.loadRequest(Uri.parse(site));
       
       Timer? checkTimer;
       checkTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
          if (_completer != null && _completer!.isCompleted) {
             timer.cancel();
             return;
          }
          try {
            await controller!.runJavaScript('''
               // Script for fastdl / igram
               let inp1 = document.getElementById('search-form-input');
               let btn1 = document.querySelector('.search-form__button');
               if (inp1 && btn1 && inp1.value === '') {
                   inp1.value = '$_currentUrl';
                   btn1.click();
               }
               let res1 = document.querySelector('.button--download');
               if (res1 && res1.href && res1.href.startsWith('http')) {
                   ScraperChannel.postMessage(res1.href);
               }

               // Script for snapinsta
               let inp2 = document.getElementById('url');
               let btn2 = document.getElementById('btn-submit');
               if (inp2 && btn2 && inp2.value === '') {
                   inp2.value = '$_currentUrl';
                   btn2.click();
               }
               let res2 = document.querySelector('.download-bottom a');
               if (!res2) res2 = document.querySelector('a.btn.download-media');
               if (res2 && res2.href && res2.href.startsWith('http') && res2.href.includes('download')) {
                   ScraperChannel.postMessage(res2.href);
               }
            ''');
          } catch (_) {}
       });

       String? result;
       try {
         result = await _completer!.future.timeout(const Duration(seconds: 15));
       } catch (e) {
         result = null; 
       }
       
       checkTimer.cancel();
       
       if (result != null && result.startsWith('http')) {
          return result;
       }
    }
    return null;
  }
}


class MediaExtractor {
  static Future<String?> getDownloadUrl(String targetUrl) async {
    String cleanUrl = targetUrl.trim();
    
    // NOUVEAU : API spécifique pour TikTok (TikMate) qui fonctionne sans clé
    if (cleanUrl.contains('tiktok')) {
      try {
        final res = await Dio().post(
          "https://api.tikmate.app/api/lookup",
          data: {"url": cleanUrl},
          options: Options(headers: {
             "Content-Type": "application/x-www-form-urlencoded",
          })
        );
        if (res.data != null && res.data['success'] == true) {
           return "https://tikmate.app/download/${res.data['token']}/${res.data['id']}.mp4";
        }
      } catch (e) {
        debugPrint("Erreur TikMate: $e");
      }
    }

    // Utilisation de l'API Cobalt V10 avec un fallback public
    try {
      final res = await Dio().post(
        "https://api.cobalt.tools/",
        data: {"url": cleanUrl},
        options: Options(headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
        })
      );
      
      if (res.data != null && res.data['url'] != null) return res.data['url'];
    } catch (e) {
      debugPrint("Erreur Cobalt principal: $e");
      // Fallback sur une instance publique
      try {
         final resFallback = await Dio().post(
           "https://cobalt-api.pewpew.nyc/",
           data: {"url": cleanUrl},
           options: Options(headers: {
             "Accept": "application/json",
             "Content-Type": "application/json",
           })
         );
         if (resFallback.data != null && resFallback.data['url'] != null) return resFallback.data['url'];
      } catch (_) {}
      
      try {
         final resFallback2 = await Dio().post(
           "https://cobalt.qck.ie/",
           data: {"url": cleanUrl},
           options: Options(headers: {
             "Accept": "application/json",
             "Content-Type": "application/json",
           })
         );
         if (resFallback2.data != null && resFallback2.data['url'] != null) return resFallback2.data['url'];
      } catch (_) {}
      
      if (cleanUrl.contains('instagram')) {
         // Utilisation d'API publiques directes pour Instagram (sans WebView)
         try {
           final formData = FormData.fromMap({"url": cleanUrl, "action": "post"});
           final res = await Dio().post(
             "https://snapinsta.app/action.php",
             data: formData,
             options: Options(headers: {
               "Origin": "https://snapinsta.app",
               "Referer": "https://snapinsta.app/",
               "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64 AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
             })
           );
           
           if (res.data != null && res.data is String) {
             // Extraction du lien MP4 avec Regex
             final RegExp regExp = RegExp(r'href=\\"(https:\/\/[^"]+\.mp4.*?)\\"');
             final match = regExp.firstMatch(res.data);
             if (match != null) {
               final String link = match.group(1)!.replaceAll(r'\\&', '&').replaceAll(r'\/', '/');
               return link;
             }
           }
         } catch (e) {
           debugPrint("Erreur SnapInsta HTTP: $e");
         }

         try {
           // Fallback 2: IgDownloader
           final formData = FormData.fromMap({"q": cleanUrl, "t": "media", "lang": "en"});
           final res = await Dio().post(
             "https://v3.igdownloader.net/api/ajaxSearch",
             data: formData,
             options: Options(headers: {
               "Origin": "https://igdownloader.net",
               "Referer": "https://igdownloader.net/",
               "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
             })
           );
           
           if (res.data != null && res.data['data'] != null) {
             final String html = res.data['data'];
             final RegExp regExp = RegExp(r'href="(https:\/\/[^"]+\.mp4.*?)"');
             final match = regExp.firstMatch(html);
             if (match != null) {
               return match.group(1)!.replaceAll('&amp;', '&');
             }
           }
         } catch (e) {
           debugPrint("Erreur IGDownloader HTTP: $e");
         }

         throw Exception("Le téléchargement de ce lien Instagram a échoué (Serveurs bloqués). Veuillez utiliser YouTube.");
      }
    }
    return null;
  }
}