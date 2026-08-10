import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/ports/share_gateway.dart';

/// Gerçek paylaşım adaptörü: geçici dizine yazar, sistem paylaşım
/// sayfasını açar.
class FileShareGateway implements ShareGateway {
  const FileShareGateway();

  @override
  Future<bool> shareText({
    required String content,
    required String fileName,
    String? subject,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, fileName));

      // `flush: true` — paylaşım hedefi dosyayı BAŞKA bir süreçte açıyor;
      // tampon diske inmeden paylaşılırsa dosya boş/yarım görünüyor.
      await file.writeAsString(content, encoding: utf8, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: subject,
      );
      return true;
    } on Object catch (e) {
      // Paylaşım iptali, izin reddi, disk dolu... hiçbiri ekranı çökertmemeli.
      debugPrint('CSV paylaşımı başarısız: $e');
      return false;
    }
  }
}

/// Paylaşımın kapalı olduğu durumlar (test, desteklenmeyen platform).
class NoopShareGateway implements ShareGateway {
  const NoopShareGateway();

  @override
  Future<bool> shareText({
    required String content,
    required String fileName,
    String? subject,
  }) async =>
      false;
}
