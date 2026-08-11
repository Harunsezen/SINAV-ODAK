import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Oturum kurulum akışında biriken seçimler.
///
/// Yalnızca **kimlik ve görünen ad** taşır; Drift tipleri taşımaz. Böylece
/// presentation katmanı data katmanına bağımlı olmaz.
class SetupSelection {
  const SetupSelection({
    this.subjectId,
    this.subjectName,
    this.subjectColorHex,
    this.topicId,
    this.topicName,
    this.activityTypeId,
    this.activityTypeName,
  });

  final String? subjectId;
  final String? subjectName;
  final String? subjectColorHex;

  /// Konu seçimi ATLANABİLİR; bu alan null kalabilir.
  final String? topicId;
  final String? topicName;

  final String? activityTypeId;
  final String? activityTypeName;

  /// Plan ekranına geçmek için ders ve tür zorunlu, konu değil.
  bool get isReadyForPlan => subjectId != null && activityTypeId != null;

  SetupSelection copyWith({
    String? subjectId,
    String? subjectName,
    String? subjectColorHex,
    String? topicId,
    String? topicName,
    String? activityTypeId,
    String? activityTypeName,
  }) {
    return SetupSelection(
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      subjectColorHex: subjectColorHex ?? this.subjectColorHex,
      topicId: topicId ?? this.topicId,
      topicName: topicName ?? this.topicName,
      activityTypeId: activityTypeId ?? this.activityTypeId,
      activityTypeName: activityTypeName ?? this.activityTypeName,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SetupSelection &&
      other.subjectId == subjectId &&
      other.subjectName == subjectName &&
      other.subjectColorHex == subjectColorHex &&
      other.topicId == topicId &&
      other.topicName == topicName &&
      other.activityTypeId == activityTypeId &&
      other.activityTypeName == activityTypeName;

  @override
  int get hashCode => Object.hash(
        subjectId,
        subjectName,
        subjectColorHex,
        topicId,
        topicName,
        activityTypeId,
        activityTypeName,
      );

  @override
  String toString() =>
      'SetupSelection($subjectName / ${topicName ?? "konusuz"} / $activityTypeName)';
}

/// Kurulum akışının state'i.
///
/// **autoDispose DEĞİL** (KARAR K1): ekranlar arası geçişte seçimler
/// kaybolmamalı. Temizlik açıkça yapılır — oturum başlatıldığında veya
/// akış iptal edildiğinde [reset].
class SetupNotifier extends Notifier<SetupSelection> {
  @override
  SetupSelection build() => const SetupSelection();

  void selectSubject({
    required String id,
    required String name,
    required String colorHex,
  }) {
    // Ders değişirse önceki konu seçimi geçersizdir.
    state = SetupSelection(
      subjectId: id,
      subjectName: name,
      subjectColorHex: colorHex,
      activityTypeId: state.activityTypeId,
      activityTypeName: state.activityTypeName,
    );
  }

  void selectTopic({required String id, required String name}) {
    state = state.copyWith(topicId: id, topicName: name);
  }

  /// "Konu seçmeden devam et": [SetupSelection.topicId] null kalır.
  void skipTopic() {
    state = SetupSelection(
      subjectId: state.subjectId,
      subjectName: state.subjectName,
      subjectColorHex: state.subjectColorHex,
      activityTypeId: state.activityTypeId,
      activityTypeName: state.activityTypeName,
    );
  }

  void selectActivityType({required String id, required String name}) {
    state = state.copyWith(activityTypeId: id, activityTypeName: name);
  }

  /// Tüm seçimleri temizler. Başlatma ve iptal yollarında ZORUNLU;
  /// yoksa eski seçimler yeni akışa sızar.
  void reset() => state = const SetupSelection();
}

final setupProvider =
    NotifierProvider<SetupNotifier, SetupSelection>(SetupNotifier.new);
