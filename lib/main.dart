import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.muhammad.luhaidan.app',
    androidNotificationChannelName: 'Bibliothèque Luhaidan',
    androidNotificationOngoing: true,
  );
  runApp(const LuhaidanApp());
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

class LuhaidanApp extends StatelessWidget {
  const LuhaidanApp({super.key});

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
  
  int _lastPosition = 0; 
  int _lastDuration = 0; // Le radar mémorise la durée totale de la piste pour éviter les faux positifs

  @override
  void initState() {
    super.initState();
    _initApp();
    _player.setVolume(volume);

    // 1. Le radar enregistre l'avancée et la durée de la vraie piste
    _player.positionStream.listen((pos) {
      if (_player.currentIndex == 1 && pos.inMilliseconds > 0) {
        _lastPosition = pos.inMilliseconds;
        _lastDuration = _player.duration?.inMilliseconds ?? 0;
      }
    });

    // 2. Interception intelligente du changement d'index
    _player.currentIndexStream.listen((index) {
      if (_isSwitchingTrack || index == null || index == 1) return; 
      
      _isSwitchingTrack = true;
      _player.pause(); 
      
      // On vérifie si la piste s'est terminée naturellement (à moins d'une seconde de SA durée mémorisée)
      bool isNaturalEnd = (_lastPosition > 0 && _lastDuration > 0 && _lastPosition >= _lastDuration - 1000);

      if (index == 0) {
        _playPrevious();
      } else if (index == 2) {
        if (loopMode == LoopModeState.off && isNaturalEnd) {
          // Fin naturelle ET bouton gris -> On bloque l'enchaînement et on rembobine
          _player.seek(Duration.zero, index: 1);
          _isSwitchingTrack = false;
        } else {
          // Bouton bleu OU clic manuel de l'utilisateur -> On enchaîne !
          _playNext();
        }
      }
    });
  }

