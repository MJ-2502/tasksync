import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../project/project_screen.dart';
import '/services/notification_service.dart';
import '../about_screen.dart';
import '../../theme/app_theme.dart';

part 'home_dialogs.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;
  final _projectsRef = FirebaseFirestore.instance.collection('projects');
  bool _isOnline = true;
  bool _isLoading = false;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  Future<Map<String, String>> _getMemberNames(List<String> memberIds) async {
    final Map<String, String> memberNames = {};
    
    for (final memberId in memberIds) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(memberId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        memberNames[memberId] = userData?['name'] ?? userData?['email'] ?? 'Unknown User';
      }
    }
    
    return memberNames;
  }

  Future<void> _addProject(BuildContext context, String name) async {
    setState(() => _isLoading = true);
    try {
      final uid = _auth.currentUser!.uid;
      await _projectsRef.add({
        "title": name,
        "ownerId": uid,
        "memberIds": [uid],
        "createdAt": FieldValue.serverTimestamp(),
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editProject(String projectId, String newName) async {
    setState(() => _isLoading = true);
    try {
      await _projectsRef.doc(projectId).update({"title": newName});
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProject(String projectId) async {
    setState(() => _isLoading = true);
    try {
      await _projectsRef.doc(projectId).delete();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _inviteMember(String projectId, String email) async {
    setState(() => _isLoading = true);
    try {
      final uid = _auth.currentUser!.uid;
      final normalizedEmail = email.trim().toLowerCase();
      final inviteId = '${projectId}_$normalizedEmail';
      
      // Get inviter's name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final inviterName = userDoc.data()?['displayName'] ?? 
                        userDoc.data()?['name'] ?? 
                        _auth.currentUser?.email ?? 
                        'Someone';
      
      // Get project name
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();
      final projectName = projectDoc.data()?['title'] ?? 'Project';
      
      await FirebaseFirestore.instance.collection('project_invites').doc(inviteId).set({
        "projectId": projectId,
        "email": normalizedEmail,
        "invitedBy": uid,
        "createdAt": FieldValue.serverTimestamp(),
      });
      
      // Send notification(needs cloud function to work properly)
      await NotificationService().notifyProjectInvitation(
        inviteeEmail: normalizedEmail,
        projectName: projectName,
        inviterName: inviterName,
      );

    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptInvitation(String inviteId, String projectId) async {
    setState(() => _isLoading = true);
    try {
      final uid = _auth.currentUser!.uid;
      
      final projectDoc = await _projectsRef.doc(projectId).get();
      if (!projectDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project no longer exists'), backgroundColor: Colors.red),
        );
        return;
      }

      final currentData = projectDoc.data() as Map<String, dynamic>;
      final List<String> memberIds = List<String>.from(currentData['memberIds'] ?? []);
      
      if (!memberIds.contains(uid)) {
        memberIds.add(uid);
        
        await FirebaseFirestore.instance.runTransaction((tx) async {
          tx.update(_projectsRef.doc(projectId), {
            'memberIds': memberIds,
            'members': {uid: {'role': 'member', 'joinedAt': FieldValue.serverTimestamp()}},
          });
          tx.delete(FirebaseFirestore.instance.collection('project_invites').doc(inviteId));
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined the project!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join project: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _initConnectivityListener();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  void _initConnectivityListener() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _isOnline = result != ConnectivityResult.none;
      setState(() {});

      _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
        final online = result != ConnectivityResult.none;
        if (online != _isOnline) {
          setState(() {
            _isOnline = online;
          });
        }
      });
    } catch (e) {
      _isOnline = true;
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Scaffold(
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
                            width: 28,
                            height: 28,
                            child: Image.asset(
                              'assets/icons/logo.png',
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
                            "TaskSync",
                            style: TextStyle(
                              fontSize: 20, 
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _isOnline ? Icons.wifi : Icons.wifi_off,
                              color: _isOnline ? Colors.green : Colors.grey,
                            ),
                            onPressed: () {
                              final msg = _isOnline ? "You're Online" : "You're Offline";
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Builder(
                            builder: (context) {
                              final currentEmailForInvites =
                                  FirebaseAuth.instance.currentUser?.email?.toLowerCase();

                              if (currentEmailForInvites == null) {
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.mail, 
                                        color: isDark ? Colors.white38 : Colors.black38,  // CHANGED
                                      ),
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("Sign in with your account to view invitations"),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                );
                              }

                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('project_invites')
                                    .where('email', isEqualTo: currentEmailForInvites.toLowerCase())
                                    .snapshots(),
                                  
                                  builder: (context, snapshot) {
                                    final count = snapshot.data?.docs.length ?? 0;
                                    
                                    return Stack(
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.mail),
                                          onPressed: () => _showInvitationsDialog(context, snapshot.data?.docs ?? []),
                                        ),
                                        //invitation counter
                                        if (count > 0)
                                          Positioned(
                                            right: 8,
                                            top: 8,
                                            child: Container(
                                              padding: EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                                              child: Text(
                                                '$count',
                                                style: TextStyle(color: Colors.white, fontSize: 10),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                              );
                            },
                          ),
                          const SizedBox(width: 12),
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
                            ],
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
                          const SizedBox(height: 12),
                          Text(  // CHANGED - removed const
                            "Projects",
                            style: TextStyle(
                              fontSize: 14, 
                              fontWeight: FontWeight.w600, 
                              color: isDark ? Colors.white60 : Colors.black54,  
                            ),
                          ),
                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _auth.currentUser?.email != null
                                  ? () => _showProjectDialog(context)
                                  : () {
                                      Navigator.pushNamed(context, '/login');
                                    },
                              icon: Icon(_auth.currentUser?.email != null ? Icons.add : Icons.login),
                              label: Text(_auth.currentUser?.email != null
                                  ? "New Project"
                                  : "Sign in to create projects"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF116DE6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                minimumSize: const Size(double.infinity, 45),
                                elevation: 5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (_auth.currentUser?.email == null)
                            Padding(  // CHANGED - removed const
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Welcome to TaskSync!",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFF4A9EFF) : const Color(0xFF116DE6),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text( 
                                    "Sign in to create projects and collaborate with your team.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            StreamBuilder<QuerySnapshot>(
                              stream: _projectsRef
                                  .where("memberIds", arrayContains: _auth.currentUser!.uid)
                                  .orderBy("createdAt", descending: true)
                                  .snapshots(includeMetadataChanges: true),
                                  builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                  return Padding( 
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    child: Center(
                                      child: Text(  
                                        "No teams yet. Create one to get started.",
                                        style: TextStyle(
                                          color: isDark ? Colors.white60 : Colors.black54,  // CHANGED
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                final projects = snapshot.data!.docs;
                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: projects.length,
                                  itemBuilder: (context, index) {
                                    final doc = projects[index];
                                    if (!doc.exists) return const SizedBox.shrink();
                                    
                                    final projectData = doc.data() as Map<String, dynamic>;
                                    final memberCount = (projectData["memberIds"] as List?)?.length ?? 0;

                                    return InkWell(
                                      onTap: () async {
                                        final memberIds = List<String>.from(projectData['memberIds'] ?? []);
                                        final tasks = List<Map<String, dynamic>>.from(projectData['tasks'] ?? []);
                                        final memberNames = await _getMemberNames(memberIds);
                                        
                                        if (!context.mounted) return;
                                        
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ProjectScreen(
                                              projectId: doc.id,
                                              projectName: projectData["title"] ?? "Untitled",
                                              members: memberIds,
                                              tasks: tasks,
                                              memberNames: memberNames,
                                              ownerId: projectData['ownerId'] ?? '',
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: AppTheme.getShadow(context),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  projectData["title"] ?? "Untitled",
                                                  style: TextStyle(
                                                    fontSize: 14, 
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? Colors.white : Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  "$memberCount Members",
                                                  style: TextStyle(
                                                    fontSize: 12, 
                                                    color: isDark ? Colors.white60 : Colors.black54,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                if (FirebaseAuth.instance.currentUser?.uid == projectData['ownerId']) ...[
                                                  IconButton(
                                                    icon: const Icon(Icons.person_add, color: Colors.green, size: 20),
                                                    onPressed: () => _showInviteDialog(context, doc.id),
                                                    iconSize: 20,
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                                    onPressed: () => _showProjectDialog(
                                                      context,
                                                      projectId: doc.id,
                                                      currentTitle: projectData["title"],
                                                    ),
                                                    iconSize: 20,
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                                    onPressed: () => _showDeleteProjectDialog(
                                                        context, doc.id, projectData["title"] ?? "Untitled"),
                                                    iconSize: 20,
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          const SizedBox(height: 28),

                          // Welcome section
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: Image.asset(
                                        'assets/icons/logo.png',
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
                                      "Welcome to TaskSync",
                                      style: TextStyle(
                                        fontSize: 14, 
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black87, 
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text( 
                                  "Team collaboration made simple for Android. Create Teams, assign tasks, and stay synchronized.",
                                  style: TextStyle(
                                    fontSize: 12, 
                                    color: isDark ? Colors.white60 : Colors.black54, 
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Feature cards
                          _buildFeatureCard(
                            icon: Icons.group,
                            title: "Create & Manage Team",
                            description: "Set up teams for different projects and organize your workflow",
                            backgroundColor: const Color.fromARGB(80, 0, 255, 21),
                          ),
                          const SizedBox(height: 12),

                          _buildFeatureCard(
                            icon: Icons.person_add,
                            title: "Invite Team Members",
                            description: "Add members using their email addresses and collaborate in real time",
                            backgroundColor: const Color.fromARGB(80, 240, 143, 255),
                          ),
                          const SizedBox(height: 12),

                          _buildFeatureCard(
                            icon: Icons.update,
                            title: "Real-time Updates",
                            description: "See instant notifications when tasks are completed or updated",
                            backgroundColor: const Color.fromARGB(80, 253, 91, 145),
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
        ),
        if (_isLoading) ...[
          ModalBarrier(dismissible: false, color: Colors.black45),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color backgroundColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.getShadow(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: Colors.black54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}