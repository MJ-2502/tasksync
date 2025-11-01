import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '/services/notification_service.dart';//i added import for notification service

class ProjectScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final List<String> members;
  final List<Map<String, dynamic>> tasks;
  final Map<String, String> memberNames;
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

class _ProjectScreenState extends State<ProjectScreen> with SingleTickerProviderStateMixin {
  late CollectionReference _tasksRef;
  Set<String> _seenTaskIds = {};
  StreamSubscription<QuerySnapshot>? _seenSub;
  bool _showOnlyMine = false;
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    _tasksRef = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('tasks');

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final seenRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('task_seen');

      _seenSub = seenRef.snapshots().listen((snap) {
        if (mounted) {
          setState(() {
            _seenTaskIds = snap.docs.map((d) => d.id).toSet();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _seenSub?.cancel();
    _fabController.dispose();
    super.dispose();
  }

  bool _isAssignedToCurrentUser(String? assigneeUid) {
    final user = FirebaseAuth.instance.currentUser;
    if (assigneeUid == null) return false;

    final currentEmail = user?.email?.toLowerCase();
    if (currentEmail != null) {
      final assigned = widget.memberNames[assigneeUid]?.toLowerCase();
      if (assigned != null && assigned == currentEmail) return true;
      if (assigneeUid.toLowerCase() == currentEmail) return true;
    }

    final currentUid = user?.uid;
    if (currentUid != null && assigneeUid == currentUid) return true;

    final displayName = user?.displayName?.toLowerCase();
    final assignedName = widget.memberNames[assigneeUid]?.toLowerCase();
    if (displayName != null && assignedName != null && displayName == assignedName) return true;

    return false;
  }

Future<void> _addTask({
  required String title,
  required String assignee,
  required DateTime startDate,
  required DateTime dueDate,
  required TimeOfDay dueTime,
  bool highPriority = false,
}) async {
  try {
    final dueDateWithTime = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      dueTime.hour,
      dueTime.minute,
    );

    final taskRef = await _tasksRef.add({
      'title': title,
      'assignee': assignee,
      'createdBy': FirebaseAuth.instance.currentUser?.uid,
      'status': 'In progress',
      'startDate': Timestamp.fromDate(startDate),
      'dueDate': Timestamp.fromDate(dueDateWithTime),
      'completed': false,
      'priority': highPriority,
      'isNew': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

      // Send notification to assignee
      await NotificationService().notifyTaskAssignment(
        assigneeId: assignee,
        taskTitle: title,
        projectName: widget.projectName,
        taskId: taskRef.id,
      );

      // Schedule reminder notification
      await NotificationService().scheduleTaskReminder(
        taskId: taskRef.id,
        taskTitle: title,
        dueDate: dueDateWithTime,
        projectName: widget.projectName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Theme.of(context).cardColor, size: 20),
                SizedBox(width: 8),
                Text('Task created successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateTask(String taskId, Map<String, dynamic> updates) async {
    await _tasksRef.doc(taskId).update(updates);
    
    // If task was marked as completed, notify team members
    if (updates['completed'] == true) {
      final taskDoc = await _tasksRef.doc(taskId).get();
      final taskData = taskDoc.data() as Map<String, dynamic>;
      
      await NotificationService().notifyTaskCompletion(
        taskTitle: taskData['title'] ?? 'Task',
        projectName: widget.projectName,
        projectId: widget.projectId,
        memberIds: widget.members,
      );
    }
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
    return dueDate.isBefore(now);
  }

  void _showAddTaskDialog() {
    final descriptionController = TextEditingController();
    String? selectedAssignee = widget.members.isNotEmpty ? widget.members.first : null;
    DateTime pickedDue = DateTime.now().add(const Duration(days: 1));
    TimeOfDay pickedTime = const TimeOfDay(hour: 17, minute: 0); // Default 5:00 PM
    bool highPriority = false;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF116DE6),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_task, color: Colors.white),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Create New Task',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: StatefulBuilder(
                      builder: (context, setState) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Task description
                          TextField(
                            controller: descriptionController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: "Task Description",
                              hintText: "What needs to be done?",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.description_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Assignee dropdown
                          DropdownButtonFormField<String>(
                            value: selectedAssignee,
                            decoration: InputDecoration(
                              labelText: "Assign To",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            items: widget.members.map((uid) {
                              final displayName = widget.memberNames[uid] ?? 'Unknown User';
                              return DropdownMenuItem(
                                value: uid,
                                child: Text(displayName),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() => selectedAssignee = v),
                          ),
                          const SizedBox(height: 16),

                          // Due date picker
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: pickedDue,
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2100),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: Color(0xFF116DE6),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() => pickedDue = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: "Due Date",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.calendar_today),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(pickedDue),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const Icon(Icons.arrow_drop_down),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Due time picker
                          InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: pickedTime,
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: Color(0xFF116DE6),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() => pickedTime = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: "Due Time",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.access_time),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    pickedTime.format(context),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const Icon(Icons.arrow_drop_down),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Priority toggle
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: CheckboxListTile(
                              title: const Text('High Priority'),
                              subtitle: const Text('Mark this task as urgent'),
                              secondary: Icon(
                                Icons.flag,
                                color: highPriority ? Colors.red : Colors.grey,
                              ),
                              value: highPriority,
                              onChanged: (v) => setState(() => highPriority = v ?? false),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Actions
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (descriptionController.text.trim().isNotEmpty) {
                              _addTask(
                                title: descriptionController.text.trim(),
                                assignee: selectedAssignee ?? widget.members.first,
                                startDate: DateTime.now(),
                                dueDate: pickedDue,
                                dueTime: pickedTime,
                                highPriority: highPriority,
                              );
                              Navigator.pop(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a task description'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF116DE6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Create Task',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteTaskDialog(BuildContext context, String taskId, String taskTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Task?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "$taskTitle"?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: TextStyle(fontSize: 13, color: Colors.red[700]),
                    ),
                  ),
                ],
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
              await _deleteTask(taskId);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Task deleted successfully'),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) { 
    final isDark = Theme.of(context).brightness == Brightness.dark;  
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back,
                    color: isDark ? Colors.white : Colors.black87,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Image.asset(
                      'assets/icons/tasklist.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.folder_open,
                          size: 32,
                          color: Color(0xFF116DE6),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.projectName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87, 
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.members.length} member${widget.members.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.more_vert,
                      color: isDark ? Colors.white : Colors.black87,
                      ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _tasksRef.orderBy('createdAt', descending: true).snapshots(),
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
                  int pending = filteredDocs.length - completed - overdue;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Stats cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Completed',
                                completed,
                                Icons.check_circle,
                                const Color(0xFFE8F5E9),
                                Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'Pending',
                                pending,
                                Icons.pending_actions,
                                const Color(0xFFFFF3E0),
                                Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'Overdue',
                                overdue,
                                Icons.error_outline,
                                const Color(0xFFFFEBEE),
                                Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Filter chips
                        Row(
                          children: [
                            Text(
                              'Show:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    FilterChip(
                                      label: const Text('All Tasks'),
                                      selected: !_showOnlyMine,
                                      onSelected: (v) => setState(() => _showOnlyMine = false),
                                      selectedColor: const Color(0xFF116DE6).withOpacity(0.2),
                                      checkmarkColor: const Color(0xFF116DE6),
                                    ),
                                    const SizedBox(width: 8),
                                    FilterChip(
                                      label: const Text('My Tasks'),
                                      selected: _showOnlyMine,
                                      onSelected: (v) => setState(() => _showOnlyMine = true),
                                      selectedColor: const Color(0xFF116DE6).withOpacity(0.2),
                                      checkmarkColor: const Color(0xFF116DE6),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Task list
                        if (filteredDocs.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.filter_list_off,
                                    size: 64,
                                    color: isDark ? Colors.grey[600] : Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    _showOnlyMine ? 'No tasks assigned to you' : 'No tasks found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
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
                              final priority = task['priority'] == true;

                              final isNewGlobal = task['isNew'] == true;
                              final isNewForUser = isNewGlobal && !_seenTaskIds.contains(id);

                              return _buildTaskCard(
                                id: id,
                                title: title,
                                assignee: assignee,
                                completed: completed,
                                dueDate: due,
                                isOverdue: isOverdue,
                                priority: priority,
                                isNew: isNewForUser,
                              );
                            },
                          ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        backgroundColor: const Color(0xFF116DE6),
                foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon, Color bgColor, Color iconColor) {

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard({
    required String id,
    required String title,
    required String assignee,
    required bool completed,
    required dynamic dueDate,
    required bool isOverdue,
    required bool priority,
    required bool isNew,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUid == widget.ownerId;
    final canToggle = isOwner || _isAssignedToCurrentUser(assignee);

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        _showDeleteTaskDialog(context, id, title);
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () {
          if (isNew) _markTaskSeen(id);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: isNew
                  ? const Color(0xFF116DE6)
                  : completed
                      ? Colors.green.withOpacity(0.3)
                      : isOverdue
                          ? Colors.red.withOpacity(0.3)
                          : Theme.of(context).dividerColor, 
              width: isNew ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Checkbox
                    Transform.scale(
                      scale: 1.1,
                      child: Checkbox(
                        value: completed,
                        onChanged: canToggle
                            ? (v) => _updateTask(id, {
                                  'completed': v,
                                  'status': v! ? 'Completed' : 'In progress',
                                })
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Task content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              decoration: completed ? TextDecoration.lineThrough : null,
                              color: completed
                                  ? (isDark ? Colors.white38 : Colors.black45)
                                  : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Assignee
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  widget.memberNames[assignee] ?? assignee,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Due date
                          Row(
                            children: [
                              Icon(
                                isOverdue ? Icons.error : Icons.access_time,
                                size: 16,
                                color: isOverdue ? Colors.red : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dueDate is Timestamp
                                    ? DateFormat('MMM dd, yyyy - h:mm a').format(dueDate.toDate())
                                    : 'No due date',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isOverdue ? Colors.red : Colors.grey[600],
                                  fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Badges
              if (priority || isNew)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (priority)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.flag, size: 12, color: Colors.red),
                              SizedBox(width: 4),
                              Text(
                                'HIGH',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (priority && isNew) const SizedBox(width: 4),
                      if (isNew)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF116DE6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E3A5F) // ADDED - dark blue for dark mode
                    : const Color(0xFFE3F2FD), // light blue for light mode
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 64,
                color: const Color(0xFF116DE6).withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No Tasks Yet",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87, 
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Start by creating your first task",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}