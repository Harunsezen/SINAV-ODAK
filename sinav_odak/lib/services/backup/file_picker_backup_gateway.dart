import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../domain/ports/backup_file_gateway.dart';

/// Gerçek dosya seçici adaptörü (v1.3).
///
/// Kullanıcı yedeği Drive'dan, indirilenlerden, e-postadan — nereye
/// koyduysa oradan seçiyor. Uygulama dosyayı yalnızca OKUYOR; hiçbir
/// yere göndermiyor.
class FilePickerBackupGateway implements BackupFileGateway {
  const FilePickerBackupGateway();

  @override
  Future<String?> pickBackupText() async {
    try {
      // `FileType.any`: bazı Android sürümleri `.json` uzantısını
      // tanımıyor ve özel uzantı filtresiyle dosya seçici BOŞ liste
      // gösteriyor. Kullanıcı doğru dosyayı görebilmeli; yanlış dosya
      // seçerse `BackupCodec` zaten imzadan anlıyor ve reddediyor.
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Yedek dosyasını seç',
      );

      final files = result?.files ?? const [];
      if (files.isEmpty) return null;
      final path = files.first.path;
      if (path == null) return null;

      return await File(path).readAsString(encoding: utf8);
    } on Object catch (e) {
      // İptal, izin reddi, bozuk dosya, okunamayan yol — hiçbiri
      // ayarlar ekranını çökertmemeli.
      debugPrint('Yedek dosyası okunamadı: $e');
      return null;
    }
  }
}
