import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/notification_routes.dart';
import '../../models/announcement.dart';
import '../../models/app_notification.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_messaging_service.dart';
import '../../services/notification_center.dart';
import '../../services/notification_service.dart';
import '../../widgets/retry_notice.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.service, this.updates});

  final NotificationService? service;
  final Stream<Object?>? updates;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final NotificationService _service;
  TabController? _tabs;
  StreamSubscription<Object?>? _pushSub;
  Future<List<AppNotification>>? _notifications;
  Future<List<Announcement>>? _announcements;
  Future<List<Map<String, dynamic>>>? _adminAlerts;
  final Set<String> _removed = {};
  bool _clearing = false;
  int _lastTab = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? NotificationService();
    _pushSub = (widget.updates ?? FirebaseMessagingService().messages)
        .listen((_) => _invalidateFeeds());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationCenter>().markAllRead();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tabs == null) {
      _tabs = TabController(
        length: context.read<AuthProvider>().isAdmin ? 3 : 2,
        vsync: this,
      )..addListener(() {
          if (_tabs!.indexIsChanging || _tabs!.index == _lastTab) return;
          _lastTab = _tabs!.index;
          // Work may have been handled in another screen or on another device.
          if (_lastTab == 2) unawaited(_refresh('admin'));
        });
    }
  }

  // Retain each request across removal and badge rebuilds. Only a new push or
  // an explicit refresh asks for the feed again, so removal never flashes a
  // loading screen or sends another request for every remaining card.
  void _invalidateFeeds() {
    if (!mounted) return;
    setState(() {
      _notifications = null;
      _announcements = null;
      _adminAlerts = null;
    });
  }

  Future<void> _refresh(String kind) async {
    if (!mounted) return;
    late Future<dynamic> next;
    setState(() {
      switch (kind) {
        case 'broadcast':
          next = _notifications = _service.fetchNotifications();
          break;
        case 'announcement':
          next = _announcements = _service.fetchAnnouncements();
          break;
        default:
          next = _adminAlerts = _service.fetchAdminAlerts();
      }
    });
    // The FutureBuilder shows an actionable error without an unhandled pull
    // to refresh exception.
    try {
      await next;
    } catch (_) {}
  }

  bool _isRemoved(String kind, String id) => _removed.contains('$kind:$id');

  Future<void> _remove(String kind, String id) async {
    if (id.isEmpty || _isRemoved(kind, id)) return;
    final key = '$kind:$id';
    setState(() => _removed.add(key));
    try {
      await _service.dismissNotification(kind, id);
      if (mounted) context.read<NotificationCenter>().refresh();
    } catch (_) {
      if (!mounted) return;
      setState(() => _removed.remove(key));
      _showFailure('Could not remove this update. Please try again.');
    }
  }

  void _showFailure(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _clearVisibleFeed() async {
    if (_clearing) return;
    final kind = ['broadcast', 'announcement', 'admin'][_tabs!.index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear this list?'),
        content: const Text(
          'These updates will be removed from your account on every device. '
          'Other people’s updates and your conversations stay unchanged.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear list')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearing = true);
    try {
      if (kind == 'admin') {
        final alerts = await (_adminAlerts ??= _service.fetchAdminAlerts());
        await Future.wait(alerts.map((alert) {
          final id = '${alert['_id'] ?? alert['id'] ?? ''}';
          return id.isEmpty
              ? Future<void>.value()
              : _service.dismissNotification('admin', id);
        }));
      } else {
        await _service.dismissAll(kind);
      }
      if (!mounted) return;
      await _refresh(kind);
      if (mounted) context.read<NotificationCenter>().refresh();
    } catch (_) {
      if (mounted) _showFailure('Could not clear this list. Please try again.');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _deleteForEveryone(String kind, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete for everyone?'),
        content: const Text(
            'This permanently removes this update from every account. It cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete for everyone'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final key = '$kind:$id';
    setState(() => _removed.add(key));
    try {
      if (kind == 'broadcast') {
        await _service.deleteNotification(id);
      } else {
        await _service.deleteAnnouncement(id);
      }
      if (mounted) context.read<NotificationCenter>().refresh();
    } catch (_) {
      if (!mounted) return;
      setState(() => _removed.remove(key));
      _showFailure('Could not delete this update. Please try again.');
    }
  }

  @override
  void dispose() {
    _pushSub?.cancel();
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(children: [
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.pop(),
                ),
                const Expanded(
                    child: Text('Your updates',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700))),
                IconButton(
                  tooltip: 'Clear this list',
                  onPressed: _clearing ? null : _clearVisibleFeed,
                  icon: _clearing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.playlist_remove_rounded),
                ),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    'Catch up, then remove anything you no longer need.',
                    style:
                        TextStyle(color: AppTheme.textSecondary, height: 1.4)),
              ),
            ),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              tabs: [
                const Tab(text: 'Notifications'),
                const Tab(text: 'Announcements'),
                if (isAdmin) const Tab(text: 'Admin alerts'),
              ],
            ),
            Expanded(
              child: TabBarView(controller: _tabs, children: [
                _notificationFeed(isAdmin),
                _announcementFeed(isAdmin),
                if (isAdmin) _adminFeed(),
              ]),
            ),
          ]),
        ),
      ),
      floatingActionButton: isAdmin
          ? AnimatedBuilder(
              animation: _tabs!,
              builder: (context, _) => _tabs!.index == 1
                  ? FloatingActionButton.extended(
                      onPressed: () => context.push('/announcements/create'),
                      icon: const Icon(Icons.add),
                      label: const Text('Announcement'),
                    )
                  : const SizedBox.shrink(),
            )
          : null,
    );
  }

  Widget _feed<T>({
    required String kind,
    required Future<List<T>> future,
    required String Function(T) id,
    required Widget Function(T) card,
  }) {
    return FutureBuilder<List<T>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Padding(
            padding: const EdgeInsets.all(20),
            child: RetryNotice(
              message:
                  'Your updates could not load. Please check your connection and try again.',
              onRetry: () => _refresh(kind),
            ),
          ));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!
            .where((item) => !_isRemoved(kind, id(item)))
            .toList();
        return RefreshIndicator(
          onRefresh: () => _refresh(kind),
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(32),
                  children: const [
                      SizedBox(height: 56),
                      Icon(Icons.notifications_none_rounded,
                          size: 48, color: AppTheme.textMuted),
                      SizedBox(height: 16),
                      Text('You’re all caught up',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Text('New updates will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ])
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: items.length,
                  itemBuilder: (_, index) => card(items[index]),
                ),
        );
      },
    );
  }

  Widget _notificationFeed(bool isAdmin) => Builder(
      builder: (_) => _feed<AppNotification>(
            kind: 'broadcast',
            future: _notifications ??= _service.fetchNotifications(),
            id: (item) => item.id,
            card: (item) => _card(
              kind: 'broadcast',
              id: item.id,
              title: item.title,
              body: item.body,
              date: item.createdAt,
              icon: Icons.notifications_outlined,
              route: appRouteFor(item.route),
              canDeleteGlobally: isAdmin,
            ),
          ));

  Widget _announcementFeed(bool isAdmin) => Builder(
      builder: (_) => _feed<Announcement>(
            kind: 'announcement',
            future: _announcements ??= _service.fetchAnnouncements(),
            id: (item) => item.id,
            card: (item) => _card(
              kind: 'announcement',
              id: item.id,
              title: item.title,
              body: item.content,
              date: item.createdAt,
              icon: Icons.campaign_outlined,
              author: item.authorName,
              canDeleteGlobally: isAdmin,
            ),
          ));

  Widget _adminFeed() => Builder(
      builder: (_) => _feed<Map<String, dynamic>>(
            kind: 'admin',
            future: _adminAlerts ??= _service.fetchAdminAlerts(),
            id: (item) => '${item['_id'] ?? item['id'] ?? ''}',
            card: (item) => _card(
              kind: 'admin',
              id: '${item['_id'] ?? item['id'] ?? ''}',
              title: '${item['title'] ?? 'Alert'}',
              body: '${item['body'] ?? ''}',
              date: DateTime.tryParse('${item['createdAt'] ?? ''}'),
              icon: Icons.support_agent_rounded,
              route: appRouteFor('${item['route'] ?? ''}', isAdminAlert: true),
              email: '${item['subjectEmail'] ?? item['userEmail'] ?? ''}',
            ),
          ));

  Widget _card({
    required String kind,
    required String id,
    required String title,
    required String body,
    required DateTime? date,
    required IconData icon,
    String? route,
    String? author,
    String? email,
    bool canDeleteGlobally = false,
  }) =>
      Card(
        key: ValueKey('$kind:$id'),
        margin: const EdgeInsets.only(bottom: 12),
        color: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppTheme.border)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: AppTheme.primary, size: 23),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          height: 1.3))),
              if (canDeleteGlobally)
                PopupMenuButton<String>(
                  tooltip: 'Admin options',
                  padding: EdgeInsets.zero,
                  onSelected: (_) => _deleteForEveryone(kind, id),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'delete', child: Text('Delete for everyone'))
                  ],
                ),
            ]),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(body,
                  style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppTheme.textSecondary)),
            ],
            const SizedBox(height: 12),
            Text(
                [
                  if (author?.isNotEmpty == true) 'By $author',
                  if (date != null)
                    DateFormat('dd MMM, h:mm a').format(date.toLocal()),
                ].join(' · '),
                style:
                    const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              if (route?.isNotEmpty == true)
                TextButton.icon(
                    onPressed: () => context.push(route!),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Open')),
              TextButton.icon(
                key: ValueKey('remove-$kind-$id'),
                onPressed: id.isEmpty ? null : () => _remove(kind, id),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Remove'),
              ),
              if (email?.isNotEmpty == true)
                TextButton.icon(
                  onPressed: () => SharePlus.instance.share(ShareParams(
                      text:
                          'Please invite this user to Firebase App Distribution:\n$email')),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share email'),
                ),
            ]),
          ]),
        ),
      );
}
