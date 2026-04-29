import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:dio/dio.dart';

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

  @override
  void initState() {
    super.initState();
    _initApp();
    _player.setVolume(volume);

    // ÉCOUTE DES BOUTONS AIRPLAY / VERROUILLAGE
    _player.currentIndexStream.listen((index) {
      if (_isSwitchingTrack) return; 
      if (index == 0) {
        _isSwitchingTrack = true;
        _playPrevious();
      } else if (index == 2) {
        _isSwitchingTrack = true;
        _playNext();
      }
    });

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (loopMode == LoopModeState.autoplay) {
          if (!_isSwitchingTrack) {
            _isSwitchingTrack = true;
            _playNext();
          }
        }
      }
    });

    _player.playbackEventStream.listen((event) {}, onError: (Object e, StackTrace st) {});
  }

  Future<void> _initApp() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'luhaidan.db');
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

  // Permet de mettre à jour les vieilles miniatures internet vers du hors-ligne
  void _downloadThumbnailOffline(Map<String, dynamic> rec) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final thumbFile = File(p.join(dir.path, "thumb_${rec['id']}.jpg"));
      if (!await thumbFile.exists()) {
         await Dio().download(rec['thumbnail'], thumbFile.path);
      }
      await _db?.update('recitations', {'thumbnail': thumbFile.path}, where: 'id = ?', whereArgs: [rec['id']]);
      if (mounted) setState(() => rec['thumbnail'] = thumbFile.path);
    } catch (_) {}
  }

  // Le vrai téléchargement silencieux pour la prochaine fois
  void _downloadYoutubeInBackground(String cleanUrl, File localFile) async {
    var yt = YoutubeExplode();
    try {
      var manifest = await yt.videos.streamsClient.getManifest(cleanUrl);
      var audioStream = manifest.audioOnly.where((s) => s.container.name == 'mp4').withHighestBitrate();
      var stream = yt.videos.streamsClient.get(audioStream);
      
      final tempFile = File("${localFile.path}.tmp");
      var fileStream = tempFile.openWrite();
      await stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();
      
      if (await tempFile.length() > 0) {
        await tempFile.rename(localFile.path);
      }
    } catch (e) {
      debugPrint("Erreur background: $e");
    } finally {
      yt.close();
    }
  }

  MediaItem _createMediaItem(Map<String, dynamic> r) {
    Duration? exactDur;
    if (r['duration'] != null && r['duration'].toString().contains(':')) {
      final parts = r['duration'].toString().split(':');
      if (parts.length == 2) exactDur = Duration(minutes: int.parse(parts[0]), seconds: int.parse(parts[1]));
    }
    Uri? artUri;
    if (r['thumbnail'] != null && r['thumbnail'].toString().isNotEmpty) {
      artUri = r['thumbnail'].toString().startsWith('http') ? Uri.parse(r['thumbnail']) : Uri.file(r['thumbnail']);
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

  Future<void> _play(Map<String, dynamic> rec) async {
    _isSwitchingTrack = true;
    setState(() => currentRecitation = rec);
    if (rec['fichier'] == null) {
      _isSwitchingTrack = false;
      return;
    }
    
    // Fix miniature hors-ligne rétroactif
    if (rec['thumbnail'] != null && rec['thumbnail'].toString().startsWith('http')) {
      _downloadThumbnailOffline(rec);
    }

    String path = rec['fichier'];
    final currentMediaItem = _createMediaItem(rec);
    Uri realUri;
    AudioSource currentAudioSource;

    try {
      if (path.contains('youtube.com') || path.contains('youtu.be') || path.contains('shorts')) {
        final cleanUrl = path.split('?').first;
        final dir = await getApplicationDocumentsDirectory();
        final fileName = "yt_${rec['id']}.mp4";
        final localFile = File(p.join(dir.path, fileName));

        if (await localFile.exists() && await localFile.length() > 0) {
          realUri = Uri.file(localFile.path);
          currentAudioSource = _buildSource(realUri, currentMediaItem);
        } else {
          // LECTURE INSTANTANÉE (Fix Erreur -1 + Vitesse)
          setState(() => _isDownloading = true); 
          var yt = YoutubeExplode();
          var manifest = await yt.videos.streamsClient.getManifest(cleanUrl);
          
          // Muxed stream est le plus apprécié par AVPlayer iOS
          var mp4Muxed = manifest.muxed.where((s) => s.container.name == 'mp4');
          var streamInfo = mp4Muxed.isNotEmpty ? mp4Muxed.withHighestBitrate() : manifest.audioOnly.where((s) => s.container.name == 'mp4').withHighestBitrate();
          
          realUri = streamInfo.url;
          currentAudioSource = _buildSource(realUri, currentMediaItem);
          
          _downloadYoutubeInBackground(cleanUrl, localFile);
          
          await _db?.update('recitations', {'fichier': fileName}, where: 'id = ?', whereArgs: [rec['id']]);
          yt.close();
          setState(() => _isDownloading = false);
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File(p.join(dir.path, path));
        if (await file.exists()) {
          realUri = Uri.file(file.path);
          currentAudioSource = _buildSource(realUri, currentMediaItem);
        } else {
          throw Exception("Fichier introuvable");
        }
      }

      // TRICK AIRPLAY : Construction de la fausse file d'attente à 3 pistes pour illuminer les boutons iOS !
      int currIdx = displayedRecitations.indexWhere((r) => r['id'] == rec['id']);
      int prevIdx = (currIdx - 1 + displayedRecitations.length) % displayedRecitations.length;
      int nextIdx = (currIdx + 1) % displayedRecitations.length;

      var playlist = ConcatenatingAudioSource(children: [
         _buildSource(realUri, _createMediaItem(displayedRecitations[prevIdx])), // Dummy 0
         currentAudioSource,                                                     // La Vraie 1
         _buildSource(realUri, _createMediaItem(displayedRecitations[nextIdx])), // Dummy 2
      ]);

      await _player.setAudioSource(playlist, initialIndex: 1);
      _player.play();

    } catch (e) {
      setState(() => _isDownloading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Erreur : $e"), backgroundColor: Colors.red));
    } finally {
      Future.delayed(const Duration(milliseconds: 300), () => _isSwitchingTrack = false);
    }
  }

  void _playNext() {
    if (displayedRecitations.isEmpty) return;
    int index = displayedRecitations.indexWhere((r) => r['id'] == currentRecitation?['id']);
    int nextIndex = (index + 1) % displayedRecitations.length;
    _play(displayedRecitations[nextIndex]);
  }

  void _playPrevious() {
    if (displayedRecitations.isEmpty) return;
    int index = displayedRecitations.indexWhere((r) => r['id'] == currentRecitation?['id']);
    int prevIndex = (index - 1 + displayedRecitations.length) % displayedRecitations.length;
    _play(displayedRecitations[prevIndex]);
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
      
      // On remet la boucle de la track à Off si on passe en mode "Autoplay / Off"
      if (loopMode != LoopModeState.one) _player.setLoopMode(LoopMode.off);
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  Widget _buildThumbnail(String? thumbPath) {
    if (thumbPath == null || thumbPath.isEmpty) {
      return Image.asset('assets/logo.jpg', width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.mic, size: 40));
    }
    if (thumbPath.startsWith('http')) {
      return Image.network(thumbPath, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.mic, size: 40));
    } else {
      return Image.file(File(thumbPath), width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.mic, size: 40));
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
                Text("${displayedRecitations.length} récitations", style: const TextStyle(color: Color(0xFF6A7A82), fontSize: 13)),
                if (selectedYearFilter != null)
                  Text(selectedYearFilter == -1 ? "Année inconnue" : "$selectedYearFilter H", style: const TextStyle(color: Color(0xFF7EB8C9), fontWeight: FontWeight.bold)),
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
                        child: _buildThumbnail(rec['thumbnail']),
                      ),
                      title: Text("${rec['sourate_num'].toString().padLeft(3, '0')} - ${rec['sourate_name']}"),
                      subtitle: Text("${rec['annee'] ?? '??'} H • Versets: ${rec['versets']}"),
                      trailing: Text(rec['duration'] ?? "--:--", style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                    child: const Icon(Icons.add, color: Colors.white, size: 30),
                  ),
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isDownloading) const Padding(padding: EdgeInsets.only(bottom: 8.0), child: LinearProgressIndicator(color: Color(0xFF7EB8C9))),
          Text("${currentRecitation!['sourate_num'].toString().padLeft(3, '0')} - ${currentRecitation!['sourate_name']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text("${currentRecitation!['annee'] ?? '??'} H • Versets: ${currentRecitation!['versets']}", style: const TextStyle(fontSize: 12, color: Color(0xFF6A7A82))),
          const SizedBox(height: 8),
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, snapshot) {
              final pos = snapshot.data ?? Duration.zero;
              final dur = _player.duration ?? Duration.zero;
              
              double maxDur = dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0;
              double sliderVal = _dragValue ?? pos.inSeconds.toDouble();
              if (sliderVal < 0) sliderVal = 0;
              if (sliderVal > maxDur) sliderVal = maxDur;

              String currentTimeText = _formatDuration(Duration(seconds: sliderVal.toInt()));

              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                    ),
                    child: Slider(
                      activeColor: const Color(0xFF7EB8C9),
                      inactiveColor: Colors.white24,
                      value: sliderVal,
                      max: maxDur,
                      onChanged: (v) {
                        setState(() {
                          _dragValue = v;
                        });
                      },
                      onChangeEnd: (v) {
                        _player.seek(Duration(seconds: v.toInt()));
                        setState(() {
                          _dragValue = null;
                        });
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                    children: [
                      Text(currentTimeText, style: const TextStyle(fontSize: 11, color: Colors.grey)), 
                      Text(_formatDuration(dur), style: const TextStyle(fontSize: 11, color: Colors.grey))
                    ]
                  ),
                ],
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(icon: Icon(loopMode == LoopModeState.off ? Icons.repeat : (loopMode == LoopModeState.autoplay ? Icons.repeat_on : Icons.repeat_one_on), color: loopMode == LoopModeState.off ? Colors.grey : const Color(0xFF7EB8C9)), onPressed: _toggleLoop),
              IconButton(icon: const Icon(Icons.skip_previous, size: 32), onPressed: _playPrevious),
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snapshot) {
                  final state = snapshot.data;
                  final processingState = state?.processingState;
                  final playing = state?.playing ?? false;

                  if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
                    return Container(margin: const EdgeInsets.symmetric(horizontal: 16), width: 48, height: 48, child: const CircularProgressIndicator(color: Color(0xFF7EB8C9)));
                  }
                  
                  bool showPlayIcon = !playing || processingState == ProcessingState.completed;

                  return IconButton(
                    iconSize: 64, 
                    icon: Icon(showPlayIcon ? Icons.play_circle : Icons.pause_circle, color: const Color(0xFF7EB8C9)), 
                    onPressed: () async {
                      if (showPlayIcon) {
                        if (processingState == ProcessingState.completed) {
                          await _player.seek(Duration.zero, index: 1); // Reste à l'index actuel
                        }
                        _player.play();
                      } else {
                        _player.pause();
                      }
                    }
                  );
                },
              ),
              IconButton(icon: const Icon(Icons.skip_next, size: 32), onPressed: _playNext),
              IconButton(icon: const Icon(Icons.stop, size: 28, color: Colors.grey), onPressed: () {
                _player.stop();
                _player.seek(Duration.zero, index: 1);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final Map<int, int?> yearMap = {};
    for (var r in allRecitations) {
      if (r['annee'] != null) yearMap[r['annee'] as int] = r['annee_g'] as int?;
    }
    final years = yearMap.keys.toList()..sort((a, b) => b.compareTo(a));

    return Drawer(
      backgroundColor: const Color(0xFF0A0A0A),
      child: ListView(
        children: [
          const DrawerHeader(child: Center(child: Text("FILTRER PAR ANNÉE", style: TextStyle(color: Color(0xFF7EB8C9), fontWeight: FontWeight.bold)))),
          ListTile(title: const Text("Toutes les récitations"), selected: selectedYearFilter == null, onTap: () { setState(() => selectedYearFilter = null); _applyFilters(); Navigator.pop(context); }),
          ListTile(title: const Text("Année inconnue"), selected: selectedYearFilter == -1, onTap: () { setState(() => selectedYearFilter = -1); _applyFilters(); Navigator.pop(context); }),
          const Divider(color: Colors.white24),
          ...years.map((y) {
            return ListTile(
              title: Text("$y H"),
              selected: selectedYearFilter == y,
              onTap: () { setState(() => selectedYearFilter = y); _applyFilters(); Navigator.pop(context); },
            );
          }),
        ],
      ),
    );
  }

  void _showOptions(Map<String, dynamic> rec) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Color(0xFF7EB8C9)),
            title: const Text("Modifier"),
            onTap: () { Navigator.pop(context); _showForm(rec: rec); },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text("Supprimer", style: TextStyle(color: Colors.red)),
            onTap: () async {
              await _db?.delete('recitations', where: 'id = ?', whereArgs: [rec['id']]);
              _fetch();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showForm({Map<String, dynamic>? rec}) {
    showDialog(context: context, builder: (context) => FormDialog(rec: rec, onSave: _fetch, db: _db));
  }
}

