import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';

class FileExportService {

  // ================= CSV =================
  Future<void> saveCsv({
    required String filename,
    required String csvText,
  }) async {
    final bytes = Uint8List.fromList(csvText.codeUnits);
    await _saveFile(filename, bytes, 'csv');
  }

  // ================= PDF =================
  Future<void> savePdf({
    required String filename,
    required Uint8List pdfBytes,
  }) async {
    await _saveFile(filename, pdfBytes, 'pdf');
  }

  // ================= CORE SAVE LOGIC =================
  Future<void> _saveFile(String filename, Uint8List bytes, String ext) async {

    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: filename,
        bytes: bytes,
        ext: ext,
        mimeType: ext == 'pdf' ? MimeType.pdf : MimeType.csv,
      );
      return;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      await FileSaver.instance.saveFile(
        name: filename,
        bytes: bytes,
        ext: ext,
        mimeType: ext == 'pdf' ? MimeType.pdf : MimeType.csv,
      );
      return;
    }

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save file',
      fileName: '$filename.$ext',
    );

    if (path == null) return; // user cancelled

    final file = File(path);
    await file.writeAsBytes(bytes);
  }
}