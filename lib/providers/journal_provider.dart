import 'package:flutter/foundation.dart';
import '../services/journal_service.dart';
import '../models/journal_entry.dart';

class JournalProvider extends ChangeNotifier {
  final JournalService _service = JournalService();

  List<JournalEntry> _entries = [];
  JournalEntry? _todaysEntry;
  int _streak = 0;
  bool _loading = false;

  List<JournalEntry> get entries => _entries;
  JournalEntry? get todaysEntry => _todaysEntry;
  int get streak => _streak;
  bool get loading => _loading;

  Future<void> loadEntries(String uid) async {
    _loading = true;
    notifyListeners();
    _entries = await _service.getEntries(uid);
    _todaysEntry = await _service.getTodaysEntry(uid);
    _streak = await _service.calculateStreak(uid);
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
    notifyListeners();
  }
}
