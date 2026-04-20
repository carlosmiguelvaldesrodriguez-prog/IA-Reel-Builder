import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:google_generative_ai/google_generative_ai.dart'; 
import 'package:image/image.dart' as img; 
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'dart:io';

void main() => runApp(const MiEstudioApp());

class VideoClip {
  final String imageName;
  final double duration;
  final String transition;
  VideoClip({required this.imageName, required this.duration, required this.transition});
  factory VideoClip.fromJson(Map<String, dynamic> json) => VideoClip(
    imageName: json['image_name'] ?? json['image_id'] ?? "foto.jpg",
    duration: (json['duration_sec'] ?? json['duration'] ?? 3.0).toDouble(),
    transition: json['transition'] ?? 'crossfade'
  );
}

class MiEstudioApp extends StatelessWidget {
  const MiEstudioApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      theme: ThemeData.dark(),
      home: const PantallaPrincipal()
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});
  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  List<PlatformFile> fotos = [];
  List<VideoClip> clips = [];
  bool cargando = false;
  String log = "Listo para crear Reels de 30s.";

  Future<void> seleccionar() async {
    FilePickerResult? res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (res != null) {
      setState(() { fotos = res.files; clips = []; log = "${res.files.length} fotos cargadas."; });
    }
  }

  Future<void> procesarIA() async {
    setState(() => cargando = true);
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: 'AIzaSyAOHfy0kk4gHHaOoXwt4kCKKhiifqnIeUw');
      final images = <DataPart>[];
      for (var f in fotos) {
        final bytes = await File(f.path!).readAsBytes();
        final decoded = img.decodeImage(bytes);
        final mini = img.encodeJpg(img.copyResize(decoded!, width: 400), quality: 60);
        images.add(DataPart('image/jpeg', Uint8List.fromList(mini)));
      }
      final prompt = TextPart('Director: Crea Reel de 30s. 10 escenas. Clips de ~3s. Alterna transiciones: crossfade, fade_black, wipeleft. JSON: {"timeline":[{"image_name":"x","duration_sec":3.0, "transition":"crossfade"}]}');
      final resp = await model.generateContent([Content.multi([...images, prompt])]);
      final data = jsonDecode(resp.text!.replaceAll('```json', '').replaceAll('```', '').trim());
      setState(() { 
        clips = (data['timeline'] as List).map((i) => VideoClip.fromJson(i)).toList();
        log = "¡Guion de ${clips.length} escenas listo! Presiona Renderizar.";
      });
    } catch (e) { setState(() => log = "Error IA: $e"); }
    finally { setState(() => cargando = false); }
  }

  Future<void> renderizarVideo() async {
    setState(() { cargando = true; log = "Iniciando motor FFmpeg en Windows..."; });
    await Future.delayed(const Duration(seconds: 4));
    setState(() { cargando = false; log = "✨ ¡VIDEO RENDERIZADO! (Simulación)"; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IA REEL STUDIO - WINDOWS')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(log, style: const TextStyle(color: Colors.cyan, fontStyle: FontStyle.italic)),
              const SizedBox(height: 30),
              if (!cargando)
                ElevatedButton(onPressed: seleccionar, child: const Text("1. SUBIR FOTOS")),
              const SizedBox(height: 15),
              if (fotos.isNotEmpty && !cargando)
                ElevatedButton(onPressed: procesarIA, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("2. GENERAR GUION")),
              const SizedBox(height: 15),
              if (clips.isNotEmpty && !cargando)
                ElevatedButton(onPressed: renderizarVideo, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), child: const Text("3. RENDERIZAR VIDEO")),
              if (cargando)
                const CircularProgressIndicator(),
              if (clips.isNotEmpty) ...[
                const SizedBox(height: 30),
                const Text("STORYBOARD:", style: TextStyle(fontWeight: FontWeight.bold)),
                for (final clip in clips)
                  Text("Foto: ${clip.imageName}, Duración: ${clip.duration}s, Transición: ${clip.transition}", style: const TextStyle(fontSize: 12)),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
