import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/notification_routes.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/firebase_messaging_service.dart';
import '../../services/notification_service.dart';
import '../../services/notification_center.dart';
import '../../models/app_notification.dart';
import '../../models/announcement.dart';
import 'package:share_plus/share_plus.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  /// Held so `FutureBuilder` does not re-fetch on every rebuild of the tab.
  Future<List<Map<String, dynamic>>>? _adminAlerts;

  late TabController _tabController;
  final NotificationService _notificationService = NotificationService();
  /// Ids removed in this session, so a card disappears the instant it is
  /// tapped rather than after the refetch. The server is the record; this is
  /// only what keeps the tap from feeling laggy.
  final Set<String> _justDismissed = {};

  /// Bumped to rebuild the feeds. `Stream.fromFuture` is one-shot, so a
  /// `StreamBuilder` keyed on nothing would show whatever it fetched when the
  /// screen opened until the member navigated away and back.
  int _feedVersion = 0;

  /// A notification arriving while this screen is open should appear on it.
  ///
  /// Push is what makes the app live — there is no polling anywhere in this
  /// codebase and there should not be. But the delivery only raised a tray
  /// notification and refreshed the badge; the list the member was looking at
  /// stayed as it was, so the screen that exists to show notifications was the
  /// one place a new notification did not appear.
  StreamSubscription? _pushSub;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _pushSub = FirebaseMessagingService().messages.listen((_) {
      if (mounted) setState(() => _feedVersion++);
    });

    // Opening this screen is what "seeing" a notification means, so the red
    // badge on the dashboard clears here rather than on each item tapped.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationCenter>().markAllRead();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final isAdmin = context.read<AuthProvider>().isAdmin;
      _tabController = TabController(length: isAdmin ? 3 : 2, vsync: this);

      /// Refetch the operator queue every time it is opened.
      ///
      /// It was fetched once and then never again for the life of the screen,
      /// which is how it drifted out of step with a queue that three other
      /// surfaces can also delete from — and a drifted list is one whose rows
      /// cannot be dismissed, because their ids are gone. Switching to the tab
      /// is the moment somebody expects to be looking at the current thing.
      if (isAdmin) {
        _tabController.addListener(() {
          if (!_tabController.indexIsChanging &&
              _tabController.index == 2 &&
              mounted) {
            _refreshAdminAlerts();
          }
        });
      }

      _initialized = true;
    }
  }

  /// Removes one card from this member's feed, on the server.
  ///
  /// Optimistic: the card goes immediately and comes back with a message if
  /// the request fails. Waiting on a round trip to acknowledge a delete makes
  /// a list feel broken on a slow connection, and this is a list people clear
  /// ten items at a time.
  Future<void> _dismiss(String kind, String id) async {
    setState(() => _justDismissed.add(id));
    try {
      await _notificationService.dismissNotification(kind, id);
      if (mounted) context.read<NotificationCenter>().refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _justDismissed.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not remove that. Try again in a moment.',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Clears whichever list is on screen.
  ///
  /// A dismissal, not a delete, on the two member feeds — a broadcast is one
  /// document everybody reads, so removing it would remove it for the whole
  /// user base. It is permanent for *this* member all the same: the server
  /// keeps the record, every feed filters against it, and it survives a
  /// reinstall and a second handset. See notification_service.dart.
  ///
  /// The operator queue is the exception, and clears by really deleting each
  /// alert — those are work items belonging to whoever is on duty, and the
  /// durable record is the session or the ticket they point at.
  Future<void> _clearVisibleFeed() async {
    final tab = _tabController.index;
    final isAdminTab = tab == 2;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isAdminTab ? 'Clear the queue?' : 'Clear this list?',
            style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary)),
        content: Text(
          isAdminTab
              ? 'Every alert here is deleted. The sessions and tickets they point at are not touched.'
              : 'Everything currently in this list is removed for good — on this phone and on every other device you sign in on.',
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Clear',
                style: TextStyle(fontFamily: 'Outfit', color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      if (isAdminTab) {
        // One delete per alert, issued together. There is no bulk route for
        // these and there should not be — an alert is a unit of work, and a
        // server-side "delete everything" is one mis-tap away from losing a
        // queue nobody has read.
        final alerts = await (_adminAlerts ?? _loadAdminAlerts());
        final ids = alerts
            .map((a) => (a['_id'] ?? a['id'] ?? '').toString())
            .where((id) => id.isNotEmpty);

        await Future.wait(
          ids.map((id) => ApiService().delete('/api/notifications/admin/$id')),
        );
        await _refreshAdminAlerts();
      } else {
        await _notificationService
            .dismissAll(tab == 0 ? 'broadcast' : 'announcement');
      }

      if (!mounted) return;
      setState(() => _feedVersion++);
      context.read<NotificationCenter>().refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not clear that just now.',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Deletes a broadcast for the entire user base. Admin only.
  ///
  /// The X beside it is the member's own "not for me"; this is "this should
  /// not exist" — a test notification, or one pointing at an article that has
  /// been taken down. Announcements have had it; the feed that actually raises
  /// the badge had no way to take anything back at all.
  Future<void> _confirmDeleteNotification(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete for everyone?',
            style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary)),
        content: const Text(
          'This removes the notification from every member\'s feed, permanently. '
          'It cannot be undone.',
          style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete',
                style: TextStyle(fontFamily: 'Outfit', color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _justDismissed.add(id));
    try {
      await _notificationService.deleteNotification(id);
      if (!mounted) return;
      setState(() => _feedVersion++);
      context.read<NotificationCenter>().refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _justDismissed.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete: $e',
              style: const TextStyle(fontFamily: 'Outfit')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pushSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
                      onPressed: () => context.pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Updates & News',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Clear the list this tab is showing.
                    //
                    // Deleting one at a time is fine for one; a member who has
                    // been away for a fortnight is looking at twenty and wants
                    // them gone, and tapping twenty × is how "I deleted them
                    // and they are still there" starts — because it is slow
                    // enough that somebody gives up halfway and concludes it
                    // did not work.
                    IconButton(
                      icon: const Icon(Icons.playlist_remove_rounded,
                          color: AppTheme.textMuted, size: 22),
                      tooltip: 'Clear this list',
                      onPressed: _clearVisibleFeed,
                    ),
                  ],
                ),
              ),

              // Tab Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.primary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppTheme.textPrimary,
                  unselectedLabelColor: AppTheme.textMuted,
                  labelStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16),
                  unselectedLabelStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 16),
                  dividerColor: const Color(0xFF2D2D4E),
                  tabs: [
                    const Tab(text: 'Notifications'),
                    const Tab(text: 'Announcements'),
                    if (auth.isAdmin) const Tab(text: 'Admin Alerts'),
                  ],
                ),
              ),

              // Tab View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNotificationsTab(),
                    _buildAnnouncementsTab(auth.isAdmin),
                    if (auth.isAdmin) _buildAdminAlertsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: auth.isAdmin
          ? ValueListenableBuilder<double>(
              valueListenable: _tabController.animation!,
              builder: (context, animValue, child) {
                // Only show fab when on the second tab (Announcements)
                final showFab = animValue >= 0.5;
                return showFab
                    ? FloatingActionButton.extended(
                        onPressed: () => context.push('/announcements/create'),
                        backgroundColor: AppTheme.primary,
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text('Add Announcement', style: TextStyle(fontFamily: 'Outfit', color: Colors.white)),
                      )
                    : const SizedBox.shrink();
              },
            )
          : null,
    );
  }

  Widget _buildNotificationsTab() {
    return StreamBuilder<List<AppNotification>>(
      key: ValueKey('notifications-$_feedVersion'),
      stream: _notificationService.streamNotifications(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent, fontFamily: 'Outfit')));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final notifications = snapshot.data ?? [];
        final activeNotifications = notifications
            .where((n) => !_justDismissed.contains(n.id))
            .toList();

        if (activeNotifications.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 64, color: AppTheme.textMuted),
                SizedBox(height: 16),
                Text('No notifications yet.', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeNotifications.length,
          itemBuilder: (context, index) {
            final notification = activeNotifications[index];
            return _buildNotificationCard(notification);
          },
        );
      },
    );
  }

  Widget _buildNotificationCard(AppNotification notification) {
    IconData icon;
    Color color;

    switch (notification.type) {
      case 'blog':
        icon = Icons.article_outlined;
        color = const Color(0xFFEC4899);
        break;
      case 'community':
        icon = Icons.people_outline;
        color = const Color(0xFF7C3AED);
        break;
      case 'library':
        icon = Icons.shopping_bag_outlined;
        color = const Color(0xFF10B981);
        break;
      case 'announcement':
        icon = Icons.campaign_outlined;
        color = const Color(0xFFD97706);
        break;
      default:
        icon = Icons.notifications_outlined;
        color = AppTheme.primary;
    }

    final formattedTime = DateFormat('dd MMM yyyy, hh:mm a').format(notification.createdAt);

    // No swipe.
    //
    // A card that also navigates on tap and scrolls in a list gives a swipe
    // three things to be confused with, and the one that deletes is the only
    // one that cannot be undone. It was also invisible: nothing on the screen
    // said the gesture existed. A button is discoverable, reachable with one
    // thumb, and impossible to trigger by accident while scrolling.
    return Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2D2D4E)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            notification.title,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notification.body,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formattedTime,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          // The same two-delete pattern the announcements tab has always had.
          // The X is "not for me" and is permanent for this account on every
          // device; the bin, for an operator, takes the notification off
          // everybody's feed.
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppTheme.textMuted, size: 20),
                tooltip: 'Remove from my list',
                onPressed: () => _dismiss('broadcast', notification.id),
              ),
              if (context.read<AuthProvider>().isAdmin)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 20),
                  tooltip: 'Delete for everyone',
                  onPressed: () => _confirmDeleteNotification(notification.id),
                ),
            ],
          ),
          onTap: () {
            // Through the same table as a tray tap. A broadcast's route is
            // this app's already, but "the card and the notification for it go
            // to the same place" is a property worth having by construction.
            final route = appRouteFor(notification.route);
            if (route != null) context.push(route);
          },
        ),
      );
  }

  Widget _buildAnnouncementsTab(bool isAdmin) {
    return StreamBuilder<List<Announcement>>(
      key: ValueKey('announcements-$_feedVersion'),
      stream: _notificationService.streamAnnouncements(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent, fontFamily: 'Outfit')));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final announcements = (snapshot.data ?? [])
            .where((a) => !_justDismissed.contains(a.id))
            .toList();
        if (announcements.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.campaign_outlined, size: 64, color: AppTheme.textMuted),
                SizedBox(height: 16),
                Text('No announcements yet.', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: announcements.length,
          itemBuilder: (context, index) {
            final announcement = announcements[index];
            return _buildAnnouncementCard(announcement, isAdmin);
          },
        );
      },
    );
  }

  Widget _buildAnnouncementCard(Announcement announcement, bool isAdmin) {
    final formattedTime = DateFormat('dd MMM yyyy, hh:mm a').format(announcement.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D2D4E)),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFD97706).withOpacity(0.05),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.campaign, color: Color(0xFFD97706), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement.title,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'By ${announcement.authorName} • $formattedTime',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Two different deletes, and the difference matters.
              //
              // The X removes it from this member's own list. The bin, for an
              // admin, removes the announcement itself for everybody — so it
              // asks first, and it is a different icon in a different colour
              // rather than the same button meaning two things depending on
              // who is holding the phone.
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppTheme.textMuted, size: 20),
                tooltip: 'Remove from my list',
                onPressed: () => _dismiss('announcement', announcement.id),
              ),
              if (isAdmin) ...[
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  tooltip: 'Delete for everyone',
                  onPressed: () => _confirmDeleteAnnouncement(context, announcement.id),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF2D2D4E)),
          const SizedBox(height: 8),
          Text(
            announcement.content,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAnnouncement(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Announcement?', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary)),
        content: const Text('Are you sure you want to permanently delete this global announcement?', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _notificationService.deleteAnnouncement(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Announcement deleted.', style: TextStyle(fontFamily: 'Outfit')), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  /// The operator alert feed.
  ///
  /// This was a Firestore `snapshots()` listener on `/admin_notifications`,
  /// open for as long as the tab was on screen. The alerts it delivered are
  /// also delivered as FCM pushes now, which reach the operator with the app
  /// closed — so the listener was the *worse* of the two channels and the one
  /// costing a connection.
  ///
  /// Read on open, refreshed by pull-to-refresh and after a dismissal.
  Widget _buildAdminAlertsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _adminAlerts ??= _loadAdminAlerts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        // Rows removed in this session are filtered here as well as on the
        // server, so a dismissal is instant and survives the rebuild that the
        // refetch causes.
        final alerts = (snapshot.data ?? const <Map<String, dynamic>>[])
            .where((a) => !_justDismissed.contains('${a['_id'] ?? ''}'))
            .toList();

        if (alerts.isEmpty) {
          return const Center(
            child: Text(
              'No admin alerts found. 📭',
              style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshAdminAlerts,
          color: AppTheme.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (ctx, i) {
              final data = alerts[i];
              final id = '${data['_id'] ?? ''}';
              final title = data['title'] ?? 'Alert';
              final body = data['body'] ?? '';
              // `subjectEmail` on anything the API wrote; `userEmail` on the
              // documents migrated out of Firestore.
              final userEmail =
                  '${data['subjectEmail'] ?? data['userEmail'] ?? ''}';
              // Where the alert points, resolved to a screen that exists here.
              //
              // The server writes the route from the operator's point of view
              // and does not know this app's router: a support ticket says
              // `/support`, which is the *member's* contact form, and a new
              // signup says `/admin`, which is a website page with no
              // equivalent in the app. Pushing either verbatim would land the
              // operator somewhere useless or on a blank route, so unknown
              // destinations simply get no button.
              final route = _alertDestination('${data['route'] ?? ''}');
              final createdAt = DateTime.tryParse('${data['createdAt'] ?? ''}');
              final dateStr = createdAt != null
                  ? DateFormat('dd MMM, hh:mm a').format(createdAt)
                  : '';

              return Card(
                color: AppTheme.bgCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF2D2D4E)),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                      Text(dateStr,
                          style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              color: AppTheme.textMuted)),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(body,
                          style: const TextStyle(
                              fontFamily: 'Outfit',
                              color: AppTheme.textSecondary,
                              fontSize: 13)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (userEmail.isNotEmpty)
                            ElevatedButton.icon(
                              onPressed: () {
                                Share.share(
                                    'Please invite this user to Firebase App Distribution:\n$userEmail');
                              },
                              icon: const Icon(Icons.share_outlined,
                                  size: 14, color: Colors.white),
                              label: const Text('Share Email',
                                  style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 12,
                                      color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          if (userEmail.isNotEmpty) const SizedBox(width: 8),

                          // Go and do the thing the alert is about. An alert
                          // is a tap on the shoulder, and until now the only
                          // thing it could be answered with was "dismiss" —
                          // the operator had to remember which screen a
                          // counselling request lives on and go there by hand.
                          if (route.isNotEmpty) ...[
                            ElevatedButton.icon(
                              onPressed: () => context.push(route),
                              icon: const Icon(Icons.arrow_forward_rounded,
                                  size: 14, color: Colors.white),
                              label: const Text('Open',
                                  style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 12,
                                      color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],

                          OutlinedButton.icon(
                            onPressed: id.isEmpty ? null : () => _dismissAlert(id),
                            icon: const Icon(Icons.delete_outline,
                                size: 15, color: Colors.redAccent),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            label: const Text('Delete',
                                style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 12,
                                    color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// The screen in *this* app that answers an alert, or '' when there is none.
  ///
  /// The mapping itself lives in `core/utils/notification_routes.dart` because
  /// a tap on the tray has to make exactly the same decision — one table, so
  /// the two cannot disagree about where an alert goes.
  static String _alertDestination(String raw) =>
      appRouteFor(raw, isAdminAlert: true) ?? '';

  Future<List<Map<String, dynamic>>> _loadAdminAlerts() async {
    final body = await ApiService()
        .get('/api/notifications/admin', query: {'limit': '50'});
    return ((body?['notifications'] as List?) ?? const [])
        .map((n) => Map<String, dynamic>.from(n as Map))
        .toList();
  }

  Future<void> _refreshAdminAlerts() async {
    final next = _loadAdminAlerts();
    setState(() => _adminAlerts = next);
    await next;
  }

  /// Deletes one operator alert.
  ///
  /// ─────────────────────────────────────────────────────────────────────────
  /// Why this could get stuck, and could not be got unstuck
  ///
  /// The list is fetched once, when the tab is first built, and then held in a
  /// `Future` for as long as the screen lives. Alerts are deleted from other
  /// places too — the other handset, the operator console on the website, the
  /// "clear the queue" button here — so the list on screen goes stale, and a
  /// stale row's id no longer exists.
  ///
  /// The old version treated the resulting **404 as a failure**: it showed
  /// "Could not dismiss", left the row exactly where it was, and did not
  /// refetch. So every subsequent tap hit the same missing id and got the same
  /// error, and the queue became impossible to clear — which is precisely what
  /// "dismiss nahi ho raha" looks like from the outside. The alert *was* gone
  /// from the server the whole time; only this screen refused to believe it.
  ///
  /// A 404 here means the job is already done. It is treated as success — the
  /// row goes, and the list is refetched so the rest of it is current.
  ///
  /// The removal is optimistic, matching the other two feeds: the card
  /// disappears on tap and comes back only if the request fails for a reason
  /// that is not "it is already deleted".
  Future<void> _dismissAlert(String id) async {
    setState(() => _justDismissed.add(id));

    try {
      await ApiService().delete('/api/notifications/admin/$id');
    } on ApiException catch (e) {
      if (e.status != 404) {
        if (!mounted) return;
        setState(() => _justDismissed.remove(id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not dismiss: ${e.message}',
                style: const TextStyle(fontFamily: 'Outfit')),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      // 404: somebody else already cleared it. Nothing to report.
    } catch (e) {
      if (!mounted) return;
      setState(() => _justDismissed.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not dismiss: $e',
              style: const TextStyle(fontFamily: 'Outfit')),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!mounted) return;
    context.read<NotificationCenter>().refresh();
    await _refreshAdminAlerts();
  }
}
