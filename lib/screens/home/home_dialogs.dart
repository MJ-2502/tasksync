part of 'home_screen.dart';

extension _HomeDialogsExtension on _HomeScreenState {
  // Add underscore prefix to match the calls in home_screen.dart
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
                                          Text(
                                            'Invited by: $inviterEmail',
                                            style: TextStyle(
                                              color: Theme.of(context).textTheme.bodySmall?.color,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Wrap(
                                      direction: Axis.vertical,
                                      spacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.check, size: 18),
                                          label: const Text('Accept'),
                                          style: OutlinedButton.styleFrom(minimumSize: const Size(88, 36)),
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
                                                      Navigator.pop(context);
                                                      Navigator.pop(context);
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
                Text(
                  'Enter the email address of the person you want to invite',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: errorMessage!.contains('already')
                          ? Colors.orange[50]
                          : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: errorMessage!.contains('already')
                            ? Colors.orange[300]!
                            : Colors.red[300]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          errorMessage!.contains('already')
                              ? Icons.warning_amber_outlined
                              : Icons.error_outline,
                          color: errorMessage!.contains('already')
                              ? Colors.orange[700]
                              : Colors.red[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: TextStyle(
                              color: errorMessage!.contains('already')
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
                  
                  setState(() => errorMessage = null);
                  
                  if (email.isEmpty) {
                    setState(() => errorMessage = 'Please enter an email address');
                    return;
                  }

                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}');
                  if (!emailRegex.hasMatch(email)) {
                    setState(() => errorMessage = 'Please enter a valid email address');
                    return;
                  }

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
                          errorMessage = '$userName is already a member of this project';
                        });
                        return;
                      }

                      final inviteId = '${projectId}_$normalizedEmail';
                      final existingInvite = await FirebaseFirestore.instance
                          .collection('project_invites')
                          .doc(inviteId)
                          .get();

                      if (existingInvite.exists) {
                        setState(() {
                          isChecking = false;
                          errorMessage = '$userName already has a pending invitation';
                        });
                        return;
                      }
                    }

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
}