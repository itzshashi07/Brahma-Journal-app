import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:brahma_app/models/journal_entry.dart';
import 'package:brahma_app/providers/journal_provider.dart';
import 'package:brahma_app/services/journal_service.dart';
import 'package:brahma_app/services/streak_service.dart';

class TestJournal extends JournalService {
  DateTime day = DateTime.now();
  @override
  JournalEntry? todaysEntryFrom(List<JournalEntry> entries) {
    for (final e in entries) {
      if (e.createdAt.year == day.year && e.createdAt.month == day.month && e.createdAt.day == day.day) return e;
    }
    return null;
  }
  Future<List<JournalEntry>> Function(String?) load = (_) async => [];
  @override
  Future<List<JournalEntry>> getEntries([String? uid]) => load(uid);
}

class TestStreaks extends StreakService {
  @override
  Future<List<DateTime>> recoveredDays([String? uid]) async => [];
}

void main() {
  late TestJournal service;
  late JournalProvider provider;
  final entry =
      JournalEntry(uid: 'member-a', mood: 4, createdAt: DateTime.now());
  setUp(() {
    service = TestJournal();
    provider = JournalProvider(service: service, streaks: TestStreaks());
  });
  tearDown(() => provider.dispose());
  test('today changes after midnight without replacing saved entries', () async {
    service.load = (_) async => [entry];
    await provider.loadEntries('member-a');
    expect(provider.todaysEntry, entry);
    service.day = DateTime(service.day.year, service.day.month, service.day.day + 1);
    expect(provider.todaysEntry, isNull);
    expect(provider.entries, [entry]);
  });
  test('failed refresh keeps saved entries and ends loading', () async {
    service.load = (_) async => [entry];
    await provider.loadEntries('member-a');
    service.load = (_) async => throw Exception('offline');
    await provider.loadEntries('member-a');
    expect(provider.entries, [entry]);
    expect(provider.error, isNotNull);
    expect(provider.loading, isFalse);
    expect(provider.hasLoaded, isTrue);
  });
  test('first-load failure is not reported as an empty diary', () async {
    service.load = (_) async => throw Exception('offline');
    await provider.loadEntries('member-a');
    expect(provider.hasLoaded, isFalse);
    expect(provider.error, isNotNull);
    service.load = (_) async => [];
    await provider.loadEntries('member-a');
    expect(provider.hasLoaded, isTrue);
    expect(provider.error, isNull);
  });
  test('late response from a signed-out account is discarded', () async {
    final old = Completer<List<JournalEntry>>();
    service.load = (_) => old.future;
    final loading = provider.loadEntries('member-a');
    provider.setUser(null);
    old.complete([entry]);
    await loading;
    expect(provider.entries, isEmpty);
    expect(provider.hasLoaded, isFalse);
    expect(provider.loading, isFalse);
  });
  test('older refresh cannot overwrite a newer response', () async {
    final old = Completer<List<JournalEntry>>();
    service.load = (_) => old.future;
    final first = provider.loadEntries('member-a');
    service.load = (_) async => [];
    await provider.loadEntries('member-a');
    old.complete([entry]);
    await first;
    expect(provider.entries, isEmpty);
    expect(provider.hasLoaded, isTrue);
  });
}
