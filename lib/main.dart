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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.muhammad.luhaidan.app',
    androidNotificationChannelName: 'Quran Library',
    androidNotificationOngoing: true,
  );
  runApp(const QuranLibraryApp());
}

class ProxyServer {
  static HttpServer? _server;
  static int? port;
  
  static Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = _server!.port;
    _server!.listen((HttpRequest request) async {
      try {
        final ytUrl = request.uri.queryParameters['url'];
        if (ytUrl != null) {
          if (ytUrl.contains('instagram') || ytUrl.contains('tiktok')) {
            // L'APPEL AU NOUVEAU RÉSEAU DE SERVEURS
            final streamUrl = await MediaExtractor.getDownloadUrl(ytUrl);
            if (streamUrl != null) {
              request.response.redirect(Uri.parse(streamUrl), status: HttpStatus.movedTemporarily);
            } else {
              request.response.statusCode = 404;
            }
            return;
          } else {
            var yt = YoutubeExplode();
            var manifest = await yt.videos.streamsClient.getManifest(ytUrl);
            var streamInfo = manifest.muxed.withHighestBitrate();
            yt.close();
            request.response.redirect(streamInfo.url, status: HttpStatus.movedTemporarily);
            return;
          }
        }
      } catch (_) {
        request.response.statusCode = 500;
      } finally {
        await request.response.close();
      }
    });
  }

  static String getProxyUrl(String originalUrl) => 'http://127.0.0.1:$port/?url=${Uri.encodeComponent(originalUrl)}';
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

class _LibraryScreenState extends State<LibraryScreen> {
  List<dynamic> allRecitations = [];
  List<dynamic> displayedRecitations = [];
  final AudioPlayer _player = AudioPlayer();
  Map<String, dynamic>? currentRecitation;
  
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

  @override
  void initState() {
    super.initState();
    _initApp();
    _player.setVolume(volume);
    _player.setLoopMode(LoopMode.off); // FIX : On force la boucle native à OFF

    // 1. SURVEILLANCE SIMPLE (Ne coupe plus l'audio !)
    _player.positionStream.listen((pos) {
      _lastPos = pos.inMilliseconds;
      _lastDuration = _player.duration?.inMilliseconds ?? 0;
    });

    // 2. FIX : GESTION DU TOUT DERNIER FICHIER DE LA PLAYLIST
    _player.playerStateStream.listen((state) async {
      if (state.processingState == ProcessingState.completed) {
        if (loopMode == LoopModeState.off) {
          await _player.pause();
          await _player.seek(Duration.zero, index: _playingIndex); // Reste sur la piste à 0
        } else if (loopMode == LoopModeState.one) {
          await _player.pause();
          await Future.delayed(const Duration(milliseconds: 200)); // Délai doux
          await _player.seek(Duration.zero, index: _playingIndex);
          _player.play();
        }
      }
    });

    // 3. FIX : GESTION DES SAUTS (La piste actuelle se termine)
    _player.currentIndexStream.listen((index) async {
      if (index == null || _isSwitchingTrack) return;
      
      // Si l'audio a naturellement basculé sur la piste suivante
      if (_playingIndex != null && index == _playingIndex! + 1) {
         if (loopMode == LoopModeState.off) {
            _isSwitchingTrack = true;
            await _player.pause();
            await _player.seek(Duration.zero, index: _playingIndex); // REVIENT A 0 SUR L'ACTUELLE
            _isSwitchingTrack = false;
            return; 
         } else if (loopMode == LoopModeState.one) {
            _isSwitchingTrack = true;
            await _player.pause();
            await Future.delayed(const Duration(milliseconds: 200)); // DELAI DE 200ms AVANT BOUCLE
            await _player.seek(Duration.zero, index: _playingIndex); // REVIENT A 0 SUR L'ACTUELLE
            _player.play();
            _isSwitchingTrack = false;
            return; 
         }
      }
      
      // Sinon (Lecture automatique classique, ou bouton manuel pressé)
      _playingIndex = index;
      if (index < displayedRecitations.length) {
         setState(() => currentRecitation = displayedRecitations[index]);
      }
    });
  }

