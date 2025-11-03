import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    
    // Request permissions
    await _requestPermissions();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Setup FCM
    await _setupFCM();

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    _initialized = true;
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Notification permissions granted');
    } else {
      print('⚠️ Notification permissions denied');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');


    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Setup Firebase Cloud Messaging
  Future<void> _setupFCM() async {
    String? token = await _fcm.getToken();
    print('📱 FCM Token: $token');

    // Save token to Firestore for the current user
    if (token != null) {
      await _saveFCMToken(token);
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen(_saveFCMToken);
  }

  /// Save FCM token to Firestore
  Future<void> _saveFCMToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('📬 Foreground message: ${message.notification?.title}');
    
    _showLocalNotification(
      title: message.notification?.title ?? 'TaskSync',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');
    // Navigate to specific screen based on message data
    // You can add navigation logic here
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('Local notification tapped: ${response.payload}');
    // Add navigation logic here
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'tasksync_channel',
      'TaskSync Notifications',
      channelDescription: 'Notifications for task updates and reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,

    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Schedule task reminder notification
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String taskTitle,
    required DateTime dueDate,
    String? projectName,
  }) async {
    // Schedule 1 hour before due date
    final reminderTime = dueDate.subtract(const Duration(hours: 1));
    
    // Only schedule if reminder time is in the future
    if (reminderTime.isAfter(DateTime.now())) {
      final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);
      
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'task_reminders',
        'Task Reminders',
        channelDescription: 'Reminders for upcoming task deadlines',
        importance: Importance.high,
        priority: Priority.high,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      await _localNotifications.zonedSchedule(
        taskId.hashCode,
        '⏰ Task Reminder',
        projectName != null 
            ? '$taskTitle - Due in 1 hour\nProject: $projectName'
            : '$taskTitle - Due in 1 hour',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      print('⏰ Scheduled reminder for $taskTitle at $reminderTime');
    }
  }

  /// Cancel task reminder
  Future<void> cancelTaskReminder(String taskId) async {
    await _localNotifications.cancel(taskId.hashCode);
  }

  /// Send notification to specific user via FCM
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final fcmToken = userDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null) {
        print('⚠️ No FCM token found for user $userId');
        return;
      }

      // Store notification in Firestore (acts as a notification queue)
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'userId': userId,
        'fcmToken': fcmToken,
        'title': title,
        'body': body,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      print('✅ Notification queued for user $userId');
    } catch (e) {
      print('❌ Error sending notification: $e');
    }
  }

  /// Notify about task assignment
  Future<void> notifyTaskAssignment({
    required String assigneeId,
    required String taskTitle,
    required String projectName,
    required String taskId,
  }) async {
    await sendNotificationToUser(
      userId: assigneeId,
      title: '📋 New Task Assigned',
      body: '$taskTitle in $projectName',
      data: {
        'type': 'task_assignment',
        'taskId': taskId,
        'projectName': projectName,
      },
    );
  }

  /// Notify about task completion
  Future<void> notifyTaskCompletion({
    required String taskTitle,
    required String projectName,
    required String projectId,
    required List<String> memberIds,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    for (String memberId in memberIds) {
      // Don't notify the person who completed the task
      if (memberId != currentUserId) {
        await sendNotificationToUser(
          userId: memberId,
          title: '✅ Task Completed',
          body: '$taskTitle in $projectName',
          data: {
            'type': 'task_completion',
            'projectId': projectId,
            'projectName': projectName,
          },
        );
      }
    }
  }

  /// Notify about project invitation
  Future<void> notifyProjectInvitation({
    required String inviteeEmail,
    required String projectName,
    required String inviterName,
  }) async {
    // Find user by email
    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: inviteeEmail.toLowerCase())
        .limit(1)
        .get();

    if (userQuery.docs.isNotEmpty) {
      final userId = userQuery.docs.first.id;
      
      await sendNotificationToUser(
        userId: userId,
        title: '🎉 Project Invitation',
        body: '$inviterName invited you to $projectName',
        data: {
          'type': 'project_invitation',
          'projectName': projectName,
        },
      );
    }
  }

  /// Notify about overdue tasks
  Future<void> checkAndNotifyOverdueTasks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    
    // Get all projects where user is a member
    final projectsSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .where('memberIds', arrayContains: user.uid)
        .get();

    for (var projectDoc in projectsSnapshot.docs) {
      final projectName = projectDoc.data()['title'] ?? 'Unknown Project';
      
      // Get overdue tasks
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectDoc.id)
          .collection('tasks')
          .where('assignee', isEqualTo: user.uid)
          .where('completed', isEqualTo: false)
          .get();

      for (var taskDoc in tasksSnapshot.docs) {
        final dueDate = (taskDoc.data()['dueDate'] as Timestamp?)?.toDate();
        
        if (dueDate != null && dueDate.isBefore(now)) {
          await _showLocalNotification(
            title: '⚠️ Overdue Task',
            body: '${taskDoc.data()['title']} in $projectName',
            payload: taskDoc.id,
          );
        }
      }
    }
  }

  /// Get unread notification count
  Future<int> getUnreadNotificationCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .get();

    return snapshot.docs.length;
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📬 Background message: ${message.notification?.title}');
}