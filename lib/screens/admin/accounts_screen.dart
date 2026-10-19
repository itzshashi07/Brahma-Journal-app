import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_accounts_service.dart';
import '../../services/api_service.dart';
import '../../widgets/retry_notice.dart';
import '../../widgets/sacred.dart';

class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key, this.service});
  final AdminAccountsService? service;
  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  final _search = TextEditingController();
  late final _service = widget.service ?? AdminAccountsService();
  List<AdminAccount> _accounts = [];
  bool _loading = true, _loadingMore = false;
  String? _error, _moreError, _nextCursor;
  String _query = '';
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (!context.read<AuthProvider>().isAdmin) {
      setState(() => _loading = false);
      return;
    }
    if (more && (_loadingMore || _nextCursor == null)) return;
    final generation = more ? _generation : ++_generation;
    final cursor = more ? _nextCursor : null;
    if (!more) _query = _search.text.trim();
    setState(() {
      if (more) {
        _loadingMore = true;
        _moreError = null;
      } else {
        _loading = true;
        _loadingMore = false;
        _error = null;
        _moreError = null;
      }
    });
    try {
      final page = await _service.list(query: _query, cursor: cursor);
      if (!mounted || generation != _generation) return;
      setState(() {
        final combined =
            more ? [..._accounts, ...page.accounts] : page.accounts;
        _accounts = {for (final a in combined) a.uid: a}.values.toList();
        _nextCursor = page.nextCursor;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        final message = _failure(error, 'Could not load users. Please retry.');
        if (more) {
          _moreError = message;
        } else {
          _error = message;
        }
      });
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _open(AdminAccount account) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: AppTheme.bgDark,
        builder: (_) => FractionallySizedBox(
            heightFactor: .9,
            child: _AccountDetailsSheet(
                account: account, service: _service, onUpdated: () => _load())),
      );

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().isAdmin) {
      return const Scaffold(body: Center(child: Text('Admins only.')));
    }
    return Scaffold(
        body: SacredBackdrop(
            child: SafeArea(
                child: Column(children: [
      SacredAppBar(
          title: 'Manage users',
          subtitle: 'Accounts & access',
          onBack: () => context.pop(),
          action: IconButton(
              tooltip: 'Refresh users',
              onPressed: _loading ? null : () => _load(),
              icon: const Icon(Icons.refresh_rounded))),
      Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: TextField(
              key: const ValueKey('admin-user-search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                  labelText: 'Search name, email or user ID',
                  suffixIcon: IconButton(
                      tooltip: 'Search users',
                      onPressed: () => _load(),
                      icon: const Icon(Icons.search_rounded))))),
      Expanded(child: _body()),
    ]))));
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return Padding(
          padding: const EdgeInsets.all(24),
          child: RetryNotice(message: _error!, onRetry: () => _load()));
    return RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text(
                'Open a user to review their account, reset app data or manage access.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text('For an incomplete signup, search the exact email or user ID.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.textMuted)),
            const SizedBox(height: 20),
            if (_accounts.isEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(children: [
                    const Icon(Icons.person_search_outlined,
                        size: 42, color: AppTheme.textMuted),
                    const SizedBox(height: 12),
                    const Text('No users found.'),
                    if (_query.isNotEmpty)
                      TextButton(
                          onPressed: () {
                            _search.clear();
                            _load();
                          },
                          child: const Text('Show all users')),
                  ])),
            for (final account in _accounts)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                          key: ValueKey('admin-user-${account.uid}'),
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _open(account),
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                        account.protected
                                            ? Icons.shield_outlined
                                            : account.banned
                                                ? Icons.block_rounded
                                                : Icons.person_outline_rounded,
                                        color: account.banned
                                            ? Colors.orangeAccent
                                            : AppTheme.primaryLight),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(account.displayName,
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 4),
                                          Text(
                                              account.email.isEmpty
                                                  ? account.uid
                                                  : account.email,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                      AppTheme.textSecondary)),
                                          const SizedBox(height: 10),
                                          _AccountStatus(account: account),
                                        ])),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chevron_right_rounded,
                                        color: AppTheme.textMuted),
                                  ]))))),
            if (_moreError != null) ...[
              Text(_moreError!,
                  style: const TextStyle(color: Colors.orangeAccent)),
              const SizedBox(height: 8),
            ],
            if (_nextCursor != null)
              OutlinedButton(
                  key: const ValueKey('admin-load-more'),
                  onPressed: _loadingMore ? null : () => _load(more: true),
                  child: _loadingMore
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_moreError == null
                          ? 'Load more users'
                          : 'Retry loading more')),
          ],
        ));
  }
}

