import 'package:flutter/foundation.dart';
import '../services/journal_service.dart';
import '../services/streak_service.dart';
import '../models/journal_entry.dart';

class JournalProvider extends ChangeNotifier {
  final JournalService _service = JournalService();
  final StreakService _streaks = StreakService();

  List<JournalEntry> _entries = [];
  JournalEntry? _todaysEntry;
  int _streak = 0;
  bool _loading = false;
  List<DateTime> _recoveredDays = const [];

  List<JournalEntry> get entries => _entries;
  JournalEntry? get todaysEntry => _todaysEntry;
  int get streak => _streak;
  bool get loading => _loading;

  /// Days forgiven by a streak recovery.
  List<DateTime> get recoveredDays => _recoveredDays;

  /// Every day this member actually wrote something. What the recovery card
  /// inspects to find a one-day gap, so it does not re-query the entries.
  List<DateTime> get entryDates =>
      _entries.map((e) => e.createdAt).toList(growable: false);

  /// Loads the user's entries once and derives today's entry and the streak
  /// from that single result. Previously each of the three ran its own
  /// identical Firestore query, so the screen showed stale/blank stats while
  /// two redundant round trips finished.
  Future<void> loadEntries(String uid) async {
    _loading = true;
    notifyListeners();
    _entries = await _service.getEntries(uid);
    _todaysEntry = _service.todaysEntryFrom(_entries);
    // Forgiven days are part of the streak the dashboard shows, or a member
    // would spend their monthly recovery and watch the number stay broken
    // until some other screen happened to resync their profile.
    _recoveredDays = await _streaks.recoveredDays(uid);
    _streak = _service.streakForEntries(_entries, recoveredDays: _recoveredDays);
    _loading = false;
    notifyListeners();
  }

  Future<String> saveEntry(JournalEntry entry, {String? existingId}) async {
    final id = await _service.saveEntry(entry, existingEntryId: existingId);
    await loadEntries(entry.uid);
    return id;
  }

  void clear() {
    _entries = [];
    _todaysEntry = null;
    _streak = 0;
    _recoveredDays = const [];
    notifyListeners();
  }
}
