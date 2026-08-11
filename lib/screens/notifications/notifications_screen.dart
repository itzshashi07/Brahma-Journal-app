import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
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
  List<String> _deletedNotificationIds = [];
  bool _loadingLocalDeletes = true;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadDeletedNotificationIds();
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
      _initialized = true;
    }
  }

  Future<void> _loadDeletedNotificationIds() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deletedNotificationIds = prefs.getStringList('deleted_notification_ids') ?? [];
      _loadingLocalDeletes = false;
    });
  }

  Future<void> _deleteNotificationLocally(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deletedNotificationIds.add(id);
    });
    await prefs.setStringList('deleted_notification_ids', _deletedNotificationIds);
  }

  @override
  void dispose() {
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
                    const SizedBox(width: 44), // balance back button
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
    if (_loadingLocalDeletes) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return StreamBuilder<List<AppNotification>>(
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
            .where((n) => !_deletedNotificationIds.contains(n.id))
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

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 28),
      ),
      onDismissed: (direction) {
        _deleteNotificationLocally(notification.id);
      },
      child: Card(
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
          onTap: () {
            if (notification.route != null && notification.route!.isNotEmpty) {
              context.push(notification.route!);
            }
          },
        ),
      ),
    );
  }

  Widget _buildAnnouncementsTab(bool isAdmin) {
    return StreamBuilder<List<Announcement>>(
      stream: _notificationService.streamAnnouncements(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent, fontFamily: 'Outfit')));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final announcements = snapshot.data ?? [];
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
              if (isAdmin) ...[
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
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

        final alerts = snapshot.data ?? const <Map<String, dynamic>>[];
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
                          OutlinedButton(
                            onPressed: id.isEmpty ? null : () => _dismissAlert(id),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Dismiss',
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

  Future<void> _dismissAlert(String id) async {
    try {
      await ApiService().delete('/api/notifications/admin/$id');
      await _refreshAdminAlerts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not dismiss: $e'),
            backgroundColor: Colors.redAccent),
      );
    }
  }
}
