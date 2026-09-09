import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';
import '../../../domain/services/backup_codec.dart';

/// YEDEKLE / GERİ YÜKLE (v1.3).
///
/// ## Neden bu ekranda, neden bu sırada
///
/// Uygulamanın verisi yalnızca cihazda — bu bir gizlilik güvencesi ama
/// aynı zamanda bir risk: **telefon değişince altı aylık geçmiş ölüyor.**
/// Yedek almak kolay olmalı; geri yüklemek ZOR olmalı, çünkü geri
/// yükleme mevcut veriyi siliyor.
///
/// Sıra da bunu söylüyor: önce "Yedek al", sonra "Geri yükle".
class BackupTiles extends ConsumerStatefulWidget {
  const BackupTiles({super.key});

  @override
  ConsumerState<BackupTiles> createState() => _BackupTilesState();
}

class _BackupTilesState extends ConsumerState<BackupTiles> {
  bool _busy = false;

  void _say(String message, {Key? key}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(key: key, content: Text(message)));
  }

  // ------------------------------------------------------------------
  // YEDEK AL — onay yok, tek dokunuş
  // ------------------------------------------------------------------

  Future<void> _export() async {
    final l = L10n.of(context);
    setState(() => _busy = true);
    try {
      final summary = await ref.read(exportBackupProvider)(
        nowMs: ref.read(clockProvider)(),
        appVersion: ref.read(appVersionProvider),
      );
      // `null` = paylaşım penceresi kapatıldı. Hata değil, ama başarı
      // mesajı göstermek de yalan olurdu.
      _say(
        summary == null
            ? l.backupExportFailed
            : l.backupExportDone(summary.sessions, summary.books),
        key: const Key('backup-export-snack'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------------
  // GERİ YÜKLE — dosya seç, NE GELDİĞİNİ göster, sonra onayla
  // ------------------------------------------------------------------

  Future<void> _import() async {
    final l = L10n.of(context);
    setState(() => _busy = true);
    try {
      final text = await ref.read(backupFileGatewayProvider).pickBackupText();
      // Kullanıcı iptal etti: sessizce dur. "Dosya seçilmedi" uyarısı
      // vermek, bilerek vazgeçen kullanıcıyı azarlamak olurdu.
      if (text == null || !mounted) return;

      // **Onaydan ÖNCE çözümleniyor.** Kullanıcıya "3 oturum ve 1 okuma
      // geliyor" diyebilmek için dosyanın içine bakmak gerekiyor; ayrıca
      // bozuk dosya onay diyaloğuna hiç gelmiyor.
      final BackupEnvelope env;
      try {
        env = BackupCodec.decode(
          text,
          currentSchemaVersion: ref.read(databaseProvider).schemaVersion,
        );
      } on BackupFormatException catch (e) {
        _say(_errorText(l, e.reason), key: const Key('backup-error-snack'));
        return;
      }

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('backup-restore-dialog'),
          icon: const Icon(Icons.warning_amber_outlined),
          title: Text(l.backupRestoreTitle),
          content: Text(
            l.backupRestoreBody(
              env.rowCount('study_sessions'),
              env.rowCount('book_sessions'),
            ),
          ),
          actions: [
            TextButton(
              key: const Key('backup-restore-cancel'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l.commonCancel),
            ),
            // Yıkıcı eylem hata renginde ve varsayılan DEĞİL: diyalog
            // açılır açılmaz "tamam"a basmak refleksi burada veri
            // siliyor.
            FilledButton(
              key: const Key('backup-restore-confirm'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(88, 48),
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l.backupRestoreConfirm),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;

      final result = await ref.read(importBackupProvider)(text);
      _say(
        l.backupRestoreDone(result.rows),
        key: const Key('backup-restore-snack'),
      );
    } on BackupFormatException catch (e) {
      _say(_errorText(l, e.reason), key: const Key('backup-error-snack'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Her ret sebebine AYRI metin.
  ///
  /// Tek bir "yedek yüklenemedi" mesajı kullanıcıyı çaresiz bırakırdı:
  /// yanlış dosyayı mı seçti, dosya mı bozuk, uygulaması mı eski —
  /// üçünün çözümü farklı.
  String _errorText(L10n l, BackupFailureReason reason) => switch (reason) {
        BackupFailureReason.notJson => l.backupErrorNotJson,
        BackupFailureReason.notOurBackup => l.backupErrorNotOurs,
        BackupFailureReason.tooNew => l.backupErrorTooNew,
        BackupFailureReason.malformed => l.backupErrorMalformed,
      };

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Column(
      children: [
        ListTile(
          key: const Key('backup-export'),
          leading: const Icon(Icons.save_alt),
          title: Text(l.settingsBackupExport),
          subtitle: Text(l.settingsBackupExportNote),
          enabled: !_busy,
          onTap: _busy ? null : _export,
        ),
        ListTile(
          key: const Key('backup-import'),
          leading: const Icon(Icons.settings_backup_restore),
          title: Text(l.settingsBackupImport),
          subtitle: Text(l.settingsBackupImportNote),
          enabled: !_busy,
          onTap: _busy ? null : _import,
        ),
      ],
    );
  }
}
