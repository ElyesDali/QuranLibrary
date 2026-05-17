import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_editor/video_editor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:ffmpeg_helper/ffmpeg_helper.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class VideoEditorScreen extends StatefulWidget {
  final File videoFile;
  final Map<String, dynamic> recitationData; // Les infos (Sourate, Année...) remplies avant

  const VideoEditorScreen({super.key, required this.videoFile, required this.recitationData});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  late final VideoEditorController _controller;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoEditorController.file(
      widget.videoFile,
      minDuration: const Duration(seconds: 1),
      maxDuration: const Duration(hours: 2),
    );
    
    _controller.initialize().then((_) {
      _saveDraft(); // BOUCLIER : Sauvegarde immédiate du chemin et des données
      setState(() {});
    }).catchError((error) {
      Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- GESTION DU BROUILLON ---
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

  // --- BOÎTE DE DIALOGUE DE PAUSE/ABANDON ---
  Future<bool> _onWillPop() async {
    int? choice = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text("Quitter le montage ?"),
        content: const Text("Voulez-vous garder ce montage en brouillon pour le terminer plus tard, ou tout abandonner ?", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(0), child: const Text("Annuler", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              await _clearDraft(); // On détruit le bouclier
              Navigator.of(context).pop(1); 
            }, 
            child: const Text("Tout effacer", style: TextStyle(color: Colors.red))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7EB8C9)),
            onPressed: () {
              // Le brouillon est déjà sauvegardé par initState, on quitte juste
              Navigator.of(context).pop(2); 
            },
            child: const Text("Garder en brouillon"),
          ),
        ],
      ),
    );
    return choice != null && choice > 0;
  }

  // --- LE MOTEUR DE DÉCOUPE FFMPEG ---
  Future<void> _exportVideo() async {
    setState(() => _isExporting = true);

    try {
      final dir = await getTemporaryDirectory();
      final targetPath = p.join(dir.path, "export_${DateTime.now().millisecondsSinceEpoch}.mp4");
      
      // On récupère les temps exacts des poignées de rognage
      final start = _controller.minCrop;
      final end = _controller.maxCrop;
      final duration = end - start;

      // Commande FFmpeg : Coupe ultra-rapide sans perte de qualité (-c copy)
      // On utilise FFMpegHelper.runCommand
      final FFMpegCommand command = FFMpegCommand(
        inputs: [
          FFMpegInput(
            filepath: widget.videoFile.path,
          )
        ],
        args: [
           CustomArgument(['-y']), // Overwrite output file
           CustomArgument(['-ss', '${start.inMilliseconds / 1000}']), // Start time
           CustomArgument(['-t', '${duration.inMilliseconds / 1000}']), // Duration
           CustomArgument(['-c', 'copy']), // Codec copy
        ],
        outputFilepath: targetPath,
      );

      final FFMpegSession session = await FFMpegHelper.instance.runAsync(command);
      
      // On attend la fin de l'exécution
      final sessionState = await session.getSessionState();

      if (sessionState == FFMpegSessionState.completed) {
          await _clearDraft(); 
          // Succès ! On renvoie le fichier coupé et les métadonnées à main.dart
          if (mounted) {
            Navigator.pop(context, {
              'file': File(targetPath),
              'metadata': widget.recitationData
            });
          }
      } else {
        throw Exception("Échec de la découpe vidéo. État : $sessionState");
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Erreur : $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text("Rogner la récitation", style: TextStyle(fontSize: 16)),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (await _onWillPop()) Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: _isExporting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.green, strokeWidth: 2))
                  : const Icon(Icons.check, color: Colors.green),
              onPressed: _isExporting ? null : _exportVideo,
            ),
          ],
        ),
        body: _controller.initialized
            ? Column(
                children: [
                  // LECTEUR VIDÉO
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
                              child: Container(
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                                child: const Icon(Icons.play_arrow, size: 80, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // TIMELINE DE ROGNAGE
                  Container(
                    height: 200,
                    margin: const EdgeInsets.only(top: 10),
                    child: Column(
                      children: [
                        Expanded(
                          child: TrimSlider(
                            controller: _controller,
                            height: 60,
                            horizontalMargin: 20,
                            child: TrimTimeline(
                              controller: _controller,
                              padding: const EdgeInsets.only(top: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              )
            : const Center(child: CircularProgressIndicator(color: Color(0xFF7EB8C9))),
      ),
    );
  }
}