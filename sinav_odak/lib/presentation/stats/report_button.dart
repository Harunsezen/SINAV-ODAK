import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/app_providers.dart';
import '../../domain/entities/report_data.dart';
import '../../services/report/pdf_report_builder.dart';

/// "Rapor Al" — hedef kitle seçimi + PDF üretimi + paylaşım (FAZ 3.1).
///
/// **Sunucu YOK.** PDF cihazda üretiliyor, geçici dizine yazılıyor ve
/// sistem paylaşım sayfasına veriliyor. Hiçbir bayt ağa çıkmıyor; raporun
/// altındaki gizlilik kaşesi bu yüzden doğru bir ifade.
class ReportButton extends ConsumerStatefulWidget {
  const ReportButton({super.key});

  @override
  ConsumerState<ReportButton> createState() => _ReportButtonState();
}

class _ReportButtonState extends ConsumerState<ReportButton> {
  bool _busy = false;

  ReportStrings _strings(L10n l) => ReportStrings(
        appName: l.appTitle,
        parentTitle: l.reportParentTitle,
        teacherTitle: l.reportTeacherTitle,
        rangeLabel: l.reportRange,
        totalStudy: l.statsTotalStudy,
        sessions: l.statsSessionCount,
        questions: l.homeQuestions,
        net: l.homeNet,
        focus: l.statsAvgFocus,
        successRate: l.statsSuccessRate,
        streak: l.reportStreak,
        bestDay: l.reportBestDay,
        dailyAverage: l.reportDailyAverage,
        subjectBreakdown: l.statsSubjectBreakdown,
        weakTopics: l.statsWeakestTopics,
        wrongCount: l.summaryWrong,
        dailyDetail: l.reportDailyDetail,
        day: l.reportDay,
        duration: l.reportDuration,
        privacyStamp: l.reportPrivacyStamp,
        achievements: l.reportAchievements,
        page: l.reportPage,
      );

  Future<void> _run(ReportAudience audience) async {
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);

    String message;
    try {
      final bounds = ref.read(statsBoundsProvider);
      final data = await ref.read(buildReportProvider)(
        audience: audience,
        from: bounds.from,
        to: bounds.to,
      );

      if (data.isEmpty) {
        // Boş rapor üretip paylaşmak kullanıcıyı utandırırdı.
        message = l.reportEmpty;
      } else {
        final bytes =
            await ref.read(pdfReportBuilderProvider).build(data, _strings(l));

        final ok = await ref.read(shareGatewayProvider).shareBytes(
              bytes: bytes,
              fileName: _fileName(audience, data),
              mimeType: 'application/pdf',
              subject: audience == ReportAudience.parent
                  ? l.reportParentTitle
                  : l.reportTeacherTitle,
            );
        message = ok ? l.reportDone : l.reportFailed;
      }
    } on Object {
      // Font yüklenemedi, disk dolu, paylaşım iptal... hiçbiri İstatistik
      // ekranını çökertmemeli.
      message = l.reportFailed;
    }

    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Dosya adı tarih aralığını taşıyor: veli/eğitimci birden fazla rapor
  /// aldığında hangisinin hangi döneme ait olduğu belli olsun.
  String _fileName(ReportAudience a, ReportData d) {
    final who = a == ReportAudience.parent ? 'veli' : 'egitimci';
    return 'sinav-odak-$who-${d.fromKey}_${d.toKey}.pdf';
  }

  Future<void> _pickAudience() async {
    final l = L10n.of(context);
    final choice = await showModalBottomSheet<ReportAudience>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l.reportPickTitle,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              key: const Key('report-parent'),
              leading: const Icon(Icons.family_restroom),
              title: Text(l.reportParent),
              subtitle: Text(l.reportParentNote),
              onTap: () => Navigator.of(ctx).pop(ReportAudience.parent),
            ),
            ListTile(
              key: const Key('report-teacher'),
              leading: const Icon(Icons.school_outlined),
              title: Text(l.reportTeacher),
              subtitle: Text(l.reportTeacherNote),
              onTap: () => Navigator.of(ctx).pop(ReportAudience.teacher),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;
    await _run(choice);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return IconButton(
      key: const Key('stats-report'),
      tooltip: l.reportButton,
      onPressed: _busy ? null : _pickAudience,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf_outlined),
    );
  }
}
