import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_providers.dart';
import '../../core/router/routes.dart';
import '../../domain/entities/enums.dart';
import 'steps/consent_step.dart';
import 'steps/exam_step.dart';
import 'steps/goal_step.dart';
import 'steps/promise_step.dart';
import 'steps/summary_step.dart';

/// Onboarding — 5 adım (FAZ 3).
///
/// Önceki hali tek ekran + "Başla" butonuydu: `examType` hiç sorulmuyordu,
/// dolayısıyla LGS öğrencisine YKS dersleri gösteriliyordu; rıza da hiç
/// alınmıyordu.
///
/// Adımlar: vaat → sınav türü → günlük hedef → rıza/izin → özet.
/// Seçimler **tek yerde** (bu State) toplanır ve yalnızca son adımda,
/// [Başla] ile yazılır: yarıda bırakılan onboarding yarım ayar bırakmaz.
///
/// v1.2'de i18n: metinler `AppLocalizations`'a taşınacak (FAZ 6 / K7).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const stepCount = 5;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();

  int _step = 0;
  ExamType? _examType;
  int _minutes = 240;
  int _questions = 100;
  bool _consent = false;
  bool? _notificationOutcome;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Sınav türü adımında seçim yapılmadan ilerlenemez: `examType` ders
  /// listesini belirlediği için varsayılana düşmek yanlış ders seti demek.
  bool get _canGoNext => _step != 1 || _examType != null;

  void _goTo(int step) {
    if (step < 0 || step >= OnboardingScreen.stepCount) return;
    setState(() => _step = step);
    _controller.animateToPage(
      step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Bildirim izni ister. **Sonuç ne olursa olsun akış durmaz (K4c).**
  Future<void> _requestNotifications() async {
    final granted =
        await ref.read(notificationServiceProvider).requestPermission();
    if (!mounted) return;
    setState(() => _notificationOutcome = granted);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    await ref.read(completeOnboardingProvider)(
      examType: _examType,
      dailyGoalMinutes: _minutes,
      dailyGoalQuestions: _questions,
      personalizedAdsConsent: _consent,
    );
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _step == OnboardingScreen.stepCount - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ProgressHeader(step: _step),
            Expanded(
              child: PageView(
                key: const Key('onboarding-pageview'),
                controller: _controller,
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  const PromiseStep(),
                  ExamStep(
                    selected: _examType,
                    onSelect: (t) => setState(() => _examType = t),
                  ),
                  GoalStep(
                    minutes: _minutes,
                    questions: _questions,
                    onMinutes: (v) => setState(() => _minutes = v),
                    onQuestions: (v) => setState(() => _questions = v),
                  ),
                  ConsentStep(
                    consent: _consent,
                    onConsent: (v) => setState(() => _consent = v),
                    onRequestNotifications: _requestNotifications,
                    // "Atla": izin İSTEMEDEN sonraki adıma geçer (K4d).
                    onSkipNotifications: () => _goTo(_step + 1),
                    notificationOutcome: _notificationOutcome,
                  ),
                  SummaryStep(
                    examType: _examType,
                    minutes: _minutes,
                    questions: _questions,
                    consent: _consent,
                  ),
                ],
              ),
            ),
            _BottomBar(
              step: _step,
              isLast: isLast,
              canGoNext: _canGoNext,
              saving: _saving,
              onBack: () => _goTo(_step - 1),
              onNext: () => _goTo(_step + 1),
              onFinish: _finish,
            ),
          ],
        ),
      ),
    );
  }
}

/// İlerleme göstergesi: çubuk + "n/5".
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final shown = step + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          LinearProgressIndicator(
            key: const Key('onboarding-progress'),
            value: shown / OnboardingScreen.stepCount,
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$shown/${OnboardingScreen.stepCount}',
              key: const Key('onboarding-progress-label'),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.step,
    required this.isLast,
    required this.canGoNext,
    required this.saving,
    required this.onBack,
    required this.onNext,
    required this.onFinish,
  });

  final int step;
  final bool isLast;
  final bool canGoNext;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (step > 0)
            TextButton(
              key: const Key('onboarding-back'),
              onPressed: onBack,
              child: const Text('Geri'),
            ),
          const Spacer(),
          if (isLast)
            FilledButton(
              key: const Key('onboarding-start'),
              onPressed: saving ? null : onFinish,
              child: const Text('Başla'),
            )
          else
            FilledButton(
              key: const Key('onboarding-next'),
              // Sınav türü seçilmeden pasif.
              onPressed: canGoNext ? onNext : null,
              child: const Text('Devam'),
            ),
        ],
      ),
    );
  }
}
