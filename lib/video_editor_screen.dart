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
  
  // Contrôleurs pour la saisie manuelle
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = VideoEditorController.file(
      widget.videoFile,
      minDuration: const Duration(seconds: 1),
      maxDuration: const Duration(hours: 10), // Limite repoussée
      trimStyle: TrimSliderStyle(
        positionLineColor: Colors.white,
        positionLineWidth: 3,
        lineColor: Colors.grey.withOpacity(0.5),
        onTrimmingColor: const Color(0xFF7EB8C9),
        lineWidth: 4,
        edgesType: TrimSliderEdgesType.bar, // Design style YouTube
        edgesSize: 15,
      ),
    );
    
    _controller.initialize().then((_) {
      _saveDraft();
      _controller.addListener(_updateTimecodes); // Écoute les mouvements du slider
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

  // --- LOGIQUE DES TIMECODES MANUELS ---
  String _formatter(Duration duration) {
    return [
      duration.inMinutes.remainder(60).toString().padLeft(2, '0'),
      duration.inSeconds.remainder(60).toString().padLeft(2, '0')
    ].join(":");
  }

  void _updateTimecodes() {
    if (!_controller.initialized) return;
    // Met à jour l'affichage texte quand on bouge le slider
    _startController.text = _formatter(_controller.startTrim);
    _endController.text = _formatter(_controller.endTrim);
  }

  void _applyManualTimecodes() {
    // Convertit le texte "MM:SS" en rognage réel sur la vidéo
    try {
      final startParts = _startController.text.split(':');
      final endParts = _endController.text.split(':');
      
      final startDur = Duration(minutes: int.parse(startParts[0]), seconds: int.parse(startParts[1]));
      final endDur = Duration(minutes: int.parse(endParts[0]), seconds: int.parse(endParts[1]));

      if (startDur < endDur && endDur <= _controller.videoDuration) {
        _controller.updateTrim(startDur.inMilliseconds / _controller.videoDuration.inMilliseconds, endDur.inMilliseconds / _controller.videoDuration.inMilliseconds);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Format invalide (Utilisez MM:SS)")));
    }
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
          title: const Text("Rogner", style: TextStyle(fontSize: 16)),
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
                  
                  // 2. L'INTERFACE DE MONTAGE (Style YouTube)
                  Container(
                    color: const Color(0xFF111111),
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Column(
                      children: [
                        // TIMECODES MANUELS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildTimecodeField(_startController, "Début"),
                            const Text("—", style: TextStyle(color: Colors.grey, fontSize: 18)),
                            _buildTimecodeField(_endController, "Fin"),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // LA BARRE DE ROGNAGE
                        SizedBox(
                          height: 60,
                          child: TrimSlider(
                            controller: _controller,
                            height: 60,
                            horizontalMargin: 0,
                            child: TrimTimeline(
                              controller: _controller,
                              padding: const EdgeInsets.only(top: 10),
                              textStyle: const TextStyle(color: Colors.grey, fontSize: 10),
                            ),
                          ),
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

  // Widget personnalisé pour les champs de texte
  Widget _buildTimecodeField(TextEditingController controller, String label) {
    return Container(
      width: 80,
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
        keyboardType: TextInputType.datetime,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onSubmitted: (_) => _applyManualTimecodes(),
        onEditingComplete: _applyManualTimecodes,
      ),
    );
  }
}