  Future<void> _initApp() async {
    final dir = await getApplicationDocumentsDirectory();
    _appDirPath = dir.path;

    final path = p.join(dir.path, 'luhaidan.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) => db.execute(
        'CREATE TABLE recitations(id INTEGER PRIMARY KEY AUTOINCREMENT, sourate_num INTEGER, sourate_name TEXT, annee INTEGER, fichier TEXT, versets TEXT, annee_g INTEGER, thumbnail TEXT, duration TEXT)'
      ),
      onUpgrade: (db, oldV, newV) {
        if (oldV < 2) {
          db.execute('ALTER TABLE recitations ADD COLUMN thumbnail TEXT');
          db.execute('ALTER TABLE recitations ADD COLUMN duration TEXT');
        }
      }
    );
    _fetch();
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
  }

  String _resolvePath(String pathStr) {
    if (pathStr.startsWith('http')) return pathStr;
    if (pathStr.startsWith('/')) return pathStr; 
    return _appDirPath != null ? p.join(_appDirPath!, pathStr) : pathStr;
  }

  MediaItem _createMediaItem(Map<String, dynamic> r) {
    Duration? exactDur;
    if (r['duration'] != null && r['duration'].toString().contains(':')) {
      final parts = r['duration'].toString().split(':');
      if (parts.length == 2) exactDur = Duration(minutes: int.parse(parts[0]), seconds: int.parse(parts[1]));
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
      artist: "Muhammad Al-Luhaidan",
      artUri: artUri,
      duration: exactDur,
    );
  }

  AudioSource _buildSource(Uri uri, MediaItem mediaItem) {
    final base = AudioSource.uri(uri, tag: mediaItem);
    if (mediaItem.duration != null && mediaItem.duration!.inSeconds > 0) {
      return ClippingAudioSource(child: base, end: mediaItem.duration, tag: mediaItem);
    }
    return base;
  }

  // NOUVEAU : Le générateur de pistes fantômes compatibles avec iOS
  AudioSource _buildDummySource(Uri uri, MediaItem mediaItem) {
    return ClippingAudioSource(
      child: AudioSource.uri(uri, tag: mediaItem), 
      start: Duration.zero, 
      end: const Duration(milliseconds: 100), 
      tag: mediaItem
    );
  }

  Future<void> _startDownload(int id, String cleanUrl, File localFile) async {
    if (_activeDownloads.containsKey(id)) return; 
    
    setState(() => _activeDownloads[id] = 0.0);
    var yt = YoutubeExplode();
    
    try {
      var manifest = await yt.videos.streamsClient.getManifest(cleanUrl);
      var mp4Muxed = manifest.muxed.where((s) => s.container.name == 'mp4');
      var streamInfo = mp4Muxed.isNotEmpty 
          ? mp4Muxed.withHighestBitrate() 
          : manifest.audioOnly.where((s) => s.container.name == 'mp4').withHighestBitrate();
      
      final tempFile = File("${localFile.path}.tmp");
      int lastUpdateValue = 0;
      
      await Dio().download(
        streamInfo.url.toString(),
        tempFile.path,
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
      
      if (await tempFile.exists() && await tempFile.length() > 500000) {
        if (await localFile.exists()) await localFile.delete(); 
        await tempFile.rename(localFile.path); 
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Vidéo téléchargée et prête pour le hors-ligne !", style: TextStyle(color: Colors.white)), 
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            )
          );
        }
      } else {
        throw Exception("Fichier corrompu.");
      }
    } catch (e) {
      debugPrint("Erreur téléchargement: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Échec du téléchargement : $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      yt.close();
      if (mounted) setState(() => _activeDownloads.remove(id)); 
    }
  }

  Future<void> _play(Map<String, dynamic> rec) async {
    _isSwitchingTrack = true;
    _lastPosition = 0; 
    _lastDuration = 0; // Remise à zéro du radar
    await _player.stop(); 
    
    setState(() {
      currentRecitation = rec;
      _isDownloading = true; 
    });

    if (rec['fichier'] == null) {
      _isSwitchingTrack = false;
      setState(() => _isDownloading = false);
      return;
    }

    String path = rec['fichier'];
    final currentMediaItem = _createMediaItem(rec);
    AudioSource finalSource;
    Uri realUri;

    try {
      if (path.contains('youtube.com') || path.contains('youtu.be') || path.contains('shorts')) {
        final cleanUrl = path; 
        final dir = await getApplicationDocumentsDirectory();
        final localFile = File(p.join(dir.path, "yt_${rec['id']}.mp4"));

        if (await localFile.exists() && await localFile.length() > 500000) {
           realUri = Uri.file(localFile.path);
           finalSource = _buildSource(realUri, currentMediaItem);
        } else {
          var yt = YoutubeExplode();
          try {
            var manifest = await yt.videos.streamsClient.getManifest(cleanUrl).timeout(const Duration(seconds: 5));
            var streamInfo = manifest.muxed.withHighestBitrate();
            realUri = streamInfo.url;
            finalSource = _buildSource(realUri, currentMediaItem);
            
            _startDownload(rec['id'], cleanUrl, localFile); 
          } catch (e) {
            throw Exception("Erreur de connexion à YouTube ($e)");
          } finally {
            yt.close();
          }
        }
      } else {
        final file = File(_resolvePath(path));
        if (await file.exists()) {
          realUri = Uri.file(file.path);
          finalSource = _buildSource(realUri, currentMediaItem);
        } else {
          throw Exception("Fichier local introuvable");
        }
      }

      int currIdx = displayedRecitations.indexWhere((r) => r['id'] == rec['id']);
      int prevIdx = (currIdx - 1 + displayedRecitations.length) % displayedRecitations.length;
      int nextIdx = (currIdx + 1) % displayedRecitations.length;

      var playlist = ConcatenatingAudioSource(children: [
         _buildDummySource(realUri, _createMediaItem(displayedRecitations[prevIdx])),
         finalSource,                                                     
         _buildDummySource(realUri, _createMediaItem(displayedRecitations[nextIdx])),
      ]);

      await _player.setAudioSource(playlist, initialIndex: 1);
      _player.play();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Erreur : $e"), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => _isDownloading = false);
      Future.delayed(const Duration(milliseconds: 300), () => _isSwitchingTrack = false);
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
        _player.setLoopMode(LoopMode.one);
      } else {
        loopMode = LoopModeState.off;
        _player.setLoopMode(LoopMode.off);
      }
      if (loopMode != LoopModeState.one) _player.setLoopMode(LoopMode.off);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("مكتبة محمد اللحيدان", style: TextStyle(color: Color(0xFF7EB8C9))),
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
                      subtitle: Text("${rec['annee'] ?? '??'} H • Versets: ${rec['versets']}"),
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
          if (_isDownloading) 
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0), 
              child: LinearProgressIndicator(color: Color(0xFF7EB8C9))
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
                      "${currentRecitation!['annee'] ?? '??'} H • Versets: ${currentRecitation!['versets']}", 
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
                      if (_timerEndTime != null)
                        Text(
                          _formatCountdown(_timerEndTime!.difference(DateTime.now())),
                          style: const TextStyle(color: Color(0xFF7EB8C9), fontSize: 11, fontWeight: FontWeight.bold)
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
                        _player.seek(Duration(seconds: v.toInt()), index: 1);
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
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8), 
                      width: 52, 
                      height: 52, 
                      child: const CircularProgressIndicator(color: Color(0xFF7EB8C9))
                    );
                  }
                  
                  bool showPlayIcon = !playing || state?.processingState == ProcessingState.completed;
                  return IconButton(
                    iconSize: 60, 
                    icon: Icon(showPlayIcon ? Icons.play_circle : Icons.pause_circle, color: const Color(0xFF7EB8C9)), 
                    onPressed: () async {
                      if (showPlayIcon) {
                        if (state?.processingState == ProcessingState.completed) {
                          await _player.seek(Duration.zero, index: 1);
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
                  _player.stop();
                  _player.seek(Duration.zero, index: 1);
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
              child: Text("MAMK", style: TextStyle(color: Color(0xFF7EB8C9), fontSize: 24, fontWeight: FontWeight.bold))
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
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Color(0xFF7EB8C9)), 
            title: const Text("Modifier"), 
            onTap: () { 
              Navigator.pop(context); 
              _showForm(rec: rec); 
            }
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red), 
            title: const Text("Supprimer"), 
            onTap: () async {
              if (currentRecitation?['id'] == rec['id']) {
                await _player.stop();
              }
              await _db?.delete('recitations', where: 'id = ?', whereArgs: [rec['id']]);
              try {
                final dir = await getApplicationDocumentsDirectory();
                final f = File(p.join(dir.path, "yt_${rec['id']}.mp4"));
                if (await f.exists()) await f.delete();
              } catch (_) {}
              
              _fetch(); 
              if (mounted) Navigator.pop(context);
            }
          ),
        ]
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
      ..loadRequest(Uri.parse('https://m.youtube.com/results?search_query=muhammad+al+luhaidan'));
  }

  bool get _isVideoPage {
    return _currentUrl.contains('watch?v=') || _currentUrl.contains('youtu.be') || _currentUrl.contains('/shorts/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Naviguer sur YouTube", style: TextStyle(color: Color(0xFF7EB8C9))),
        backgroundColor: const Color(0xFF111111),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
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
  late TextEditingController _year, _file, _ytUrl, _vStart, _vEnd;
  bool isLocal = true; 
  bool isFull = true;

  @override
  void initState() {
    super.initState();
    
    bool defaultIsLocal = true;
    if (widget.rec != null) {
      defaultIsLocal = !(widget.rec!['fichier']?.toString().contains('youtu') ?? false);
    } else if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      defaultIsLocal = false; 
    }
    isLocal = defaultIsLocal;
    
    if (widget.rec != null) {
      selectedNum = widget.rec!['sourate_num'];
      selectedName = widget.rec!['sourate_name'];
      isFull = widget.rec!['versets'] == "complet";
    }
    
    _year = TextEditingController(text: widget.rec?['annee']?.toString() ?? "");
    _file = TextEditingController(text: (widget.rec != null && isLocal) ? widget.rec!['fichier'] : "");
    _ytUrl = TextEditingController(text: widget.initialUrl ?? ((widget.rec != null && !isLocal) ? widget.rec!['fichier'] : ""));
    
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
              controller: _year, 
              keyboardType: TextInputType.number, 
              decoration: const InputDecoration(labelText: "Année (H)")
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
            const SizedBox(height: 10),
            Row(
              children: [
                Radio(value: true, groupValue: isLocal, onChanged: (v) => setState(() => isLocal = v!)), 
                const Text("Local"),
                Radio(value: false, groupValue: isLocal, onChanged: (v) => setState(() => isLocal = v!)), 
                const Text("YouTube"),
              ]
            ),
            const SizedBox(height: 10),
            if (isLocal) 
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
                child: const Text("Choisir fichier")
              )
            else 
              TextField(
                controller: _ytUrl, 
                decoration: const InputDecoration(labelText: "Lien YouTube")
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
              
              if (!isLocal && _ytUrl.text.isNotEmpty) {
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
              } else if (isLocal && _file.text.isNotEmpty) {
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
                "annee": int.tryParse(_year.text), 
                "fichier": isLocal ? _file.text : _ytUrl.text,
                "versets": isFull ? "complet" : "${_vStart.text}-${_vEnd.text}",
                "thumbnail": thumb, 
                "duration": dur,
              };
              
              int recordId = widget.rec == null ? await widget.db!.insert('recitations', data) : widget.rec!['id'];
              if (widget.rec != null) await widget.db!.update('recitations', data, where: 'id = ?', whereArgs: [recordId]);
              
              if (!isLocal && _ytUrl.text.isNotEmpty) {
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