class _AccountStatus extends StatelessWidget {
  const _AccountStatus({required this.account});
  final AdminAccount account;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 6, children: [
        Text(account.status,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: account.banned || account.cleanupPending
                    ? Colors.orangeAccent
                    : AppTheme.success)),
        if (account.protected)
          const Text('Protected account',
              style: TextStyle(fontSize: 12, color: AppTheme.primaryLight)),
      ]);
}

class _AccountDetailsSheet extends StatefulWidget {
  const _AccountDetailsSheet(
      {required this.account, required this.service, required this.onUpdated});
  final AdminAccount account;
  final AdminAccountsService service;
  final VoidCallback onUpdated;
  @override
  State<_AccountDetailsSheet> createState() => _AccountDetailsSheetState();
}

class _AccountDetailsSheetState extends State<_AccountDetailsSheet> {
  AdminAccountDetails? _details;
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final details = await widget.service.details(widget.account.uid);
      if (mounted) setState(() => _details = details);
    } catch (error) {
      if (mounted)
        setState(
            () => _error = _failure(error, 'Could not load account details.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(String action) async {
    final completed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AccountActionDialog(
            account: _details!.account,
            action: action,
            service: widget.service));
    if (!mounted || completed != true) return;
    widget.onUpdated();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(switch (action) {
      'delete' => 'Account and app data deleted. Action recorded.',
      'reset_data' => 'App data reset. Sign-in account kept. Action recorded.',
      'ban' => 'Account banned. Action recorded.',
      _ => 'Account access restored. Action recorded.',
    })));
    if (action == 'delete') {
      Navigator.of(context).pop();
    } else {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = _details?.account ?? widget.account;
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 12, 8),
          child: Row(children: [
            const Expanded(
                child: Text('User details',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
            IconButton(
                tooltip: 'Close user details',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded)),
          ])),
      Expanded(
          child: ListView(
              key: const ValueKey('admin-user-details-list'),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
            Text(account.displayName,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _AccountStatus(account: account),
            const SizedBox(height: 24),
            if (account.email.isNotEmpty) _detail('Email', account.email),
            _detail('User ID', account.uid),
            if (account.createdAt != null)
              _detail('Joined',
                  DateFormat.yMMMd().format(account.createdAt!.toLocal())),
            if (_loading)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              RetryNotice(message: _error!, onRetry: _load)
            else ...[
              const SizedBox(height: 8),
              const Text('App data',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                  'Activity counts only. Private writing is not shown here.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
              const SizedBox(height: 12),
              for (final entry in const {
                'journalEntries': 'Journal entries',
                'smallWins': 'Small wins',
                'thoughts': 'Anonymous thoughts',
                'replies': 'Community replies',
                'counsellingSessions': 'Counselling requests',
                'gameScores': 'Game scores',
              }.entries)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(children: [
                      Expanded(
                          child: Text(entry.value,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary))),
                      const SizedBox(width: 12),
                      Text('${_details!.summary[entry.key] ?? 0}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ])),
              const Divider(height: 32),
              if (account.protected)
                const Text(
                    'Your account and administrator accounts are protected from these actions.',
                    style: TextStyle(color: AppTheme.textSecondary))
              else ...[
                if (account.cleanupPending) ...[
                  const Text(
                      'A previous cleanup did not finish. Access stays blocked until cleanup is complete.',
                      style: TextStyle(color: Colors.orangeAccent)),
                  const SizedBox(height: 16),
                ],
                if (!account.cleanupPending && !account.identityMissing)
                  _actionButton(
                      account.banned ? 'Restore access' : 'Ban account',
                      account.banned
                          ? Icons.lock_open_rounded
                          : Icons.block_rounded,
                      account.banned ? 'unban' : 'ban'),
                if (!account.identityMissing &&
                    (!account.cleanupPending ||
                        account.pendingAction == 'reset_data')) ...[
                  const SizedBox(height: 8),
                  _actionButton(
                      account.cleanupPending
                          ? 'Retry data reset'
                          : 'Reset app data',
                      Icons.restart_alt_rounded,
                      'reset_data'),
                  const Padding(
                      padding: EdgeInsets.only(top: 6, bottom: 12),
                      child: Text(
                          'Delete app activity and content. Keep the sign-in account.',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted))),
                ],
                if (!account.cleanupPending ||
                    account.pendingAction == 'delete')
                  _actionButton(
                      account.identityMissing
                          ? 'Delete remaining app data'
                          : account.cleanupPending
                              ? 'Retry account deletion'
                              : 'Delete account permanently',
                      Icons.delete_outline_rounded,
                      'delete',
                      danger: true),
                const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                        'Purchase, moderation and security records are retained.',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textMuted))),
              ],
            ],
          ])),
    ]);
  }

  Widget _detail(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        const SizedBox(height: 4),
        SelectableText(value, style: const TextStyle(fontSize: 14)),
      ]));

  Widget _actionButton(String label, IconData icon, String action,
          {bool danger = false}) =>
      OutlinedButton.icon(
        key: ValueKey('admin-action-$action'),
        onPressed: () => _act(action),
        icon: Icon(icon, size: 20),
        label: Text(label, textAlign: TextAlign.center),
        style: OutlinedButton.styleFrom(
            foregroundColor: danger ? Colors.redAccent.shade100 : null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      );
}