class FormDialog extends StatefulWidget {
  final Map<String, dynamic>? rec;
  final VoidCallback onSave;
  final Database? db;
  const FormDialog({super.key, this.rec, required this.onSave, this.db});
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
    if (widget.rec != null) {
      selectedNum = widget.rec!['sourate_num'];
      selectedName = widget.rec!['sourate_name'];
      isFull = widget.rec!['versets'] == "complet";
      isLocal = !(widget.rec!['fichier']?.toString().contains('youtu') ?? false);
    }
    
    _year = TextEditingController(text: widget.rec?['annee']?.toString() ?? "");
    _file = TextEditingController(text: (widget.rec != null && isLocal) ? widget.rec!['fichier'] : "");
    _ytUrl = TextEditingController(text: (widget.rec != null && !isLocal) ? widget.rec!['fichier'] : "");
    _vStart = TextEditingController();
    _vEnd = TextEditingController();
    
    if (!isFull) {
      List<String> parts = widget.rec!['versets'].split('-');
      if (parts.length == 2) { _vStart.text = parts[0]; _vEnd.text = parts[1]; }
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
              width: 280, label: const Text("Sourate"), enableSearch: true,
              dropdownMenuEntries: ALL_SURAHS.map((s) => DropdownMenuEntry(value: s, label: "${s['num']} - ${s['name']}")).toList(),
              onSelected: (s) { selectedNum = s?['num']; selectedName = s?['name']; },
            ),
            const SizedBox(height: 15),
            TextField(controller: _year, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Année (H ou G)")),
            const SizedBox(height: 15),
            const Text("Étendue :"),
            Row(children: [
              Radio(value: true, groupValue: isFull, onChanged: (v) => setState(() => isFull = v!)), const Text("Complet"),
              Radio(value: false, groupValue: isFull, onChanged: (v) => setState(() => isFull = v!)), const Text("Partiel"),
            ]),
            if (!isFull) Row(children: [
              Expanded(child: TextField(controller: _vStart, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Début"))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _vEnd, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Fin"))),
            ]),
            const SizedBox(height: 15),
            const Text("Source :"),
            Row(children: [
              Radio(value: true, groupValue: isLocal, onChanged: (v) => setState(() => isLocal = v!)), const Text("Local"),
              Radio(value: false, groupValue: isLocal, onChanged: (v) => setState(() => isLocal = v!)), const Text("YouTube"),
            ]),
            if (isLocal) Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)),
                icon: const Icon(Icons.folder_open), label: const Text("Parcourir l'iPhone..."),
                onPressed: () async {
                  try {
                    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.any); 
                    if (result != null) {
                      final file = result.files.single;
                      final dir = await getApplicationDocumentsDirectory();
                      await File(file.path!).copy(p.join(dir.path, file.name));
                      setState(() => _file.text = file.name);
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Erreur fichiers : $e"), backgroundColor: Colors.red));
                  }
                }
              ),
              if (_file.text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8.0), child: Text("🎵 Fichier sélectionné : \n${_file.text}", style: const TextStyle(color: Color(0xFF7EB8C9), fontSize: 13))),
            ])
            else TextField(controller: _ytUrl, decoration: const InputDecoration(labelText: "Lien YouTube ou Shorts")),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A8FA3)),
          onPressed: () async {
            if (selectedNum == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Vous devez sélectionner une sourate"), backgroundColor: Colors.red));
              return;
            }

            try {
              String thumb = widget.rec?['thumbnail'] ?? "";
              String dur = widget.rec?['duration'] ?? "";

              if (!isLocal && _ytUrl.text.isNotEmpty && (widget.rec == null || _ytUrl.text != widget.rec?['fichier'])) {
                var yt = YoutubeExplode();
                try {
                  var video = await yt.videos.get(_ytUrl.text.split('?').first);
                  String remoteThumb = video.thumbnails.highResUrl;
                  if (remoteThumb.isEmpty) {
                    remoteThumb = video.thumbnails.standardResUrl;
                  }
                  
                  dur = "${video.duration?.inMinutes}:${((video.duration?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')}";
                  
                  try {
                    final dir = await getApplicationDocumentsDirectory();
                    final thumbFile = File(p.join(dir.path, "thumb_yt_${video.id}.jpg"));
                    await Dio().download(remoteThumb, thumbFile.path);
                    thumb = thumbFile.path; 
                  } catch (e) {
                    thumb = remoteThumb; 
                  }
                  
                } catch (e) {
                  debugPrint("Erreur YouTube: $e");
                } finally {
                  yt.close();
                }
              } 
              else if (isLocal && _file.text.isNotEmpty && (widget.rec == null || _file.text != widget.rec?['fichier'])) {
                final dir = await getApplicationDocumentsDirectory();
                final localFilePath = p.join(dir.path, _file.text);
                
                try {
                  final player = AudioPlayer();
                  final d = await player.setFilePath(localFilePath);
                  if (d != null) dur = "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
                  await player.dispose();
                } catch (e) {
                  debugPrint("Impossible de lire la durée locale: $e");
                }

                try {
                  final metadata = await MetadataRetriever.fromFile(File(localFilePath));
                  if (metadata.albumArt != null) {
                    final artFile = File(p.join(dir.path, "thumb_${_file.text}.jpg"));
                    await artFile.writeAsBytes(metadata.albumArt!);
                    thumb = artFile.path;
                  }
                } catch (e) {
                  debugPrint("Pas d'image trouvée: $e");
                }
              }

              String versets = isFull ? "complet" : "${_vStart.text}-${_vEnd.text}";
              final data = {
                "sourate_num": selectedNum,
                "sourate_name": selectedName,
                "annee": int.tryParse(_year.text),
                "fichier": isLocal ? _file.text : _ytUrl.text,
                "versets": versets,
                "thumbnail": thumb,
                "duration": dur,
              };

              if (widget.rec == null) {
                await widget.db?.insert('recitations', data);
              } else {
                await widget.db?.update('recitations', data, where: 'id = ?', whereArgs: [widget.rec!['id']]);
              }
              
              widget.onSave();
              if (mounted) Navigator.pop(context);

            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Erreur de sauvegarde : $e"), backgroundColor: Colors.red));
            }
          },
          child: const Text("Enregistrer", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}