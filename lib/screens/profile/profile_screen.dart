import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../providers/theme_provider.dart';
import '../auth/login_screen.dart';
import '../about_screen.dart';
import '../help/tutorial_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialogs.dart';
import '../../services/notification_preferences_service.dart';
import '../../services/notification_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _userName;
  bool _isLoading = true;
  bool _quietHoursEnabled = false;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);
  bool _savingNotificationPrefs = false;
  final NotificationPreferencesService _notificationPrefs = NotificationPreferencesService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final data = userDoc.data();
          final notificationSettings =
              (data?['notificationSettings'] as Map<String, dynamic>?) ?? {};
          final startMinutes = (notificationSettings['quietHoursStart'] as int?) ?? 22 * 60;
          final endMinutes = (notificationSettings['quietHoursEnd'] as int?) ?? 7 * 60;
          
          setState(() {
            _userName = (data?['displayName'] ?? data?['name'] ?? user.email?.split('@')[0]) as String?;
            _isLoading = false;
            _quietHoursEnabled = notificationSettings['quietHoursEnabled'] == true;
            _quietStart = _notificationPrefs.minutesToTimeOfDay(startMinutes);
            _quietEnd = _notificationPrefs.minutesToTimeOfDay(endMinutes);
          });
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'email': user.email,
                'name': user.displayName ?? user.email?.split('@')[0] ?? 'User',
                'createdAt': FieldValue.serverTimestamp(),
              });
          
          setState(() {
            _userName = user.displayName ?? user.email?.split('@')[0] ?? 'User';
            _isLoading = false;
            _quietHoursEnabled = false;
            _quietStart = const TimeOfDay(hour: 22, minute: 0);
            _quietEnd = const TimeOfDay(hour: 7, minute: 0);
          });
        }
      } catch (e) {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _showLogoutDialog(BuildContext context) async {
    final confirmed = await AppDialogs.showConfirmationDialog(
      context: context,
      title: 'Logout',
      content: 'Are you sure you want to logout?',
      confirmText: 'Logout',
      cancelText: 'Cancel',
      isDangerous: true,
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthService>().logout();

      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _pickTime(BuildContext context, {required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _quietStart : _quietEnd,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _quietStart = picked;
        } else {
          _quietEnd = picked;
        }
      });
    }
  }

  Future<void> _saveNotificationPrefs() async {
    setState(() => _savingNotificationPrefs = true);
    try {
      await _notificationPrefs.updateSettings({
        'quietHoursEnabled': _quietHoursEnabled,
        'quietHoursStart': _notificationPrefs.timeOfDayToMinutes(_quietStart),
        'quietHoursEnd': _notificationPrefs.timeOfDayToMinutes(_quietEnd),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification preferences updated'),
          backgroundColor: Colors.green,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingNotificationPrefs = false);
      }
    }
  }

  Future<void> _requestPushPermissions() async {
    await NotificationService().requestPermissions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Permission prompt sent to the system')),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String label,
    IconData icon,
    ThemeMode mode,
    ThemeProvider themeProvider,
  ) {
    final isSelected = themeProvider.themeMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;  // ADD THIS
    
    return GestureDetector(
      onTap: () => themeProvider.setTheme(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF116DE6)
              : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? null : AppTheme.getShadow(context),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected 
                  ? Colors.white 
                  : (isDark ? Colors.white70 : Colors.black54), 
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected 
                    ? Colors.white 
                    : (isDark ? Colors.white70 : Colors.black54), 
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark; 

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,  
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 35,
                        height: 35,
                        child: Image.asset(
                          'assets/icons/profile.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.task_alt,
                              size: 28,
                              color: Color(0xFF116DE6),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(  
                        "Profile",
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    offset: const Offset(0, 50),
                    icon: Icon(
                      Icons.menu,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    onSelected: (value) {
                      if (value == 'about') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AboutScreen(),
                          ),
                        );
                      } else if (value == 'tutorial') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TutorialScreen(),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'about',
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 20),
                            SizedBox(width: 12),
                            Text('About TaskSync'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'tutorial',
                        child: Row(
                          children: [
                            Icon(Icons.help_center_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('Tutorial & Help'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      
                      // Profile Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFAFAFA),  
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppTheme.getShadow(context),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: const Color(0xFF116DE6),
                              child: Text(
                                _isLoading 
                                    ? '...'
                                    : (_userName?.isNotEmpty == true 
                                        ? _userName![0].toUpperCase() 
                                        : (user?.email?.isNotEmpty == true 
                                            ? user!.email![0].toUpperCase() 
                                            : '?')),
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (_isLoading)
                              const CircularProgressIndicator()
                            else ...[
                              if (_userName != null && _userName!.isNotEmpty)
                                Text(
                                  _userName!,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,  // ADDED
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              if (_userName != null && _userName!.isNotEmpty)
                                const SizedBox(height: 8),
                              Text(
                                user?.email ?? "No email",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Account Info Section
                      Text(
                        "Account Information",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // User ID Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppTheme.getShadow(context),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.badge, color: Color(0xFF116DE6), size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "User ID",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user?.uid ?? 'N/A',
                                    style: TextStyle(  
                                      fontSize: 11,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Appearance Section
                      Text(  
                        "Appearance",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Theme Selector
                      Consumer<ThemeProvider>(
                        builder: (context, themeProvider, child) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: AppTheme.getShadow(context),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      themeProvider.isDarkMode
                                          ? Icons.dark_mode
                                          : Icons.light_mode,
                                      color: const Color(0xFF116DE6),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Theme",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Choose your preferred theme",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.white60 : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildThemeOption(
                                        context,
                                        'Light',
                                        Icons.light_mode_outlined,
                                        ThemeMode.light,
                                        themeProvider,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildThemeOption(
                                        context,
                                        'Dark',
                                        Icons.dark_mode_outlined,
                                        ThemeMode.dark,
                                        themeProvider,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildThemeOption(
                                        context,
                                        'System',
                                        Icons.settings_suggest_outlined,
                                        ThemeMode.system,
                                        themeProvider,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),

                      Text(
                        "Notifications",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppTheme.getShadow(context),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.notifications_active_outlined, color: Color(0xFF116DE6)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Quiet hours',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _quietHoursEnabled,
                              title: const Text('Mute push alerts'),
                              subtitle: const Text('Silence notifications between the selected times'),
                              onChanged: (value) {
                                setState(() => _quietHoursEnabled = value);
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _quietHoursEnabled
                                        ? () => _pickTime(context, isStart: true)
                                        : null,
                                    icon: const Icon(Icons.access_time),
                                    label: Text('Start: ${MaterialLocalizations.of(context).formatTimeOfDay(_quietStart)}'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _quietHoursEnabled
                                        ? () => _pickTime(context, isStart: false)
                                        : null,
                                    icon: const Icon(Icons.access_time_outlined),
                                    label: Text('End: ${MaterialLocalizations.of(context).formatTimeOfDay(_quietEnd)}'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _savingNotificationPrefs ? null : _saveNotificationPrefs,
                                    icon: _savingNotificationPrefs
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.save_alt),
                                    label: Text(_savingNotificationPrefs ? 'Saving...' : 'Save preferences'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _requestPushPermissions,
                                    icon: const Icon(Icons.notifications),
                                    label: const Text('Request permissions'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Actions Section
                      Text(
                        "Actions",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,  
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Logout Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showLogoutDialog(context),
                          icon: const Icon(Icons.logout),
                          label: const Text("Logout"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size(double.infinity, 45),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}