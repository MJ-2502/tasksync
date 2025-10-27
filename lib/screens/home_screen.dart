import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'project/project_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;
  final _projectsRef = FirebaseFirestore.instance.collection('projects');

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

  @override
  void initState() {
    super.initState();
    _ensureSignedIn();
  }

  Future<void> _ensureSignedIn() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  Future<void> _addProject(BuildContext context, String name) async {
    final uid = _auth.currentUser!.uid;
    await _projectsRef.add({
      "title": name,
      "memberIds": [uid],
      "ownerId": uid,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> _editProject(String projectId, String newName) async {
    await _projectsRef.doc(projectId).update({"title": newName});
  }

  Future<void> _deleteProject(String projectId) async {
    await _projectsRef.doc(projectId).delete();
  }

  Future<void> _inviteMember(String projectId, String email) async {
    final uid = _auth.currentUser!.uid;
    final normalizedEmail = email.toLowerCase();
    final inviteId = '${projectId}_$normalizedEmail'; // ✅ Key change

    await FirebaseFirestore.instance
        .collection('project_invites')
        .doc(inviteId)
        .set({
      "projectId": projectId,
      "email": normalizedEmail,
      "invitedBy": uid,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }


  void _showProjectDialog(BuildContext context, {String? projectId, String? currentTitle}) {
    final controller = TextEditingController(text: currentTitle ?? "");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(projectId == null ? "New Project" : "Edit Project"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Project name", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              if (projectId == null) {
                _addProject(context, controller.text.trim());
              } else {
                _editProject(projectId, controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: Text(projectId == null ? "Create" : "Save"),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context, String projectId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Invite Member"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Enter member email",
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final email = controller.text.trim();
              if (email.isNotEmpty && email.contains("@")) {
                await _inviteMember(projectId, email);
              }
              Navigator.pop(context);
            },
            child: const Text("Invite"),
          ),
        ],
      ),
    );
  }

  void _showInvitationsDialog(BuildContext context, List<QueryDocumentSnapshot> invites) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Project Invitations"),
        content: invites.isEmpty
            ? const Text("No pending invitations.")
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: invites.length,
                  itemBuilder: (context, index) {
                    final invite = invites[index];
                    final data = invite.data() as Map<String, dynamic>;
                    final projectId = data['projectId'];
                    final invitedBy = data['invitedBy'];

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(invitedBy).get(),
                      builder: (context, userSnapshot) {
                        final inviterEmail = (userSnapshot.data?.exists ?? false)
                          ? (userSnapshot.data?.get('email') ?? "Unknown")
                          : "Unknown";


                        return ListTile(
                          title: FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('projects')
                                .doc(projectId)
                                .get(),
                            builder: (context, snapshot) {
                              final projectName =
                                  snapshot.data?.get('title') ?? 'Unnamed Project';
                              return Text(
                                projectName,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              );
                            },
                          ),
                          subtitle: Text("Invited by: $inviterEmail"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: () async {
                                  final userEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
                                  if (userEmail == null) return;

                                  Navigator.pop(context);

                                  // ✅ Use composite invite ID for lookup
                                  final inviteId = '${projectId}_${userEmail.toLowerCase()}';

                                  await _acceptInvitation(inviteId, projectId);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Invitation accepted! ✅"),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },

                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection('project_invites')
                                      .doc(invite.id)
                                      .delete();

                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Invitation declined ❌"),
                                      backgroundColor: Colors.redAccent,
                                      behavior: SnackBarBehavior.floating,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }



  Future<void> _acceptInvitation(String inviteId, String projectId) async {
  final user = _auth.currentUser!;
  final firestore = FirebaseFirestore.instance;

  final projectRef = firestore.collection('projects').doc(projectId);
  final inviteRef = firestore.collection('project_invites').doc(inviteId);

  await firestore.runTransaction((transaction) async {
    final projectSnap = await transaction.get(projectRef);
    final inviteSnap = await transaction.get(inviteRef);

    if (!projectSnap.exists || !inviteSnap.exists) {
      throw Exception("Invalid invite or project.");
    }

    // Only allow joining if this user's email matches the invite
    final inviteData = inviteSnap.data()!;
    if (inviteData['email'] != user.email?.toLowerCase()) {
      throw Exception("This invite isn’t for you.");
    }

    final projectData = projectSnap.data()!;
    final memberIds = List<String>.from(projectData['memberIds'] ?? []);

    if (!memberIds.contains(user.uid)) {
      transaction.update(projectRef, {
        'memberIds': FieldValue.arrayUnion([user.uid]),
      });
    }

    // Delete invite so it disappears from inbox
    transaction.delete(inviteRef);
  });

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Invitation accepted ✅"),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  setState(() {}); // Refresh UI immediately
}




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF116DE6), size: 28),
                      SizedBox(width: 8),
                      Text("TaskSync",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      //Invitation mail icon with red dot indicator
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('project_invites')
                            .where('email',
                                isEqualTo:
                                    FirebaseAuth.instance.currentUser?.email?.toLowerCase())
                            .snapshots(),
                        builder: (context, snapshot) {
                          final hasInvites =
                              snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.mail, color: Colors.black87),
                                onPressed: () =>
                                    _showInvitationsDialog(context, snapshot.data?.docs ?? []),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Your teams section
                    const Text(
                      "My teams",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),

                    // New team button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showProjectDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text("New Project"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF116DE6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(double.infinity, 45),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Projects list
                    StreamBuilder<QuerySnapshot>(
                      stream: _projectsRef
                          .where("memberIds", arrayContains: FirebaseAuth.instance.currentUser?.uid)
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
                            return StreamBuilder<DocumentSnapshot>(
                              stream: _projectsRef.doc(doc.id).snapshots(),
                              builder: (context, projectSnapshot) {
                                if (!projectSnapshot.hasData) {
                                  return const SizedBox.shrink();
                                }

                                final projectData =
                                    projectSnapshot.data!.data() as Map<String, dynamic>;
                                final memberCount =
                                    (projectData["memberIds"] as List?)?.length ?? 0;

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
                                        // Move variable declarations outside the widget tree
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
                                                onPressed: () => _deleteProject(doc.id),
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
                              const Icon(Icons.check_circle, color: Color(0xFF116DE6), size: 24),
                              const SizedBox(width: 8),
                              const Text(
                                "Welcome to TaskSync",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Team collaboration made simple for Android.",
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
          ],
        ),
      ),
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