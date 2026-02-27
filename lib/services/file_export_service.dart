import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:open_filex/open_filex.dart';

class FileExportService {
  Future<void> saveCsv({
    required String filename,
    required String csvText,
  }) async {
    final bytes = Uint8List.fromList(csvText.codeUnits);
    final path = await FileSaver.instance.saveFile(
      name: filename,
      bytes: bytes,
      ext: 'csv',
      mimeType: MimeType.csv,
    );
    await OpenFilex.open(path);
  }

  Future<void> savePdf({
    required String filename,
    required Uint8List pdfBytes,
  }) async {
    final path = await FileSaver.instance.saveFile(
      name: filename,
      bytes: pdfBytes,
      ext: 'pdf',
      mimeType: MimeType.pdf,
    );
    await OpenFilex.open(path);
  }
}