  Future<void> _initApp() async {
    final dir = await getApplicationDocumentsDirectory();
    _appDirPath = dir.path;
    await ProxyServer.start(); 

    final path = p.join(dir.path, 'luhaidan.db');
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
    await _cleanupOrphans(); // L'aspirateur automatique est lancé ici !
  }

  // --- L'ASPIRATEUR AUTOMATIQUE ---
  Future<void> _cleanupOrphans() async {
    if (_appDirPath == null) return;
    final dir = Directory(_appDirPath!);
    final files = dir.listSync();
    
    // On dresse la liste des fichiers officiellement enregistrés dans l'application
    Set<String> validFiles = {'luhaidan.db', 'luhaidan.db-wal', 'luhaidan.db-shm'};
    for (var rec in allRecitations) {
      if (rec['fichier'] != null) validFiles.add(p.basename(rec['fichier']));
      if (rec['thumbnail'] != null) validFiles.add(p.basename(rec['thumbnail']));
      validFiles.add("yt_${rec['id']}.mp4");
      validFiles.add("thumb_yt_${rec['id']}.jpg");
    }
    
    // On détruit tout ce qui n'est pas sur la liste (Les .tmp, les vieilles vidéos, etc.)
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
    setState(() {
      allRecitations = res ?? [];
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      if (selectedYearFilter == null) {
        displayedRecitations = allRecitations;
      } else if (selectedYearFilter == -1) {
        displayedRecitations = allRecitations.where((r) => r['annee'] == null).toList();
      } else {
        displayedRecitations = allRecitations.where((r) => r['annee'] == selectedYearFilter).toList();
      }
    });
    _updateFullPlaylist(); 
  }

  Future<void> _updateFullPlaylist() async {
    List<AudioSource> sources = [];
    for (var rec in displayedRecitations) {
      String path = rec['fichier'] ?? "";
      Uri uri;
      if (path.contains('youtube.com') || path.contains('youtu.be') || path.contains('shorts') || path.contains('instagram') || path.contains('tiktok')) {
        final localFile = File(p.join(_appDirPath!, "yt_${rec['id']}.mp4"));
        if (await localFile.exists() && await localFile.length() > 100000) { 
          uri = Uri.file(localFile.path);
        } else {
          uri = Uri.parse(ProxyServer.getProxyUrl(path)); 
        }
      } else {
        uri = Uri.file(_resolvePath(path));
      }
      
      final baseSource = AudioSource.uri(uri, tag: _createMediaItem(rec));
      
      if (rec['duration'] != null && rec['duration'].toString().contains(':')) {
         try {
           final parts = rec['duration'].toString().split(':');
           if (parts.length == 2) {
             final dur = Duration(minutes: int.parse(parts[0]), seconds: int.parse(parts[1]));
             sources.add(ClippingAudioSource(child: baseSource, end: dur, tag: _createMediaItem(rec)));
             continue;
           }
         } catch (_) {}
      }
      sources.add(baseSource);
    }

    if (sources.isNotEmpty) {
      // FIX : Mémoriser la lecture en cours pour ne pas repartir à zéro !
      int? savedIndex = _playingIndex;
      Duration savedPos = _player.position;
      bool wasPlaying = _player.playing;

      final newPlaylist = ConcatenatingAudioSource(children: sources);

      if (savedIndex != null && savedIndex < sources.length) {
        // On insère la nouvelle playlist mais on force le lecteur à rester sur la piste actuelle
        await _player.setAudioSource(newPlaylist, initialIndex: savedIndex, initialPosition: savedPos);
        if (wasPlaying) _player.play();
      } else {
        await _player.setAudioSource(newPlaylist);
      }
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
      id: r['id'].toString(),
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
        if (extracted == null) throw Exception("Tous les serveurs ont rejeté le lien.");
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
      
      int lastUpdateValue = 0;
      
      await Dio().download(
        downloadUrl,
        tempFile.path,
        // FIX 0% : On force les serveurs d'Instagram/TikTok à accepter le téléchargement
        options: Options(headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Referer': 'https://cobalt.tools/'
        }),
        onReceiveProgress: (received, total) {
          if (total != -1) {
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
      
      if (await tempFile.exists() && await tempFile.length() > 100000) {
        if (await localFile.exists()) await localFile.delete(); 
        await tempFile.rename(localFile.path); 
        
        if (cleanUrl.contains('instagram') || cleanUrl.contains('tiktok')) {
          try {
             final metadata = await MetadataRetriever.fromFile(localFile);
             String newDur = "--:--";
             if (metadata.trackDuration != null) {
                final d = Duration(milliseconds: metadata.trackDuration!);
                newDur = "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
             }
             
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
                _fetch(); 
             }
          } catch (e) {
             debugPrint("Erreur métadonnées: $e");
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Vidéo prête pour le hors-ligne !", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green, duration: Duration(seconds: 3))
          );
        }
        _updateFullPlaylist(); 
      } else {
        throw Exception("Fichier corrompu ou illisible.");
      }
    } catch (e) {
      debugPrint("Erreur téléchargement: $e");
      if (await tempFile.exists()) {
         try { await tempFile.delete(); } catch (_) {}
      }
      
      // FIX PISTE FANTÔME : Si le téléchargement foire, on supprime la ligne vide de la BDD !
      final localAudioFile = File(p.join(_appDirPath!, "yt_$id.mp4"));
      if (!await localAudioFile.exists()) {
          await _db?.delete('recitations', where: 'id = ?', whereArgs: [id]);
          _fetch();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Impossible d'extraire la vidéo (Privée ou indisponible)."), backgroundColor: Colors.red)
        );
      }
    } finally {
      yt?.close();
      if (mounted) setState(() => _activeDownloads.remove(id)); 
    }
  }

