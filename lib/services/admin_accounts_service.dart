import 'api_service.dart';

class AdminAccount {
  const AdminAccount(
      {required this.uid,
      required this.name,
      required this.email,
      this.createdAt,
      this.banned = false,
      this.protected = false,
      this.identityMissing = false,
      this.cleanupPending = false,
      this.pendingAction});

  factory AdminAccount.fromJson(Map<String, dynamic> json) => AdminAccount(
        uid: '${json['firebaseUid'] ?? ''}',
        name: '${json['name'] ?? ''}'.trim(),
        email: '${json['email'] ?? ''}'.trim(),
        createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
        banned: json['banned'] == true,
        protected: json['protected'] == true,
        identityMissing: json['identityMissing'] == true,
        cleanupPending: json['cleanupPending'] == true,
        pendingAction: json['pendingAction'] as String?,
      );

  final String uid, name, email;
  final DateTime? createdAt;
  final bool banned, protected, identityMissing, cleanupPending;
  final String? pendingAction;
  String get displayName => name.isEmpty ? 'Member' : name;
  String get confirmation => email.isEmpty ? uid : email;
  String get status => cleanupPending
      ? 'Cleanup pending'
      : identityMissing
          ? 'Sign-in removed'
          : banned
              ? 'Banned'
              : 'Active';
}

class AdminAccountsPage {
  const AdminAccountsPage({required this.accounts, this.nextCursor});
  final List<AdminAccount> accounts;
  final String? nextCursor;
}

class AdminAccountDetails {
  const AdminAccountDetails({required this.account, required this.summary});
  final AdminAccount account;
  final Map<String, int> summary;
}

/// All authorization and deletion checks remain on the server.
class AdminAccountsService {
  Future<AdminAccountsPage> list({String query = '', String? cursor}) async {
    final body = await ApiService().get('/api/admin/accounts', query: {
      'q': query,
      'limit': '25',
      if (cursor != null) 'cursor': cursor,
    });
    return AdminAccountsPage(
      accounts: ((body?['accounts'] as List?) ?? [])
          .map((value) =>
              AdminAccount.fromJson(Map<String, dynamic>.from(value)))
          .toList(),
      nextCursor:
          body?['hasMore'] == true ? (body?['nextCursor'] as String?) : null,
    );
  }

  Future<AdminAccountDetails> details(String uid) async {
    final body = await ApiService()
        .get('/api/admin/accounts/${Uri.encodeComponent(uid)}');
    return AdminAccountDetails(
      account:
          AdminAccount.fromJson(Map<String, dynamic>.from(body['account'])),
      summary: Map<String, dynamic>.from(body['summary'] ?? {})
          .map((key, value) => MapEntry(key, (value as num).toInt())),
    );
  }

  Future<void> act(
      {required String uid,
      required String action,
      required String reason,
      required String confirmation}) async {
    await ApiService().postWithTimeout(
        '/api/admin/accounts/${Uri.encodeComponent(uid)}/action',
        {
          'action': action,
          'reason': reason,
          'confirmation': confirmation,
        },
        timeout: const Duration(seconds: 90));
  }
}
