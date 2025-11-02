import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class InAppNotificationService {
  static final InAppNotificationService _instance = InAppNotificationService._internal();
  factory InAppNotificationService() => _instance;
  InAppNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  StreamSubscription<QuerySnapshot>? _inviteSub;
  StreamSubscription<QuerySnapshot>? _taskSub;
  final Set<String> _seenInvites = {};
  final Set<String> _seenTasks = {};

  /// Initialize and start listening for changes
  Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings);
    
    // Start listening
    _listenToInvitations();
    _listenToNewTasks();
  }

  /// Listen for project invitations
  void _listenToInvitations() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;

    _inviteSub = FirebaseFirestore.instance
        .collection('project_invites')
        .where('email', isEqualTo: user!.email!.toLowerCase())
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final inviteId = change.doc.id;
          
          // Skip if we've already seen this invite
          if (_seenInvites.contains(inviteId)) continue;
          _seenInvites.add(inviteId);

          final data = change.doc.data() as Map<String, dynamic>;
          final projectId = data['projectId'];

          // Get project name
          FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .get()
              .then((projectDoc) {
            if (!projectDoc.exists) return;
            
            final projectName = projectDoc.data()?['title'] ?? 'Unknown Project';
            
            _showLocalNotification(
              title: '🎉 Project Invitation',
              body: 'You were invited to $projectName',
            );
          });
        }
      }
    });
  }

  /// Listen for new tasks assigned to user
  void _listenToNewTasks() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get all projects where user is a member
    FirebaseFirestore.instance
        .collection('projects')
        .where('memberIds', arrayContains: user.uid)
        .snapshots()
        .listen((projectSnapshot) {
      for (var projectDoc in projectSnapshot.docs) {
        final projectId = projectDoc.id;
        final projectName = projectDoc.data()['title'] ?? 'Project';

        // Listen to tasks in this project assigned to current user
        FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .collection('tasks')
            .where('assignee', isEqualTo: user.uid)
            .where('isNew', isEqualTo: true)
            .snapshots()
            .listen((taskSnapshot) {
          for (var change in taskSnapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final taskId = change.doc.id;
              
              // Skip if we've already seen this task
              if (_seenTasks.contains(taskId)) continue;
              _seenTasks.add(taskId);

              final taskData = change.doc.data() as Map<String, dynamic>;
              final taskTitle = taskData['title'] ?? 'New Task';
              final createdBy = taskData['createdBy'];

              // Don't notify if you created the task yourself
              if (createdBy == user.uid) continue;

              _showLocalNotification(
                title: '📋 New Task Assigned',
                body: '$taskTitle in $projectName',
              );
            }
          }
        });
      }
    });
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'tasksync_updates',
      'TaskSync Updates',
      channelDescription: 'Notifications for app updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
    );
  }

  /// Clean up
  void dispose() {
    _inviteSub?.cancel();
    _taskSub?.cancel();
  }
}