  Future<void> _play(Map<String, dynamic> rec) async {
    int index = displayedRecitations.indexWhere((r) => r['id'] == rec['id']);
    
    if (index != -1) {
      _isSwitchingTrack = true;
      
      setState(() {
        currentRecitation = rec;
        _playingIndex = index;
      });

      try {
        await _player.seek(Duration.zero, index: index);
        _player.play();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ Erreur de lecture : $e"), backgroundColor: Colors.red)
          );
        }
      } finally {
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
      } else if (loopMode == LoopModeState.autoplay) {
        loopMode = LoopModeState.one;
      } else {
        loopMode = LoopModeState.off;
      }
      _player.setLoopMode(LoopMode.off); // FIX : Toujours désactivé nativement
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
    _showLoading("Création de la sauvegarde en cours...\nL'application va se figer quelques secondes, ne la fermez pas.");
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // FIX SQLITE : On ferme la BDD pour forcer l'écriture du cache (WAL)
      await _db?.close(); 
      
      final dir = await getApplicationDocumentsDirectory();
      final encoder = ZipFileEncoder();
      final zipPath = p.join(dir.path, "QuranLibrary_Backup.zip");
      
      encoder.create(zipPath);
      
      final dbFile = File(p.join(dir.path, 'luhaidan.db'));
      if (await dbFile.exists()) {
        encoder.addFile(dbFile, 'luhaidan.db'); 
      }
      
      final files = dir.listSync();
      for (var f in files) {
        if (f is File && (f.path.endsWith('.mp4') || f.path.endsWith('.jpg'))) {
          encoder.addFile(f, p.basename(f.path)); 
        }
      }
      encoder.close();

