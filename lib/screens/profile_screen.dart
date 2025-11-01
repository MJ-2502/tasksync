import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../providers/theme_provider.dart';  // ADD THIS
import 'auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _userName;
  bool _isLoading = true;

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
          
          setState(() {
            _userName = (data?['displayName'] ?? data?['name'] ?? user.email?.split('@')[0]) as String?;
            _isLoading = false;
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
          });
        }
      } catch (e) {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _showLogoutDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = _userName ?? user?.email ?? 'User';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Text(
              'Are you sure you want to logout "$displayName"?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await context.read<AuthService>().logout();

              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
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
          border: Border.all(
            color: isSelected
                ? const Color(0xFF116DE6)
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected 
                  ? Colors.white 
                  : (isDark ? Colors.white70 : Colors.black54),  // CHANGED
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected 
                    ? Colors.white 
                    : (isDark ? Colors.white70 : Colors.black54),  // CHANGED
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
    final isDark = Theme.of(context).brightness == Brightness.dark;  // ADD THIS

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,  // CHANGED
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
                      Text(  // CHANGED - removed const
                        "Profile",
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,  // ADDED
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.settings, 
                      color: isDark ? Colors.white70 : Colors.black87,  // CHANGED
                    ),
                    onPressed: () {
                      // Optional: Add settings functionality
                    },
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.surface,  // CHANGED
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
                          color: Theme.of(context).cardColor,  // CHANGED
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,  // CHANGED
                            width: 1,
                          ),
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
                                  style: TextStyle(  // CHANGED - removed const
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
                                style: TextStyle(  // CHANGED - removed const
                                  fontSize: 14,
                                  color: isDark ? Colors.white60 : Colors.black54,  // CHANGED
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Account Info Section
                      Text(  // CHANGED - removed const
                        "Account Information",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,  // CHANGED
                        ),
                      ),
                      const SizedBox(height: 12),

                      // User ID Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,  // CHANGED
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,  // CHANGED
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.badge, color: Color(0xFF116DE6), size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(  // CHANGED - removed const
                                    "User ID",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white60 : Colors.black54,  // CHANGED
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user?.uid ?? 'N/A',
                                    style: TextStyle(  // CHANGED - removed const
                                      fontSize: 11,
                                      color: isDark ? Colors.white70 : Colors.black87,  // CHANGED
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
                      Text(  // CHANGED - removed const
                        "Appearance",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,  // CHANGED
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
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                                width: 1,
                              ),
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
                                    Expanded(  // CHANGED - removed const
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(  // CHANGED - removed const
                                            "Theme",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white : Colors.black87,  // ADDED
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(  // CHANGED - removed const
                                            "Choose your preferred theme",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.white60 : Colors.black54,  // CHANGED
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

                      // Actions Section
                      Text(  // CHANGED - removed const
                        "Actions",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,  // CHANGED
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