import 'package:flutter/foundation.dart';
import '../services/journal_service.dart';
import '../services/streak_service.dart';
import '../models/journal_entry.dart';

class JournalProvider extends ChangeNotifier {
  JournalProvider({JournalService? service, StreakService? streaks})
      : _service = service ?? JournalService(),
        _streaks = streaks ?? StreakService();

  final JournalService _service;
  final StreakService _streaks;
  String? _uid;
  String? _error;
  bool _hasLoaded = false;
  int _generation = 0;
  bool _disposed = false;

  List<JournalEntry> _entries = [];
  int _streak = 0;
  bool _loading = false;
  List<DateTime> _recoveredDays = const [];

  List<JournalEntry> get entries => _entries;
  JournalEntry? get todaysEntry => _service.todaysEntryFrom(_entries);
  int get streak => _streak;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasLoaded => _hasLoaded;

  void setUser(String? uid) {
    if (_uid == uid) return;
    _uid = uid;
    clear();
  }

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
    setUser(uid);
    final generation = ++_generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      // These independent reads used to run one after the other.
      final results = await Future.wait<Object>([
        _service.getEntries(uid),
        _streaks.recoveredDays(uid),
      ]);
      if (_disposed || generation != _generation) return;
      _entries = results[0] as List<JournalEntry>;
      _recoveredDays = results[1] as List<DateTime>;
      _streak =
          _service.streakForEntries(_entries, recoveredDays: _recoveredDays);
      _hasLoaded = true;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _error =
          'We couldn’t refresh your journal. Check your connection and try again.';
    } finally {
      if (!_disposed && generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<String> saveEntry(JournalEntry entry, {String? existingId}) async {
    final uid = _uid;
    final id = await _service.saveEntry(entry, existingEntryId: existingId);
    if (!_disposed && _uid == uid) await loadEntries(entry.uid);
    return id;
  }

  void clear() {
    _generation++;
    _loading = false;
    _hasLoaded = false;
    _error = null;
    _entries = [];
    _streak = 0;
    _recoveredDays = const [];
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
