import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationPreferencesService {
  NotificationPreferencesService._internal();
  static final NotificationPreferencesService _instance =
      NotificationPreferencesService._internal();
  factory NotificationPreferencesService() => _instance;

  Map<String, dynamic>? _cachedSettings;
  DateTime? _lastFetched;

  static const _defaultSettings = {
    'quietHoursEnabled': false,
    'quietHoursStart': 60 * 22, // 10:00 PM
    'quietHoursEnd': 60 * 7, // 7:00 AM
    'allowPushNotifications': true,
  };

  Future<Map<String, dynamic>> getSettings({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Map<String, dynamic>.from(_defaultSettings);

    if (!forceRefresh && _cachedSettings != null && _lastFetched != null) {
      final minutesSinceFetch = DateTime.now().difference(_lastFetched!).inMinutes;
      if (minutesSinceFetch < 5) {
        return Map<String, dynamic>.from(_cachedSettings!);
      }
    }

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data()?['notificationSettings'] as Map<String, dynamic>?;

    _cachedSettings = {
      ..._defaultSettings,
      ...?data,
    };
    _lastFetched = DateTime.now();
    return Map<String, dynamic>.from(_cachedSettings!);
  }

  Future<void> updateSettings(Map<String, dynamic> updates) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final current = await getSettings();
    final merged = {
      ...current,
      ...updates,
    };

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {
        'notificationSettings': merged,
      },
      SetOptions(merge: true),
    );

    _cachedSettings = merged;
    _lastFetched = DateTime.now();
  }

  Future<bool> isWithinQuietHours({DateTime? moment}) async {
    final settings = await getSettings();
    return _isMomentInQuietHours(
      moment ?? DateTime.now(),
      (settings['quietHoursStart'] as int?) ?? 0,
      (settings['quietHoursEnd'] as int?) ?? 0,
      settings['quietHoursEnabled'] == true,
    );
  }

  Future<DateTime> nextAvailableNotificationTime(DateTime target) async {
    final settings = await getSettings();
    final enabled = settings['quietHoursEnabled'] == true;
    if (!enabled) return target;

    final start = (settings['quietHoursStart'] as int?) ?? 0;
    final end = (settings['quietHoursEnd'] as int?) ?? 0;

    if (start == end) return target;

    DateTime candidate = target;
    while (_isMomentInQuietHours(candidate, start, end, enabled)) {
      final minutes = candidate.hour * 60 + candidate.minute;
      int deltaMinutes;
      if (start < end) {
        deltaMinutes = end - minutes;
      } else {
        // Quiet hours span midnight
        if (minutes >= start) {
          deltaMinutes = (24 * 60 - minutes) + end;
        } else {
          deltaMinutes = end - minutes;
        }
      }
      candidate = candidate.add(Duration(minutes: deltaMinutes == 0 ? 1 : deltaMinutes));
    }
    return candidate;
  }

  bool _isMomentInQuietHours(
    DateTime moment,
    int start,
    int end,
    bool enabled,
  ) {
    if (!enabled) return false;
    if (start == end) return false;

    final minutes = moment.hour * 60 + moment.minute;
    if (start < end) {
      return minutes >= start && minutes < end;
    }
    return minutes >= start || minutes < end;
  }

  TimeOfDay minutesToTimeOfDay(int minutes) {
    final hrs = (minutes ~/ 60) % 24;
    final mins = minutes % 60;
    return TimeOfDay(hour: hrs, minute: mins);
  }

  int timeOfDayToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  void clearCache() {
    _cachedSettings = null;
    _lastFetched = null;
  }
}
