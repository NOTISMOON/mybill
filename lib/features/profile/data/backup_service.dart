import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// File selection and backup export stay outside the ledger storage layer.
class BackupService {
  const BackupService();

  /// Saves the JSON through the system file picker. Returns null if canceled.
  /// The returned value is a path when available, otherwise the saved name.
  Future<String?> saveJson(String json) async {
    const name = '好好记账备份.json';
    final destination = await FilePicker.saveFile(
      dialogTitle: '保存账本 JSON',
      fileName: name,
      mimeType: 'application/json',
      bytes: Uint8List.fromList(utf8.encode(json)),
    );
    if (destination == null) return null;
    if (destination.scheme == 'file') return destination.toFilePath();

    // Android may return an SAF document URI whose final component contains
    // the chosen name. Some providers only return an opaque document id.
    final lastSegment = destination.pathSegments.isEmpty
        ? ''
        : destination.pathSegments.last.split('/').last;
    return lastSegment.toLowerCase().endsWith('.json') ? lastSegment : name;
  }

  /// Opens the system share sheet with a temporary JSON backup attachment.
  Future<void> shareJson(String json, Rect shareOrigin) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}好好记账备份.json');
    await file.writeAsString(json, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        text: '好好记账 JSON 备份',
        sharePositionOrigin: shareOrigin,
      ),
    );
  }

  Future<String?> pickJson() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return null;
    final length = file.lengthSync() ?? await file.length();
    if (length != null && length > 20 * 1024 * 1024) {
      throw const FormatException('文件超过 20 MB，请选择较小的账本。');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('文件超过 20 MB，请选择较小的账本。');
    }
    return utf8.decode(bytes);
  }

  /// Keeps the current ledger on the device before a replacement import.
  Future<File> savePreImportBackup(String json) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${documents.path}${Platform.pathSeparator}backups',
    );
    await directory.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File(
      '${directory.path}${Platform.pathSeparator}ledger-before-import-$stamp.json',
    );
    await file.writeAsString(json, flush: true);
    return file;
  }
}
