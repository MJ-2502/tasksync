import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../project/project_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;
  final _projectsRef = FirebaseFirestore.instance.collection('projects');
  // Connectivity
  bool _isOnline = true;
  bool _isLoading = false;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  Future<Map<String, String>> _getMemberNames(List<String> memberIds) async {
    final Map<String, String> memberNames = {};
    
    for (final memberId in memberIds) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(memberId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        // Use email as display name if name is not available
        memberNames[memberId] = userData?['name'] ?? userData?['email'] ?? 'Unknown User';
      }
    }
    
    return memberNames;
  }
  // --- Add Project ---
  Future<void> _addProject(BuildContext context, String name) async {
    setState(() => _isLoading = true);
    try {
      final uid = _auth.currentUser!.uid;
      await _projectsRef.add({
        "title": name,
        "ownerId": uid,  // ✅ Changed from "createdBy" to "ownerId"
        "memberIds": [uid],  // ✅ Must include the creator as a member
        "createdAt": FieldValue.serverTimestamp(),
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // --- Edit Project ---
  Future<void> _editProject(String projectId, String newName) async {
    setState(() => _isLoading = true);
    try {
      await _projectsRef.doc(projectId).update({"title": newName});
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // --- Delete Project ---
  Future<void> _deleteProject(String projectId) async {
    setState(() => _isLoading = true);
    try {
      await _projectsRef.doc(projectId).delete();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // --- Invite Member ---
  Future<void> _inviteMember(String projectId, String email) async {
    setState(() => _isLoading = true);
    try {
      final uid = _auth.currentUser!.uid;
      final normalizedEmail = email.trim().toLowerCase(); // ✅ Add trim()
      final inviteId = '${projectId}_$normalizedEmail';
      
      await FirebaseFirestore.instance.collection('project_invites').doc(inviteId).set({
        "projectId": projectId,
        "email": normalizedEmail, // ✅ Store lowercase
        "invitedBy": uid,
        "createdAt": FieldValue.serverTimestamp(),
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  //  --- Accept Invitation ---
  Future<void> _acceptInvitation(String inviteId, String projectId) async {
    setState(() => _isLoading = true);
    try {
      final uid = _auth.currentUser!.uid;
      
      // First get the project to check current memberIds
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
        
        // Update project with new memberIds array
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
    // Start listening to connectivity changes
    _initConnectivityListener();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
  // --- Connectivity Listener ---
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
  // --- Project Dialogs ---
  void _showProjectDialog(BuildContext context, {String? projectId, String? currentTitle}) {
    final controller = TextEditingController(text: currentTitle ?? "");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(projectId == null ? 'New Project' : 'Edit Project'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Project name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.of(context).pop();
              if (projectId == null) {
                await _addProject(context, name);
              } else {
                await _editProject(projectId, name);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  // --- Invite Member Dialog ---
  void _showInviteDialog(BuildContext context, String projectId) {
    final controller = TextEditingController();
    bool isChecking = false;
    String? errorMessage;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Invite Member'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'user@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter the email address of the person you want to invite',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                
                // Error/Success message below input field
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: errorMessage!.startsWith('✓') 
                          ? Colors.green[50]
                          : errorMessage!.startsWith('⚠')
                              ? Colors.orange[50]
                              : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: errorMessage!.startsWith('✓')
                            ? Colors.green[300]!
                            : errorMessage!.startsWith('⚠')
                                ? Colors.orange[300]!
                                : Colors.red[300]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          errorMessage!.startsWith('✓')
                              ? Icons.check_circle_outline
                              : errorMessage!.startsWith('⚠')
                                  ? Icons.warning_amber_outlined
                                  : Icons.error_outline,
                          color: errorMessage!.startsWith('✓')
                              ? Colors.green[700]
                              : errorMessage!.startsWith('⚠')
                                  ? Colors.orange[700]
                                  : Colors.red[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: TextStyle(
                              color: errorMessage!.startsWith('✓')
                                  ? Colors.green[700]
                                  : errorMessage!.startsWith('⚠')
                                      ? Colors.orange[700]
                                      : Colors.red[700],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isChecking ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isChecking ? null : () async {
                  final email = controller.text.trim();
                  
                  // Clear previous error
                  setState(() => errorMessage = null);
                  
                  // Basic validation
                  if (email.isEmpty) {
                    setState(() => errorMessage = 'Please enter an email address');
                    return;
                  }

                  // Email format validation
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}');
                  if (!emailRegex.hasMatch(email)) {
                    setState(() => errorMessage = 'Please enter a valid email address');
                    return;
                  }

                  // Check if inviting yourself
                  final currentUserEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
                  if (email.toLowerCase() == currentUserEmail) {
                    setState(() => errorMessage = 'You cannot invite yourself');
                    return;
                  }

                  setState(() {
                    isChecking = true;
                    errorMessage = null;
                  });

                  try {
                    // Check if user exists in the database
                    final normalizedEmail = email.toLowerCase();
                    final usersQuery = await FirebaseFirestore.instance
                        .collection('users')
                        .where('email', isEqualTo: normalizedEmail)
                        .limit(1)
                        .get();

                    if (usersQuery.docs.isEmpty) {
                      setState(() {
                        isChecking = false;
                        errorMessage = 'No user found with email: $email';
                      });
                      return;
                    }

                    final userDoc = usersQuery.docs.first;
                    final userId = userDoc.id;
                    final userName = userDoc.data()['name'] ?? email;

                    // Check if user is already a member
                    final projectDoc = await FirebaseFirestore.instance
                        .collection('projects')
                        .doc(projectId)
                        .get();
                    
                    if (projectDoc.exists) {
                      final projectData = projectDoc.data() as Map<String, dynamic>;
                      final memberIds = List<String>.from(projectData['memberIds'] ?? []);
                      
                      if (memberIds.contains(userId)) {
                        setState(() {
                          isChecking = false;
                          errorMessage = '⚠ $userName is already a member of this project';
                        });
                        return;
                      }

                      // Check if user already has a pending invitation
                      final inviteId = '${projectId}_$normalizedEmail';
                      final existingInvite = await FirebaseFirestore.instance
                          .collection('project_invites')
                          .doc(inviteId)
                          .get();

                      if (existingInvite.exists) {
                        setState(() {
                          isChecking = false;
                          errorMessage = '⚠ $userName already has a pending invitation';
                        });
                        return;
                      }
                    }

                    // All checks passed, send the invitation
                    Navigator.of(context).pop();
                    await _inviteMember(projectId, email);
                    
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Invitation sent to $userName')),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                    
                  } catch (e) {
                    setState(() {
                      isChecking = false;
                      errorMessage = 'Error: ${e.toString()}';
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF116DE6),
                  foregroundColor: Colors.white,
                ),
                child: isChecking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Send Invitation'),
              ),
            ],
          );
        },
      ),
    );
  }
  // --- Invitations Dialog ---
  void _showInvitationsDialog(BuildContext context, List<QueryDocumentSnapshot> invites) {
    showDialog(
      context: context,
      builder: (context) {
        final mq = MediaQuery.of(context);
        final maxHeight = mq.size.height * 0.75;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Project Invitations",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (invites.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                    child: Text("No pending invitations."),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      itemCount: invites.length,
                      itemBuilder: (context, index) {
                        final invite = invites[index];
                        final data = invite.data() as Map<String, dynamic>;
                        final projectId = data['projectId'];
                        final invitedBy = data['invitedBy'];

                        return FutureBuilder<List<DocumentSnapshot>>(
                          future: Future.wait([
                            FirebaseFirestore.instance.collection('users').doc(invitedBy).get(),
                            FirebaseFirestore.instance.collection('projects').doc(projectId).get(),
                          ]),
                          builder: (context, AsyncSnapshot<List<DocumentSnapshot>> snapshots) {
                            if (snapshots.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  leading: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)),
                                  title: Text('Loading project details...'),
                                ),
                              );
                            }

                            if (snapshots.hasError) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: const Icon(Icons.error, color: Colors.red),
                                  title: const Text('Error loading project details'),
                                  subtitle: Text(snapshots.error.toString()),
                                ),
                              );
                            }

                            final userDoc = snapshots.data![0];
                            final projectDoc = snapshots.data![1];
                            final inviterEmail = userDoc.exists ? (userDoc.get('email') ?? 'Unknown') : 'Unknown';
                            final projectName = projectDoc.exists ? (projectDoc.get('title') ?? 'Unnamed Project') : 'Project no longer exists';

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            projectName,
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Text('Invited by: $inviterEmail', style: const TextStyle(color: Colors.black54)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Wrap(
                                      direction: Axis.vertical,
                                      spacing: 8,
                                      children: [
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.check, size: 18),
                                          label: const Text('Accept'),
                                          style: ElevatedButton.styleFrom(minimumSize: const Size(88, 36)),
                                          onPressed: () async {
                                            final user = FirebaseAuth.instance.currentUser;
                                            if (user?.email == null) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Please sign in to accept invitations'), backgroundColor: Colors.red),
                                              );
                                              return;
                                            }
                                            Navigator.pop(context);
                                            final inviteId = '${projectId}_${user!.email!.toLowerCase()}';
                                            await _acceptInvitation(inviteId, projectId);
                                          },
                                        ),
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                          label: const Text('Decline', style: TextStyle(color: Colors.red)),
                                          style: OutlinedButton.styleFrom(minimumSize: const Size(88, 36)),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Decline Invitation?'),
                                                content: Text('Are you sure you want to decline the invitation to "$projectName"?'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
                                                  TextButton(
                                                    onPressed: () async {
                                                      Navigator.pop(context); // close confirmation
                                                      Navigator.pop(context); // close invites dialog
                                                      await invite.reference.delete();
                                                      if (!context.mounted) return;
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text('Invitation declined'), backgroundColor: Colors.red),
                                                      );
                                                    },
                                                    child: const Text('Yes', style: TextStyle(color: Colors.red)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
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
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  // --- Delete Project Dialog ---


  void _showDeleteProjectDialog(BuildContext context, String projectId, String projectName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this project "$projectName"?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'This action cannot be undone.\nAll tasks and data will be permanently deleted.',
                style: TextStyle(fontSize: 12, color: Colors.red[700]),
                textAlign: TextAlign.center,
              ),
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
              await _deleteProject(projectId);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Project "$projectName" deleted')),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
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
                            const Text(
                              "TaskSync",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      Row(
                        children: [
                          // Online / Offline indicator (tap to show a quick message)
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
                          // Invitation mail icon with red dot indicator
                          Builder(
                            builder: (context) {
                              final currentEmailForInvites =
                                  FirebaseAuth.instance.currentUser?.email?.toLowerCase();

                              // If user doesn't have an email (e.g. anonymous), don't start
                              // the invites query because Firestore rules will reject it.
                              if (currentEmailForInvites == null) {
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.mail, color: Colors.black38),
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                "Sign in with your account to view invitations"),
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
                                  final hasInvites =
                                      snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.mail, color: Colors.black87),
                                        onPressed: () => _showInvitationsDialog(
                                            context, snapshot.data?.docs ?? []),
                                      ),
                                      if (hasInvites)
                                        const Positioned(
                                          right: 6,
                                          top: 6,
                                          child: CircleAvatar(
                                            radius: 5,
                                            backgroundColor: Colors.red,
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.settings, color: Colors.black87),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),


                // Main content
                Expanded(
                  child: Container(
                    color: const Color.fromARGB(255, 245, 245, 245),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        // Your teams section
                        const Text(
                          "My teams",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
                        ),
                        const SizedBox(height: 12),

                        // New team button or sign in prompt
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
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Projects list or welcome message for non-signed in users
                        if (_auth.currentUser?.email == null)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Welcome to TaskSync!",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF116DE6),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Sign in to create projects and collaborate with your team.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black54),
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
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Text(
                                    "No teams yet. Create one to get started.",
                                    style: TextStyle(color: Colors.black54),
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
                                
                                // ✅ Get data directly from the doc instead of nested StreamBuilder
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
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey[200]!, width: 1),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              projectData["title"] ?? "Untitled",
                                              style: const TextStyle(
                                                  fontSize: 14, fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "$memberCount Members",
                                              style: const TextStyle(
                                                  fontSize: 12, color: Colors.black54),
                                            ),
                                          ],
                                        ),
                                        // Edit/Delete buttons for project owner
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!, width: 1),
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
                                  const Text(
                                    "Welcome to TaskSync",
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                "Team collaboration made simple for Android. Create Teams, assign tasks, and stay synchronized.",
                                
                                style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
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
                          backgroundColor: const Color(0xFFE8F5E9),
                        ),
                        const SizedBox(height: 12),

                        _buildFeatureCard(
                          icon: Icons.person_add,
                          title: "Invite Team Members",
                          description: "Add members using their email addresses and collaborate in real time",
                          backgroundColor: const Color(0xFFF3E5F5),
                        ),
                        const SizedBox(height: 12),

                        _buildFeatureCard(
                          icon: Icons.update,
                          title: "Real-time Updates",
                          description: "See instant notifications when tasks are completed or updated",
                          backgroundColor: const Color(0xFFFCE4EC),
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