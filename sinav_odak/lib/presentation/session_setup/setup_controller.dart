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
    this.topicIds = const [],
    this.topicNames = const [],
    this.activityTypeId,
    this.activityTypeName,
  });

  final String? subjectId;
  final String? subjectName;
  final String? subjectColorHex;

  /// Seçilen konular, kullanıcının seçtiği SIRAYLA (v1.2/D).
  ///
  /// Konu seçimi ATLANABİLİR; bu listeler boş kalabilir.
  final List<String> topicIds;
  final List<String> topicNames;

  final String? activityTypeId;
  final String? activityTypeName;

  /// Birincil konu — listenin ilki.
  ///
  /// Şemadaki `study_sessions.topic_id` ile aynı kural. Tek konu gösteren
  /// yerler (CSV, yanlış defteri, ana panel) bunu okuyor.
  String? get topicId => topicIds.isEmpty ? null : topicIds.first;
  String? get topicName => topicNames.isEmpty ? null : topicNames.first;

  /// Birden fazla konu seçildiyse kaç TANE FAZLA olduğu ("+2" rozeti).
  int get extraTopicCount => topicIds.isEmpty ? 0 : topicIds.length - 1;

  /// Plan ekranına geçmek için ders ve tür zorunlu, konu değil.
  bool get isReadyForPlan => subjectId != null && activityTypeId != null;

  SetupSelection copyWith({
    String? subjectId,
    String? subjectName,
    String? subjectColorHex,
    List<String>? topicIds,
    List<String>? topicNames,
    String? activityTypeId,
    String? activityTypeName,
  }) {
    return SetupSelection(
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      subjectColorHex: subjectColorHex ?? this.subjectColorHex,
      topicIds: topicIds ?? this.topicIds,
      topicNames: topicNames ?? this.topicNames,
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
      _sameList(other.topicIds, topicIds) &&
      _sameList(other.topicNames, topicNames) &&
      other.activityTypeId == activityTypeId &&
      other.activityTypeName == activityTypeName;

  /// Liste eşitliği ELLE: Dart'ta `List` `==` kimlik karşılaştırıyor ve
  /// aynı içerikli iki liste farklı sayılıyor. Riverpod state'i buna
  /// bakarak yeniden çiziyor; kimlik karşılaştırması her `copyWith`te
  /// gereksiz yeniden çizim üretirdi.
  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        subjectId,
        subjectName,
        subjectColorHex,
        Object.hashAll(topicIds),
        Object.hashAll(topicNames),
        activityTypeId,
        activityTypeName,
      );

  @override
  String toString() => 'SetupSelection($subjectName / '
      '${topicNames.isEmpty ? "konusuz" : topicNames.join(", ")} / '
      '$activityTypeName)';
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

  /// Tek konu seçer — önceki seçimin YERİNE.
  ///
  /// Hızlı yol: listeden bir konuya dokunmak. Çoklu seçim ayrı bir
  /// eylem ([toggleTopic]); tek dokunuş v1.1'deki gibi tek konu seçip
  /// ilerliyor.
  void selectTopic({required String id, required String name}) {
    state = state.copyWith(topicIds: [id], topicNames: [name]);
  }

  /// Konuyu listeye ekler veya çıkarır (v1.2/D).
  ///
  /// Sıra korunuyor: ilk seçilen birincil konu olarak kalıyor. Çıkarılan
  /// birincil konuysa sıradaki birincil oluyor — kullanıcı "ilk seçtiğim
  /// gitti, ikincisi başa geçti" diye şaşırmasın diye liste hep aynı
  /// sırada.
  void toggleTopic({required String id, required String name}) {
    final ids = [...state.topicIds];
    final names = [...state.topicNames];
    final i = ids.indexOf(id);
    if (i >= 0) {
      ids.removeAt(i);
      names.removeAt(i);
    } else {
      ids.add(id);
      names.add(name);
    }
    state = state.copyWith(topicIds: ids, topicNames: names);
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