class _AccountActionDialog extends StatefulWidget {
  const _AccountActionDialog(
      {required this.account, required this.action, required this.service});
  final AdminAccount account;
  final String action;
  final AdminAccountsService service;
  @override
  State<_AccountActionDialog> createState() => _AccountActionDialogState();
}

class _AccountActionDialogState extends State<_AccountActionDialog> {
  final _confirmation = TextEditingController();
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _confirmation.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.act(
          uid: widget.account.uid,
          action: widget.action,
          reason: _reason.text.trim(),
          confirmation: _confirmation.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = _failure(error,
              'Could not complete this action. Your confirmation is kept; please retry.');
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final target = widget.account.confirmation;
    final label = switch (action) {
      'delete' => widget.account.identityMissing
          ? 'Delete remaining data'
          : 'Delete permanently',
      'reset_data' => 'Reset app data',
      'ban' => 'Ban account',
      _ => 'Restore access',
    };
    return PopScope(
        canPop: !_busy,
        child: AlertDialog(
          title: Text('$label?'),
          content: SingleChildScrollView(
              child: Form(
                  key: _form,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(target,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Text(switch (action) {
                          'delete' => widget.account.identityMissing
                              ? 'Sign-in is already removed. Permanently delete this user’s remaining app data, including journals, small wins, community posts and replies, and counselling conversations. This cannot be undone.'
                              : 'Permanently delete this user’s sign-in account and app data, including journals, small wins, community posts and replies, and counselling conversations. This cannot be undone.',
                          'reset_data' =>
                            'Permanently delete this user’s app activity and content, including journals, small wins, community posts and replies, and counselling conversations. Keep their sign-in, basic profile (name, email, age, gender and phone) and current ban status. This cannot be undone.',
                          'ban' =>
                            'Block sign-in and app access. App data stays saved, and you can restore access later.',
                          _ =>
                            'Allow this member to sign in and use the app again.',
                        }),
                        if (action == 'delete' || action == 'reset_data')
                          const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                  'Purchase, moderation and security records are retained.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textMuted))),
                        const SizedBox(height: 16),
                        TextFormField(
                            key: const ValueKey('admin-action-reason'),
                            controller: _reason,
                            enabled: !_busy,
                            maxLength: 500,
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                                labelText: 'Reason for this action',
                                helperText: 'Saved in the admin audit log'),
                            validator: (value) =>
                                (value ?? '').trim().length < 3
                                    ? 'Enter a reason (at least 3 characters).'
                                    : null),
                        const SizedBox(height: 12),
                        TextFormField(
                            key: const ValueKey('admin-action-confirmation'),
                            controller: _confirmation,
                            enabled: !_busy,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                                labelText: widget.account.email.isEmpty
                                    ? 'Type user ID to confirm'
                                    : 'Type email to confirm'),
                            validator: (value) => value?.trim() == target
                                ? null
                                : 'Enter the exact ${widget.account.email.isEmpty ? 'user ID' : 'email'} shown above.'),
                        if (_busy)
                          const Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: Text(
                                  'Updating account. Large cleanups can take a little longer.',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary))),
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: Colors.orangeAccent))),
                      ]))),
          actions: [
            TextButton(
                onPressed:
                    _busy ? null : () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            FilledButton(
                key: const ValueKey('admin-confirm-action'),
                onPressed: _busy ? null : _submit,
                style: action == 'delete' || action == 'reset_data'
                    ? FilledButton.styleFrom(backgroundColor: AppTheme.danger)
                    : null,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(label)),
          ],
        ));
  }
}

String _failure(Object error, String fallback) =>
    error is ApiException ? error.message : fallback;
