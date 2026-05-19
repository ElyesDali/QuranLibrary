import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_editor/video_editor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class VideoEditorScreen extends StatefulWidget {
  final File videoFile;
  final Map<String, dynamic> recitationData;

  const VideoEditorScreen({super.key, required this.videoFile, required this.recitationData});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  late final VideoEditorController _controller;
  bool _isExporting = false;
  
  // Affichage en direct et saisie
  String _currentTime = "00:00.00";
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = VideoEditorController.file(
      widget.videoFile,
      minDuration: const Duration(seconds: 1),
      maxThumbnailQuality: 10, // <-- AJOUTE CETTE LIGNE ICI POUR SAUVER LA RAM
      trimStyle: TrimSliderStyle(
        positionLineColor: Colors.red,
        positionLineWidth: 3,
        lineColor: Colors.grey.withOpacity(0.5),
        onTrimmingColor: const Color(0xFF7EB8C9),
        lineWidth: 4,
        edgesType: TrimSliderEdgesType.bar, 
        edgesSize: 20,
      ),
    );
    
    _controller.initialize().then((_) {
      _saveDraft();
      _controller.addListener(_updateTimecodes);
      _controller.video.addListener(_updateCurrentTime); // Écoute la lecture en direct
      setState(() {});
    }).catchError((error) {
      Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_updateTimecodes);
    _controller.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  // --- LOGIQUE DES TIMECODES (Précision au centième) ---
  String _formatter(Duration duration) {
    String mins = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    String secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    String hunds = (duration.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return "$mins:$secs.$hunds";
  }

  void _updateTimecodes() {
    if (!_controller.initialized) return;
    _startController.text = _formatter(_controller.startTrim);
    _endController.text = _formatter(_controller.endTrim);
  }

  void _updateCurrentTime() {
    if (mounted && _controller.initialized) {
      setState(() {
        _currentTime = _formatter(_controller.videoPosition);
      });
    }
  }

  // Convertisseur de texte Manuel (MM:SS.XX) vers Durée
  Duration _parseTime(String timeStr) {
    timeStr = timeStr.replaceAll('.', ':'); // Harmonise les séparateurs
    final parts = timeStr.split(':');
    int m = 0, s = 0, ms = 0;
    if (parts.isNotEmpty) m = int.tryParse(parts[0]) ?? 0;
    if (parts.length > 1) s = int.tryParse(parts[1]) ?? 0;
    if (parts.length > 2) ms = (int.tryParse(parts[2]) ?? 0) * 10;
    return Duration(minutes: m, seconds: s, milliseconds: ms);
  }

  void _applyManualTimecodes() {
    try {
      final startDur = _parseTime(_startController.text);
      final endDur = _parseTime(_endController.text);

      if (startDur < endDur && endDur <= _controller.videoDuration) {
        _controller.updateTrim(
          startDur.inMilliseconds / _controller.videoDuration.inMilliseconds, 
          endDur.inMilliseconds / _controller.videoDuration.inMilliseconds
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Format: MM:SS.XX")));
    }
  }

  // --- OUTILS DE MONTAGE PRO (Magnétisme instantané) ---
  void _setStartAtPlayhead() {
    final currentPos = _controller.videoPosition.inMilliseconds / _controller.videoDuration.inMilliseconds;
    if (currentPos < _controller.maxTrim) _controller.updateTrim(currentPos, _controller.maxTrim);
  }

  void _setEndAtPlayhead() {
    final currentPos = _controller.videoPosition.inMilliseconds / _controller.videoDuration.inMilliseconds;
    if (currentPos > _controller.minTrim) _controller.updateTrim(_controller.minTrim, currentPos);
  }

  // --- GESTION DU BROUILLON ET EXPORT ---
  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('draft_video_path', widget.videoFile.path);
    await prefs.setString('draft_metadata', jsonEncode(widget.recitationData));
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('draft_video_path');
    await prefs.remove('draft_metadata');
  }

  Future<void> _exportVideo() async {
    setState(() => _isExporting = true);
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = p.join(dir.path, "export_${DateTime.now().millisecondsSinceEpoch}.mp4");
      
      final start = _controller.startTrim;
      final end = _controller.endTrim;
      final duration = end - start;

      final command = "-y -ss ${start.inMilliseconds / 1000} -i '${widget.videoFile.path}' -t ${duration.inMilliseconds / 1000} -c copy '$targetPath'";

      await FFmpegKit.execute(command).then((session) async {
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          await _clearDraft(); 
          if (mounted) Navigator.pop(context, {'file': File(targetPath), 'metadata': widget.recitationData});
        } else {
          throw Exception("Échec de la découpe vidéo.");
        }
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Erreur : $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<bool> _onWillPop() async {
    int? choice = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text("Quitter le montage ?"),
        content: const Text("Voulez-vous garder ce montage en brouillon pour le terminer plus tard, ou tout abandonner ?", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(0), child: const Text("Annuler", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () async { await _clearDraft(); Navigator.of(context).pop(1); }, child: const Text("Tout effacer", style: TextStyle(color: Colors.red))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7EB8C9)), onPressed: () => Navigator.of(context).pop(2), child: const Text("Garder en brouillon")),
        ],
      ),
    );
    return choice != null && choice > 0;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text("Éditeur Précis", style: TextStyle(fontSize: 16)),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () async { if (await _onWillPop()) Navigator.pop(context); }),
          actions: [
            IconButton(
              icon: _isExporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.green, strokeWidth: 2)) : const Icon(Icons.check, color: Colors.green),
              onPressed: _isExporting ? null : _exportVideo,
            ),
          ],
        ),
        body: _controller.initialized
            ? Column(
                children: [
                  // 1. LE LECTEUR
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CropGridViewer.preview(controller: _controller),
                        AnimatedBuilder(
                          animation: _controller.video,
                          builder: (_, __) => AnimatedOpacity(
                            opacity: _controller.isPlaying ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: GestureDetector(
                              onTap: _controller.video.play,
                              child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54), child: const Icon(Icons.play_arrow, size: 80, color: Colors.white)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 2. PANNEAU DE CONTRÔLE ERGONOMIQUE
                  Container(
                    color: const Color(0xFF111111),
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                    child: Column(
                      children: [
                        // Ligne de contrôle : Temps direct, Play/Pause, Coupes rapides
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Couper le Début ici
                            IconButton(
                              tooltip: "Fixer le début ici",
                              icon: const Icon(Icons.keyboard_arrow_left, color: Colors.white, size: 30),
                              onPressed: _setStartAtPlayhead,
                            ),
                            
                            // Temps en direct & Play/Pause
                            Row(
                              children: [
                                Text(_currentTime, style: const TextStyle(color: Color(0xFF7EB8C9), fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
                                const SizedBox(width: 15),
                                IconButton(
                                  icon: Icon(_controller.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white, size: 40),
                                  onPressed: () {
                                    _controller.isPlaying ? _controller.video.pause() : _controller.video.play();
                                    setState((){});
                                  },
                                ),
                              ],
                            ),

                            // Couper la Fin ici
                            IconButton(
                              tooltip: "Fixer la fin ici",
                              icon: const Icon(Icons.keyboard_arrow_right, color: Colors.white, size: 30),
                              onPressed: _setEndAtPlayhead,
                            ),
                          ],
                        ),

                        const SizedBox(height: 15),

                        // TIMECODES MANUELS & TIMELINE
                        Row(
                          children: [
                            _buildTimecodeField(_startController),
                            Expanded(
                              child: TrimSlider(
                                controller: _controller,
                                height: 45,
                                horizontalMargin: 10,
                                child: TrimTimeline(
                                  controller: _controller,
                                  padding: const EdgeInsets.only(top: 10),
                                  textStyle: const TextStyle(color: Colors.grey, fontSize: 10),
                                ),
                              ),
                            ),
                            _buildTimecodeField(_endController),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  )
                ],
              )
            : const Center(child: CircularProgressIndicator(color: Color(0xFF7EB8C9))),
      ),
    );
  }

  Widget _buildTimecodeField(TextEditingController controller) {
    return SizedBox(
      width: 75,
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Courier'),
        textAlign: TextAlign.center,
        keyboardType: TextInputType.datetime,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey[900],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 5),
        ),
        onSubmitted: (_) => _applyManualTimecodes(),
        onEditingComplete: _applyManualTimecodes,
      ),
    );
  }
}