      // On rouvre la BDD pour pouvoir continuer d'utiliser l'app
      await _initApp(); 

      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Fichier QuranLibrary_Backup.zip créé dans l'app Fichiers !"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Erreur d'exportation : $e"), backgroundColor: Colors.red));
      await _initApp();
    }
  }

  Future<void> _importLibrary() async {
    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
    if (result == null) return;

    _showLoading("Restauration en cours...\nL'application va se figer quelques secondes, ne la fermez pas.");
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // 1. Dézipper dans un dossier temporaire sécurisé
      final zipFile = File(result.files.single.path!);
      final dir = await getApplicationDocumentsDirectory();
      
      final tempDir = Directory(p.join(dir.path, 'temp_restore'));
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      await tempDir.create();

      extractFileToDisk(zipFile.path, tempDir.path);

      // 2. MODE ASPIRATEUR : Chercher la base de données partout dans les sous-dossiers
      File? extractedDb;
      List<File> extractedMedia = [];
      
      final entities = tempDir.listSync(recursive: true);
      for (var entity in entities) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (name == 'luhaidan.db') {
            extractedDb = entity;
          } else if (name.endsWith('.mp4') || name.endsWith('.jpg')) {
            extractedMedia.add(entity);
          }
        }
      }

      // Si le fichier zip ne contient pas de base de données, on annule tout
      if (extractedDb == null) {
        throw Exception("Fichier luhaidan.db introuvable dans la sauvegarde.");
      }

      // 3. Stopper l'audio et détruire la base de données actuelle (et son cache WAL)
      await _player.stop();
      await _db?.close();
      _db = null; 
      
      final realDbPath = p.join(dir.path, 'luhaidan.db');
      await deleteDatabase(realDbPath); // Supprime la DB et le cache
      
      // 4. Placer la nouvelle base de données au bon endroit
      await extractedDb.copy(realDbPath);

      // 5. Restaurer les fichiers médias à la racine
      for (var mediaFile in extractedMedia) {
        final newPath = p.join(dir.path, p.basename(mediaFile.path));
        if (await File(newPath).exists()) {
           await File(newPath).delete(); // Écrase si le fichier existe déjà
        }
        await mediaFile.copy(newPath);
      }

      // 6. Nettoyer le dossier temporaire
      await tempDir.delete(recursive: true);

      // 7. Relancer l'application pour afficher les données
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
                        _player.seek(Duration(seconds: v.toInt()), index: _playingIndex);
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
                    onDownload: (id, url, file) => _startDownload(id, url, file),
                  )
                )
              );
            },
          ),
          
          const Divider(color: Colors.white24),
          
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
      )
    );
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
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _controller.runJavaScript("""
              const observer = new MutationObserver(() => {
                document.querySelectorAll('video').forEach(v => {
                  if (!v.hasAttribute('playsinline')) {
                    v.setAttribute('playsinline', 'true');
                    v.removeAttribute('autoplay');
                  }
                  if (v.webkitEnterInlineFullScreen) {
                    v.webkitExitFullscreen();
                  }
                });
                document.querySelectorAll('ytm-inline-preview').forEach(e => e.remove());
              });
              observer.observe(document.body, { childList: true, subtree: true });
            """);
          },
          onUrlChange: (UrlChange change) {
            if (mounted) {
              setState(() {
                _currentUrl = change.url ?? "";
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          }
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
    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("YouTube", style: TextStyle(color: Color(0xFF7EB8C9))),
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
        body: WebViewWidget(controller: _controller),
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
                label: const Text("Télécharger la vidéo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
  
  const FormDialog({super.key, this.rec, required this.onSave, this.db, this.initialUrl, this.onDownload});
  
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A8FA3)),
          onPressed: () async {
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

// --- NOUVEL EXTRACTEUR MULTI-SERVEURS ---
class MediaExtractor {
  static Future<String?> getDownloadUrl(String targetUrl) async {
    // Liste de serveurs miroirs Cobalt communautaires (sans sécurité stricte)
    final instances = [
      'https://cobalt-api.ayo.tf/',
      'https://coapi.kelig.me/api/json',
      'https://ca.haloz.at/api/json',
      'https://cblt.fariz.dev/api/json',
      'https://api.cobalt.tacohitbox.com/api/json',
    ];
    
    for (String instance in instances) {
      try {
        final response = await Dio().post(
          instance,
          options: Options(
            headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
            validateStatus: (status) => status != null && status < 500, // Ne crash pas Dio sur une erreur 400
          ),
          data: jsonEncode({"url": targetUrl})
        );
        
        if (response.statusCode == 200 && response.data != null && response.data['url'] != null) {
          return response.data['url'];
        }
      } catch (e) {
        continue; // On passe au serveur suivant silencieusement
      }
    }
    return null; // Si absolument tous les serveurs sont hors-ligne
  }
}