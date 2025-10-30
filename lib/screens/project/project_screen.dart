import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProjectScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final List<String> members;
  final List<Map<String, dynamic>> tasks;
  final Map<String, String> memberNames; // Map of uid to display name/email
  final String ownerId;

  const ProjectScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.members,
    required this.tasks,
    required this.memberNames,
    required this.ownerId,
  });

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  late CollectionReference _tasksRef;
  // Track which tasks the current user has seen (per-user metadata)
  Set<String> _seenTaskIds = {};
  StreamSubscription<QuerySnapshot>? _seenSub;
  bool _showOnlyMine = false; // filter state: false = All, true = My tasks

  @override
  void initState() {
    super.initState();
    _tasksRef = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('tasks');

    // Subscribe to the per-user 'task_seen' subcollection so we can decide
    // whether the 'New' badge should be shown for this user only.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final seenRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('task_seen');

      _seenSub = seenRef.snapshots().listen((snap) {
        setState(() {
          _seenTaskIds = snap.docs.map((d) => d.id).toSet();
        });
      });
    }
  }

  @override
  void dispose() {
    _seenSub?.cancel();
    super.dispose();
  }

  bool _isAssignedToCurrentUser(String? assigneeUid) {
    final user = FirebaseAuth.instance.currentUser;
    if (assigneeUid == null) return false;

    // Try to match by email (preferred), then by uid
    final currentEmail = user?.email?.toLowerCase();
    if (currentEmail != null) {
      final assigned = widget.memberNames[assigneeUid]?.toLowerCase();
      if (assigned != null && assigned == currentEmail) return true;
      // It's possible the assignee field already stores an email string
      if (assigneeUid.toLowerCase() == currentEmail) return true;
    }

    final currentUid = user?.uid;
    if (currentUid != null && assigneeUid == currentUid) return true;

    // Also match by displayName if available
    final displayName = user?.displayName?.toLowerCase();
    final assignedName = widget.memberNames[assigneeUid]?.toLowerCase();
    if (displayName != null && assignedName != null && displayName == assignedName) return true;

    return false;
  }

  // --- Task Operations ---
  Future<void> _addTask({
    required String title,
    required String assignee,
    required DateTime startDate,
    required DateTime dueDate,
    bool highPriority = false,
  }) async {
    await _tasksRef.add({
      'title': title,
      'assignee': assignee,
      'createdBy': FirebaseAuth.instance.currentUser?.uid,
      'status': 'In progress',
      'startDate': startDate,
      'dueDate': dueDate,
      'completed': false,
      'priority': highPriority,
      // Mark newly created tasks so we can highlight them in the UI.
      'isNew': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateTask(String taskId, Map<String, dynamic> updates) async {
    await _tasksRef.doc(taskId).update(updates);
  }

  Future<void> _deleteTask(String taskId) async {
    await _tasksRef.doc(taskId).delete();
  }

  Future<void> _markTaskSeen(String taskId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final seenRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('task_seen');

    await seenRef.doc(taskId).set({'seenAt': FieldValue.serverTimestamp()});
  }

  bool _isOverdue(dynamic due, bool completed) {
    if (due == null || completed) return false;
    if (due is! Timestamp) return false;
    final now = DateTime.now();
    final dueDate = due.toDate();
    return dueDate.isBefore(DateTime(now.year, now.month, now.day + 1));
  }

  // --- Add Task Dialog ---
  void _showAddTaskDialog() {
    final descriptionController = TextEditingController();
    String? selectedAssignee =
        widget.members.isNotEmpty ? widget.members.first : null;
    DateTime? pickedDue;
    bool highPriority = false;

    showDialog(
      context: context,
      builder: (context) {
        final mq = MediaQuery.of(context);
        final maxHeight = mq.size.height * 0.75;
        final narrow = mq.size.width < 380;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: StatefulBuilder(
                builder: (context, setState) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Add New Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                        Tooltip(message: 'Close', child: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: "Task description",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedAssignee,
                      decoration: const InputDecoration(
                        labelText: "Assign to",
                        border: OutlineInputBorder(),
                      ),
                      items: widget.members.map((uid) {
                        final displayName = widget.memberNames[uid] ?? 'Unknown User';
                        return DropdownMenuItem(value: uid, child: Text(displayName));
                      }).toList(),
                      onChanged: (v) => setState(() => selectedAssignee = v),
                    ),
                    const SizedBox(height: 12),
                    Tooltip(
                      message: 'Pick a due date',
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => pickedDue = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: "Due Date (optional)",
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                pickedDue != null
                                    ? "${pickedDue!.month}/${pickedDue!.day}/${pickedDue!.year}"
                                    : "mm/dd/yy",
                                style: const TextStyle(color: Colors.black54),
                              ),
                              const Icon(Icons.calendar_today, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: highPriority,
                          onChanged: (v) => setState(() => highPriority = v ?? false),
                        ),
                        const Text("High Priority"),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Builder(builder: (context) {
                      final addButton = Tooltip(
                        message: 'Add task',
                        child: ElevatedButton(
                          onPressed: () {
                            if (descriptionController.text.trim().isNotEmpty) {
                              _addTask(
                                title: descriptionController.text.trim(),
                                assignee: selectedAssignee ?? "You",
                                startDate: DateTime.now(),
                                dueDate: pickedDue ?? DateTime.now().add(const Duration(days: 1)),
                                highPriority: highPriority,
                              );
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF116DE6),
                            elevation: 0,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(120, 44),
                          ),
                          child: const Text("Add Task"),
                        ),
                      );

                      final cancelButton = Tooltip(
                        message: 'Cancel',
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel", style: TextStyle(color: Color(0xFF116DE6))),
                        ),
                      );

                      if (narrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            addButton,
                            const SizedBox(height: 8),
                            cancelButton,
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          cancelButton,
                          const SizedBox(width: 8),
                          addButton,
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  // --- Delete Task Confirmation Dialog ---
  void _showDeleteTaskDialog(BuildContext context, String taskId, String taskTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this task "$taskTitle"?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'This action cannot be undone.',
                    style: TextStyle(fontSize: 14, color: Colors.red[700]),
                  ),
                ],
              ),
            )
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
              await _deleteTask(taskId);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Task deleted')),
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
          backgroundColor: const Color(0xFFFFFFFF),
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
                                'assets/icons/tasklist.png',
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
                            widget.projectName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.black87),
                        onPressed: () {}, // optional project settings
                      ),
                    ],
                  ),
                ),

                // Main content container (matches HomeScreen body)
                Expanded(
                  child: Container(
                    color: const Color.fromARGB(255, 255, 255, 255),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _tasksRef.snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return _buildEmptyView();
                        }

                        final docs = snapshot.data!.docs;

                        // Filtering logic
                        final filteredDocs = docs.where((d) {
                          if (!_showOnlyMine) return true;
                          final data = d.data() as Map<String, dynamic>;
                          final assignee = data['assignee'] as String?;
                          return _isAssignedToCurrentUser(assignee);
                        }).toList();

                        // Sorting logic
                        filteredDocs.sort((a, b) {
                          final aData = a.data() as Map<String, dynamic>;
                          final bData = b.data() as Map<String, dynamic>;
                          final aCompleted = aData['completed'] == true;
                          final bCompleted = bData['completed'] == true;
                          if (aCompleted != bCompleted) return aCompleted ? 1 : -1;
                          final aHigh = aData['priority'] == true;
                          final bHigh = bData['priority'] == true;
                          if (aHigh != bHigh) return aHigh ? -1 : 1;
                          final aDate = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                          final bDate = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                          return bDate.compareTo(aDate);
                        });

                        // Counters
                        int completed = filteredDocs.where((d) => (d.data() as Map)['completed'] == true).length;
                        int overdue = filteredDocs
                            .where((d) => _isOverdue((d.data() as Map)['dueDate'], (d.data() as Map)['completed'] == true))
                            .length;
                        int inProgress = filteredDocs.length - completed - overdue;

                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Status counters (in consistent row layout)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildCounter("Completed", completed, Colors.green),
                                  _buildCounter("Pending", inProgress, Colors.orange),
                                  _buildCounter("Overdue", overdue, Colors.red),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Add Task button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _showAddTaskDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text("Add Task"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF116DE6),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    minimumSize: const Size(double.infinity, 45),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Filter chips
                              Row(
                                children: [
                                  ChoiceChip(
                                    label: const Text('All'),
                                    selected: !_showOnlyMine,
                                    onSelected: (v) => setState(() => _showOnlyMine = false),
                                  ),
                                  const SizedBox(width: 8),
                                  ChoiceChip(
                                    label: const Text('My tasks'),
                                    selected: _showOnlyMine,
                                    onSelected: (v) => setState(() => _showOnlyMine = v),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Task List - visually consistent cards
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filteredDocs.length,
                                itemBuilder: (context, i) {
                                  final task = filteredDocs[i].data() as Map<String, dynamic>;
                                  final id = filteredDocs[i].id;
                                  final title = task['title'] ?? 'Untitled Task';
                                  final assignee = task['assignee'] ?? 'Unassigned';
                                  final completed = task['completed'] == true;
                                  final due = task['dueDate'];
                                  final isOverdue = _isOverdue(due, completed);

                                  Color borderColor;
                                  if (completed) {
                                    borderColor = Colors.green;
                                  } else if (isOverdue) {
                                    borderColor = Colors.red;
                                  } else {
                                    borderColor = Colors.orange;
                                  }

                                  final isNewGlobal = task['isNew'] == true;
                                  final isNewForUser = isNewGlobal && !_seenTaskIds.contains(id);

                                  return GestureDetector(
                                    onTap: () {
                                      if (isNewForUser) _markTaskSeen(id);
                                    },
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        // The main task card
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color.fromARGB(255, 255, 255, 255),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isNewForUser ? Colors.blue : borderColor,
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.3),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Checkbox area
                                              Builder(builder: (context) {
                                                final currentUid = FirebaseAuth.instance.currentUser?.uid;
                                                final isOwner = currentUid == widget.ownerId;
                                                final canToggle = isOwner || _isAssignedToCurrentUser(assignee);
                                                return Opacity(
                                                  opacity: canToggle ? 1.0 : 0.6,
                                                  child: Checkbox(
                                                    value: completed,
                                                    onChanged: canToggle
                                                        ? (v) => _updateTask(id, {
                                                              'completed': v,
                                                              'status': v! ? 'Completed' : 'In progress',
                                                            })
                                                        : null,
                                                  ),
                                                );
                                              }),

                                              // Task info
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            title,
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.w600,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      widget.memberNames[assignee] ?? 'Unknown User',
                                                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      due is Timestamp
                                                          ? "Due: ${due.toDate().month}/${due.toDate().day}/${due.toDate().year}"
                                                          : "No due date",
                                                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Delete button
                                              Builder(builder: (context) {
                                                final currentUid = FirebaseAuth.instance.currentUser?.uid;
                                                final taskCreator = task['createdBy'] as String?;
                                                final isOwner = currentUid == widget.ownerId;
                                                final canDelete = isOwner || (currentUid != null && currentUid == taskCreator);
                                                return IconButton(
                                                  icon: Icon(Icons.delete,
                                                      color: canDelete ? Colors.red : Colors.grey),
                                                  onPressed: canDelete ? () => _showDeleteTaskDialog(context, id, title) : null,
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                        // High-priority icon in the top-left corner
                                        if (task['priority'] == true)
                                          Positioned(
                                            left: 3,
                                            top: 4,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(
                                                    Icons.priority_high,
                                                    size: 12,
                                                    color: Colors.red,
                                                  ),
                                                  SizedBox(width: 2),
                                                  Text(
                                                    'HIGH',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),


                                        // 🟦 'New' badge overlay
                                        if (isNewForUser)
                                          Positioned(
                                            right: 0.5,
                                            top: 0.5,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.blue,
                                                border: Border.all(color: Colors.blue, width: 1.6),
                                                borderRadius: const BorderRadius.only(
                                                  topRight: Radius.circular(12),
                                                  bottomLeft: Radius.circular(6),
                                                ),
                                              ),
                                              child: const Text(
                                                'New',
                                                style: TextStyle(color: Colors.white, fontSize: 12),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );

                                },
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                "No tasks yet",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Start by adding a new task to your project.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showAddTaskDialog,
                icon: const Icon(Icons.add),
                label: const Text("Add Task"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF116DE6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(150, 44),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildCounter(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
