import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

/// Üretim bağlantısı: uygulama belge klasöründe `sinav_odak.sqlite`.
///
/// Not: Şifreleme (SQLCipher/AES-256) bilinçli olarak KAPSAM DIŞI.
/// Saklanan veri çalışma süresi ve soru sayısı; şifreleme anahtar yönetimi
/// karmaşıklığı getirir, karşılığında anlamlı bir koruma sağlamaz.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'sinav_odak.sqlite'));

    // Android'de eski sqlite3 sürümlerinden kaçın.
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();

    // Geçici dosyalar için sqlite3'e yazılabilir dizin göster.
    final cacheDir = await getTemporaryDirectory();
    sqlite3.tempDirectory = cacheDir.path;

    return NativeDatabase.createInBackground(file);
  });
}

/// Testler için bellek içi bağlantı.
QueryExecutor openTestConnection() => NativeDatabase.memory();
