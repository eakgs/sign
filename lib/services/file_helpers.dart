import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class PickedFileData {
  final String? path;
  final Uint8List bytes;
  PickedFileData({required this.bytes, this.path});
}

class FileHelpers {
  static Future<PickedFileData?> pickPdfBytes() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    return PickedFileData(bytes: f.bytes!, path: f.path);
  }

  static Future<String> saveBytesToAppSupport(
    Uint8List bytes,
    String fileName,
  ) async {
    final dir = await getApplicationSupportDirectory();
    final path = '${dir.path}/$fileName';
    final out = File(path);
    await out.create(recursive: true);
    await out.writeAsBytes(bytes, flush: true);
    return path;
  }

  static Future<void> openPath(String path) async {
    await OpenFile.open(path);
  }
}
