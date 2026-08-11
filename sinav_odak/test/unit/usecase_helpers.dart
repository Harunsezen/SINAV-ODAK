import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:sinav_odak/application/schedule_writer.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/data/repositories/session_repository.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/entities/session_schedule.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/domain/services/schedule_builder.dart';

/// Sabit epoch: 2025-08-06 08:00:00 UTC. Testlerde DateTime.now() KULLANILMAZ.
const int t0 = 1754467200000;

const subjectId = 'sub_yks_1'; // Matematik
const topicId = 'top_sub_yks_1_22'; // Türev
const activityId = 'act_soru';

/// Bildirim çağrılarını sayan sahte implementasyon.
class FakeNotifier implements SessionNotifier {
  final List<String> scheduled = [];
  final List<String> cancelled = [];

  @override
  Future<void> scheduleFor({
    required String sessionId,
    required SessionSchedule schedule,
  }) async =>
      scheduled.add(sessionId);

  @override
  Future<void> cancelAll(String sessionId) async => cancelled.add(sessionId);

  @override
  Future<bool> hasPermission() async => true;
}

/// attach/detach çağrılarını kaydeden sahte izleyici.
class FakeTracker implements SessionActivityTracker {
  final List<String> attached = [];
  int detachCount = 0;

  @override
  void attach(String sessionId) => attached.add(sessionId);

  @override
  Future<void> detach() async => detachCount++;
}

AppDatabase newDb() => AppDatabase(NativeDatabase.memory());

SessionRepository newRepo(AppDatabase db) => SessionRepository(db);

ScheduleWriter newWriter(AppDatabase db, SessionNotifier n) =>
    ScheduleWriter(db, n);

/// 24 dk çalışma + 5 dk mola + 24 dk çalışma. Mola indeksi 1.
SessionSchedule schedule({int startAtMs = t0}) => ScheduleBuilder.fromPreset(
      startAtMs: startAtMs,
      workMinutes: 24,
      breakMinutes: 5,
      cycles: 2,
    ).schedule;

const int breakIndex = 1;
const int breakStart = t0 + 1440000;
const int breakEnd = breakStart + 300000;
const int lastEnd = breakEnd + 1440000;

/// Hazır bir `running` oturum yazar (use-case'i atlayarak).
Future<void> seedRunningSession(
  AppDatabase db, {
  required String id,
  required SessionSchedule sch,
}) async {
  await db.sessionDao.createSession(
    StudySessionsCompanion.insert(
      id: id,
      dateKey: '2025-08-06',
      startedAt: sch.firstStartMs,
      plannedDurationS: sch.totalStudyS,
      subjectId: subjectId,
      topicId: const Value(topicId),
      activityTypeId: activityId,
      status: SessionStatus.running,
      scheduleJson: _encode(sch),
    ),
    ScheduleWriter.blocksOf(id, sch),
  );
}

String _encode(SessionSchedule s) => jsonEncode(s.toJson());
