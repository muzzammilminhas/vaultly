import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class OcrResult {
  const OcrResult({required this.text, required this.blockCount});

  final String text;
  final int blockCount;

  bool get hasText => text.trim().isNotEmpty;
}

/// On-device text recognition via ML Kit.
///
/// The native recognizer runs the actual inference on a platform background
/// thread; awaiting [extractText] is non-blocking I/O over the platform
/// channel, so the Flutter UI isolate never stalls during a scan.
///
/// Recognition itself never leaves the device. The one exception is Google
/// Play Services provisioning the text-recognition model the first time
/// it's needed on a given device — a one-time, OS-level download, not a
/// call this app makes. Every scan after that runs fully offline.
class OcrService {
  OcrService() : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  /// Runs OCR on an encoded (e.g. JPEG) image. ML Kit's file-based API needs
  /// a path, so the bytes are staged to a temp file for the duration of the
  /// call and deleted immediately after, win or lose.
  Future<OcrResult> extractText(Uint8List imageBytes) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      p.join(tempDir.path, 'vaultly_ocr_${DateTime.now().microsecondsSinceEpoch}.jpg'),
    );
    await tempFile.writeAsBytes(imageBytes);
    try {
      final inputImage = InputImage.fromFilePath(tempFile.path);
      final recognized = await _recognizer.processImage(inputImage);
      return OcrResult(text: recognized.text, blockCount: recognized.blocks.length);
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  void dispose() {
    _recognizer.close();
  }
}
