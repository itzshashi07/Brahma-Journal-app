import 'api_service.dart';

class SmallWinsService {
  final _api = ApiService();
  Future<List<Map<String, dynamic>>> load() async {
    final body = await _api.get('/api/small-wins');
    return ((body?['entries'] as List?) ?? [])
        .map((v) => Map<String, dynamic>.from(v))
        .toList();
  }

  Future<void> save(
      {required String day,
      required String gratitude,
      required String smallWin,
      required String nextStep}) async {
    await _api.put('/api/small-wins', {
      'day': day,
      'gratitude': gratitude,
      'smallWin': smallWin,
      'nextStep': nextStep
    });
  }
}
