import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/notification_service.dart';

class NotificationBell extends StatelessWidget {
  final Color? iconColor;
  const NotificationBell({super.key, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return IconButton(
        icon: Icon(Icons.notifications_off_outlined, color: iconColor ?? Colors.grey),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sign in to view notifications'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final unread = snapshot.data?.docs
                .where((doc) => (doc.data() as Map<String, dynamic>)['read'] != true)
                .length ??
            0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                unread > 0 ? Icons.notifications_active_outlined : Icons.notifications_none_outlined,
                color: iconColor ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
              ),
              onPressed: () => _openNotificationCenter(context, user.uid),
            ),
            if (unread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

void _openNotificationCenter(BuildContext context, String userId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _NotificationCenterSheet(userId: userId),
  );
}

class _NotificationCenterSheet extends StatelessWidget {
  final String userId;
  const _NotificationCenterSheet({required this.userId});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await NotificationService().markAllNotificationsAsRead();
                    },
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Mark all read'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('userId', isEqualTo: userId)
                    .orderBy('createdAt', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _EmptyNotificationsState();
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final isUnread = data['read'] != true;
                      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

                      return Material(
                        color: isUnread
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: _buildLeadingIcon(data['type'] as String?),
                          title: Text(
                            data['title'] ?? 'Notification',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                data['body'] ?? '',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (createdAt != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM d • h:mm a').format(createdAt),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                          trailing: isUnread
                              ? Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF116DE6),
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                          onTap: () async {
                            await NotificationService().markNotificationAsRead(doc.id);
                          },
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: docs.length,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(String? type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'task_assignment':
        icon = Icons.assignment_ind_outlined;
        color = Colors.blueAccent;
        break;
      case 'task_completion':
        icon = Icons.celebration_outlined;
        color = Colors.green;
        break;
      case 'project_invitation':
        icon = Icons.mail_outline;
        color = Colors.orange;
        break;
      default:
        icon = Icons.notifications_outlined;
        color = Colors.purple;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.15),
      child: Icon(icon, color: color),
    );
  }
}

class _EmptyNotificationsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('You\'re all caught up!', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('New updates and mentions will appear here.'),
          ],
        ),
      ),
    );
  }
}
