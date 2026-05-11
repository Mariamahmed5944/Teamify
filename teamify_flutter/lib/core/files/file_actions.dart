import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class PickedUploadFile {
  final String path;
  final String name;

  const PickedUploadFile({required this.path, required this.name});
}

class FileActions {
  Future<PickedUploadFile?> pickFile() async {
    final result = await FilePicker.pickFiles(withData: false);
    final file = result?.files.single;
    if (file == null || file.path == null) return null;
    return PickedUploadFile(path: file.path!, name: file.name);
  }

  Future<String> saveBytes(String filename, List<int> bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> openPath(String path) async {
    await OpenFilex.open(path);
  }
}
