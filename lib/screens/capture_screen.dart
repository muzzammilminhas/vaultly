import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../services/ocr_service.dart';
import '../widgets/crop_box.dart';

enum _Stage { camera, reviewing, ocr, error }

/// The result of a capture: the final cropped image plus whatever text
/// on-device OCR could pull from it.
class CaptureResult {
  const CaptureResult({required this.imageBytes, required this.extractedText});

  final Uint8List imageBytes;
  final String extractedText;
}

/// Capture a document via camera or gallery, crop/rotate it, then run
/// on-device OCR so the extracted text can be visually confirmed against the
/// image before it's accepted. Pops with a [CaptureResult], or null if
/// cancelled.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  _Stage _stage = _Stage.camera;
  String? _errorMessage;

  img.Image? _decoded;
  Uint8List? _previewBytes;
  Rect _cropRect = const Rect.fromLTRB(0.08, 0.08, 0.92, 0.92);

  final OcrService _ocrService = OcrService();
  Uint8List? _finalImageBytes;
  OcrResult? _ocrResult;
  String? _ocrError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _stage = _Stage.error;
          _errorMessage = 'No camera found on this device. You can still import from the gallery.';
        });
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(camera, ResolutionPreset.high, enableAudio: false);
      _controller = controller;
      _initializeControllerFuture = controller.initialize();
      await _initializeControllerFuture;
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _errorMessage = 'Camera unavailable — you can still import from the gallery.\n($e)';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || controller.value.isTakingPicture) {
      return;
    }
    try {
      final file = await controller.takePicture();
      final bytes = await File(file.path).readAsBytes();
      _loadForReview(bytes);
    } catch (e) {
      _showSnack('Could not capture photo: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 95);
      if (picked == null) return;
      final bytes = await File(picked.path).readAsBytes();
      _loadForReview(bytes);
    } catch (e) {
      _showSnack('Could not open gallery: $e');
    }
  }

  void _loadForReview(Uint8List bytes) {
    var decoded = img.decodeImage(bytes);
    if (decoded == null) {
      _showSnack('That image could not be read. Try another one.');
      return;
    }
    // Camera/gallery JPEGs often carry an EXIF orientation tag rather than
    // pre-rotated pixels — bake it in so the crop box and final image
    // aren't sideways.
    decoded = img.bakeOrientation(decoded);
    setState(() {
      _decoded = decoded;
      _previewBytes = Uint8List.fromList(img.encodeJpg(decoded!, quality: 90));
      _cropRect = const Rect.fromLTRB(0.08, 0.08, 0.92, 0.92);
      _stage = _Stage.reviewing;
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _rotate() {
    final decoded = _decoded;
    if (decoded == null) return;
    final rotated = img.copyRotate(decoded, angle: 90);
    setState(() {
      _decoded = rotated;
      _previewBytes = Uint8List.fromList(img.encodeJpg(rotated, quality: 90));
    });
  }

  void _retake() {
    setState(() {
      _decoded = null;
      _previewBytes = null;
      _stage = _Stage.camera;
    });
  }

  Future<void> _confirm() async {
    final decoded = _decoded;
    if (decoded == null) return;
    final x = (_cropRect.left * decoded.width).round().clamp(0, decoded.width - 1);
    final y = (_cropRect.top * decoded.height).round().clamp(0, decoded.height - 1);
    final w = (_cropRect.width * decoded.width).round().clamp(1, decoded.width - x);
    final h = (_cropRect.height * decoded.height).round().clamp(1, decoded.height - y);
    final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
    final jpg = Uint8List.fromList(img.encodeJpg(cropped, quality: 92));

    setState(() {
      _finalImageBytes = jpg;
      _ocrResult = null;
      _ocrError = null;
      _stage = _Stage.ocr;
    });

    try {
      final result = await _ocrService.extractText(jpg);
      if (!mounted) return;
      setState(() => _ocrResult = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocrError = 'Text recognition failed: $e');
    }
  }

  void _acceptResult() {
    final imageBytes = _finalImageBytes;
    if (imageBytes == null) return;
    Navigator.of(context).pop(
      CaptureResult(imageBytes: imageBytes, extractedText: _ocrResult?.text ?? ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(switch (_stage) {
          _Stage.reviewing => 'Adjust crop',
          _Stage.ocr => 'Extracted text',
          _ => 'Scan document',
        }),
      ),
      body: switch (_stage) {
        _Stage.camera => _buildCameraStage(),
        _Stage.reviewing => _buildReviewStage(),
        _Stage.ocr => _buildOcrStage(),
        _Stage.error => _buildErrorStage(),
      },
    );
  }

  Widget _buildCameraStage() {
    final controller = _controller;
    return Column(
      children: [
        Expanded(
          child: controller == null || _initializeControllerFuture == null
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder(
                  future: _initializeControllerFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Center(child: CameraPreview(controller));
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  iconSize: 32,
                  color: Colors.white,
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  tooltip: 'Import from gallery',
                ),
                GestureDetector(
                  onTap: _capture,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStage() {
    final decoded = _decoded;
    final previewBytes = _previewBytes;
    if (decoded == null || previewBytes == null) return const SizedBox.shrink();
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CropBox(
                imageBytes: previewBytes,
                imageWidth: decoded.width,
                imageHeight: decoded.height,
                onChanged: (rect) => _cropRect = rect,
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _retake,
                  icon: const Icon(Icons.replay, color: Colors.white),
                  label: const Text('Retake', style: TextStyle(color: Colors.white)),
                ),
                TextButton.icon(
                  onPressed: _rotate,
                  icon: const Icon(Icons.rotate_right, color: Colors.white),
                  label: const Text('Rotate', style: TextStyle(color: Colors.white)),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _confirm,
                  icon: const Icon(Icons.check),
                  label: const Text('Use photo'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOcrStage() {
    final imageBytes = _finalImageBytes;
    if (imageBytes == null) return const SizedBox.shrink();
    final result = _ocrResult;
    final error = _ocrError;
    final isRunning = result == null && error == null;

    return Column(
      children: [
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(imageBytes, fit: BoxFit.contain, width: double.infinity),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: isRunning
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white70),
                        SizedBox(height: 12),
                        Text('Reading text on-device…', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  )
                : error != null
                    ? Center(
                        child: Text(
                          error,
                          style: const TextStyle(color: Colors.orangeAccent),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : SingleChildScrollView(
                        child: Text(
                          result!.hasText ? result.text : 'No text was found in this image.',
                          style: TextStyle(
                            color: result.hasText ? Colors.white : Colors.white54,
                            fontStyle: result.hasText ? FontStyle.normal : FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _retake,
                  icon: const Icon(Icons.replay, color: Colors.white),
                  label: const Text('Retake', style: TextStyle(color: Colors.white)),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: isRunning ? null : _acceptResult,
                  icon: const Icon(Icons.check),
                  label: const Text('Looks good'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorStage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Camera unavailable.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Import from gallery'),
            ),
          ],
        ),
      ),
    );
  }
}
