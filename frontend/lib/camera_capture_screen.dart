import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  String? _error;
  bool _initializing = true;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera was found.');
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _initializing = false;
      });
    }
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    final navigator = Navigator.of(context);
    setState(() => _capturing = true);
    try {
      final image = await controller.takePicture();
      if (!mounted) return;
      navigator.pop(image);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Could not capture photo: $error';
          _capturing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0EA391);
    const blue = Color(0xFF1684A7);
    const cream = Color(0xFFF4F1EA);
    final controller = _controller;

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: blue,
        foregroundColor: Colors.white,
        title: Text(
          'CAPTURE QUEST PHOTO',
          style: GoogleFonts.pressStart2p(fontSize: 9),
        ),
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator(color: teal))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.no_photography, color: blue, size: 42),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.vt323(fontSize: 20, color: blue),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: controller == null
                          ? const Center(child: Text('Camera unavailable'))
                          : Center(
                              child: AspectRatio(
                                aspectRatio: controller.value.aspectRatio,
                                child: CameraPreview(controller),
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _capturing ? null : _takePhoto,
                          icon: const Icon(Icons.camera_alt),
                          label: Text(
                            'TAKE PHOTO',
                            style: GoogleFonts.pressStart2p(fontSize: 8),
                          ),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: teal,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
