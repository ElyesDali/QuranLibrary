import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:just_audio/just_audio.dart';
import 'package:file_selector/file_selector.dart';

void main() => runApp(const LuhaidanApp());

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

  @override
  void initState() {
    super.initState();
    _fetch();
    _player.setVolume(volume);
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (loopMode == LoopModeState.autoplay) _playNext();
      }
    });
  }

  Future<void> _fetch() async {
    try {
      final res = await http.get(Uri.parse('http://127.0.0.1:8000/recitations'));
      if (res.statusCode == 200) {
        setState(() {
          allRecitations = json.decode(res.body);
          _applyFilters();
        });
      }
    } catch (e) {
      debugPrint("Erreur API: $e");
    }
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

  void _play(Map<String, dynamic> rec) async {
    setState(() => currentRecitation = rec);
    if (rec['fichier'] != null) {
      try {
        await _player.setUrl('http://127.0.0.1:8000/stream_file?path=${Uri.encodeComponent(rec['fichier'])}');
        _player.play();
      } catch (e) {
        debugPrint("Erreur lecture: $e");
      }
    }
  }

  void _playNext() {
    if (displayedRecitations.isEmpty || currentRecitation == null) return;
    int index = displayedRecitations.indexWhere((r) => r['id'] == currentRecitation!['id']);
    if (index != -1 && index < displayedRecitations.length - 1) {
      _play(displayedRecitations[index + 1]);
    }
  }

  void _playPrevious() {
    if (displayedRecitations.isEmpty || currentRecitation == null) return;
    int index = displayedRecitations.indexWhere((r) => r['id'] == currentRecitation!['id']);
    if (index > 0) {
      _play(displayedRecitations[index - 1]);
    }
  }

  void _toggleLoop() {
    setState(() {
      if (loopMode == LoopModeState.off) {
        loopMode = LoopModeState.autoplay;
        _player.setLoopMode(LoopMode.off);
      } else if (loopMode == LoopModeState.autoplay) {
        loopMode = LoopModeState.one;
        _player.setLoopMode(LoopMode.one);
      } else {
        loopMode = LoopModeState.off;
        _player.setLoopMode(LoopMode.off);
      }
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
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
                  style: const TextStyle(color: Color(0xFF6A7A82), fontSize: 13),
                ),
                if (selectedYearFilter != null)
                  Text(
                    selectedYearFilter == -1 ? "Année inconnue" : "$selectedYearFilter H",
                    style: const TextStyle(color: Color(0xFF7EB8C9), fontWeight: FontWeight.bold),
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
                    final yearH = rec['annee']?.toString() ?? "??";
                    final yearG = rec['annee_g']?.toString() ?? "??";
                    return ListTile(
                      selected: currentRecitation?['id'] == rec['id'],
                      title: Text("${rec['sourate_num'].toString().padLeft(3, '0')} - ${rec['sourate_name']}"),
                      subtitle: Text("$yearH H | $yearG G • Versets: ${rec['versets']}"),
                      onTap: () => _play(rec),
                      onLongPress: () => _showOptions(rec),
                    );
                  },
                ),
                Positioned(
                  bottom: 16,
                  right: 24,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: FloatingActionButton(
                      onPressed: () => _showForm(),
                      backgroundColor: const Color(0xFF4A8FA3),
                      child: const Icon(Icons.add, color: Colors.white, size: 30),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (currentRecitation != null) _buildPlayer(),
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
          ListTile(
            title: const Text("Toutes les récitations"),
            selected: selectedYearFilter == null,
            onTap: () { setState(() => selectedYearFilter = null); _applyFilters(); Navigator.pop(context); },
          ),
          ListTile(
            title: const Text("Année inconnue"),
            selected: selectedYearFilter == -1,
            onTap: () { setState(() => selectedYearFilter = -1); _applyFilters(); Navigator.pop(context); },
          ),
          const Divider(color: Colors.white24),
          ...years.map((y) {
            final yg = yearMap[y];
            return ListTile(
              title: Text("$y H  |  ${yg ?? '??'} G"),
              selected: selectedYearFilter == y,
              onTap: () { setState(() => selectedYearFilter = y); _applyFilters(); Navigator.pop(context); },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      child: Column(
        children: [
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, snapshot) {
              final pos = snapshot.data ?? Duration.zero;
              final dur = _player.duration ?? Duration.zero;
              return Column(
                children: [
                  Slider(
                    activeColor: const Color(0xFF7EB8C9),
                    value: pos.inSeconds.toDouble().clamp(0, dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0),
                    max: dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0,
                    onChanged: (v) => _player.seek(Duration(seconds: v.toInt())),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(pos), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(_formatDuration(dur), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              );
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              // GAUCHE : Informations de la sourate (Style Windows)
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${currentRecitation!['sourate_num'].toString().padLeft(3, '0')} - ${currentRecitation!['sourate_name']}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    Text(
                      "${currentRecitation!['annee'] ?? '??'} H | ${currentRecitation!['annee_g'] ?? '??'} G • Versets: ${currentRecitation!['versets']}",
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6A7A82)),
                    ),
                  ],
                ),
              ),
              // CENTRE : Boutons de lecture symétriques
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // INVERSEMENT : Stop d'abord pour la symétrie
                  IconButton(icon: const Icon(Icons.stop, size: 30), onPressed: () => _player.seek(Duration.zero)),
                  IconButton(icon: const Icon(Icons.skip_previous, size: 30), onPressed: _playPrevious),
                  StreamBuilder<bool>(
                    stream: _player.playingStream,
                    builder: (context, snap) => IconButton(
                      iconSize: 52,
                      icon: Icon(snap.data == true ? Icons.pause_circle : Icons.play_circle),
                      onPressed: () => snap.data == true ? _player.pause() : _player.play(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.skip_next, size: 30), onPressed: _playNext),
                  IconButton(
                    icon: Icon(
                      loopMode == LoopModeState.off ? Icons.repeat : 
                      loopMode == LoopModeState.autoplay ? Icons.repeat_on : Icons.repeat_one_on,
                      color: loopMode == LoopModeState.off ? Colors.grey : const Color(0xFF7EB8C9),
                    ),
                    onPressed: _toggleLoop,
                  ),
                ],
              ),
              // DROITE : Volume
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(volume == 0 ? Icons.volume_off : Icons.volume_up, size: 22, color: Colors.grey),
                    SizedBox(
                      width: 110,
                      child: Slider(
                        activeColor: const Color(0xFF7EB8C9),
                        value: volume,
                        onChanged: (v) { setState(() => volume = v); _player.setVolume(v); },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
              await http.delete(Uri.parse('http://127.0.0.1:8000/recitations/${rec['id']}'));
              _fetch();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showForm({Map<String, dynamic>? rec}) {
    showDialog(context: context, builder: (context) => FormDialog(rec: rec, onSave: _fetch));
  }
}

class FormDialog extends StatefulWidget {
  final Map<String, dynamic>? rec;
  final VoidCallback onSave;
  const FormDialog({super.key, this.rec, required this.onSave});
  @override
  State<FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<FormDialog> {
  int? selectedNum;
  String? selectedName;
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
    }
    _year = TextEditingController(text: widget.rec?['annee']?.toString() ?? "");
    _file = TextEditingController(text: widget.rec?['fichier'] ?? "");
    _ytUrl = TextEditingController();
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
              initialSelection: widget.rec != null ? ALL_SURAHS.firstWhere((s) => s['num'] == widget.rec!['sourate_num']) : null,
              width: 280,
              label: const Text("Sourate"),
              enableSearch: true,
              dropdownMenuEntries: ALL_SURAHS.map((s) => DropdownMenuEntry(value: s, label: "${s['num']} - ${s['name']}")).toList(),
              onSelected: (s) { selectedNum = s?['num']; selectedName = s?['name']; },
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _year,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              decoration: const InputDecoration(labelText: "Année (H ou G)", hintText: "Sécurité : Max 4 chiffres"),
            ),
            const SizedBox(height: 15),
            const Text("Étendue :"),
            Row(
              children: [
                Radio(value: true, groupValue: isFull, onChanged: (v) => setState(() => isFull = v!)), const Text("Complet"),
                Radio(value: false, groupValue: isFull, onChanged: (v) => setState(() => isFull = v!)), const Text("Partiel"),
              ],
            ),
            if (!isFull)
              Row(
                children: [
                  Expanded(child: TextField(controller: _vStart, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Début"))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _vEnd, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Fin"))),
                ],
              ),
            const SizedBox(height: 15),
            const Text("Source :"),
            Row(
              children: [
                Radio(value: true, groupValue: isLocal, onChanged: (v) => setState(() => isLocal = v!)), const Text("Local"),
                Radio(value: false, groupValue: isLocal, onChanged: (v) => setState(() => isLocal = v!)), const Text("YouTube"),
              ],
            ),
            if (isLocal)
              Row(
                children: [
                  Expanded(child: TextField(controller: _file, decoration: const InputDecoration(labelText: "Fichier"))),
                  IconButton(icon: const Icon(Icons.folder), onPressed: () async {
                    const XTypeGroup typeGroup = XTypeGroup(label: 'Audio', extensions: ['mp3', 'm4a', 'wav']);
                    final file = await openFile(acceptedTypeGroups: [typeGroup]);
                    if (file != null) setState(() => _file.text = file.path);
                  }),
                ],
              )
            else
              TextField(controller: _ytUrl, decoration: const InputDecoration(labelText: "Lien YouTube")),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A8FA3)),
          onPressed: () async {
            if (selectedNum == null) return;
            String versets = isFull ? "complet" : "${_vStart.text}-${_vEnd.text}";
            final data = {
              "sourate_num": selectedNum,
              "sourate_name": selectedName,
              "annee": int.tryParse(_year.text),
              "fichier": isLocal ? _file.text : _ytUrl.text,
              "versets": versets,
            };
            if (widget.rec == null) {
              await http.post(Uri.parse('http://127.0.0.1:8000/recitations'), body: jsonEncode(data), headers: {"Content-Type": "application/json"});
            } else {
              await http.put(Uri.parse('http://127.0.0.1:8000/recitations/${widget.rec!['id']}'), body: jsonEncode(data), headers: {"Content-Type": "application/json"});
            }
            widget.onSave();
            Navigator.pop(context);
          },
          child: const Text("Enregistrer", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}