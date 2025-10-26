import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final List<String> members;
  final List<Map<String, dynamic>> tasks;

  const ProjectScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.members,
    required this.tasks,
  });

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  late CollectionReference _tasksRef;

  @override
  void initState() {
    super.initState();
    _tasksRef = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('tasks');
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
      'status': 'In progress',
      'startDate': startDate,
      'dueDate': dueDate,
      'completed': false,
      'priority': highPriority,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateTask(String taskId, Map<String, dynamic> updates) async {
    await _tasksRef.doc(taskId).update(updates);
  }

  Future<void> _deleteTask(String taskId) async {
    await _tasksRef.doc(taskId).delete();
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Add New Task"),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                items: widget.members
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => selectedAssignee = v),
              ),
              const SizedBox(height: 12),
              InkWell(
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
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
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
            child: const Text("Add Task"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName),
        backgroundColor: const Color(0xFF116DE6),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _tasksRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyView();
          }

          final docs = snapshot.data!.docs;
          int completed =
              docs.where((d) => (d.data() as Map)['completed'] == true).length;
          int overdue = docs
              .where((d) =>
                  _isOverdue((d.data() as Map)['dueDate'],
                      (d.data() as Map)['completed'] == true))
              .length;
          int inProgress = docs.length - completed - overdue;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCounter("Completed", completed, Colors.green),
                    _buildCounter("In Progress", inProgress, Colors.orange),
                    _buildCounter("Overdue", overdue, Colors.red),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _showAddTaskDialog,
                  icon: const Icon(Icons.add),
                  label: const Text("Add Task"),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(45)),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final task = docs[i].data() as Map<String, dynamic>;
                      final id = docs[i].id;

                      final title = task['title'] ?? 'Untitled Task';
                      final assignee = task['assignee'] ?? 'Unassigned';
                      final completed = task['completed'] == true;
                      final due = task['dueDate'];
                      final isOverdue = _isOverdue(due, completed);

                      Color borderColor;
                      if (completed){
                        borderColor = Colors.green;}
                      else if (isOverdue){
                        borderColor = Colors.red;}
                      else{
                        borderColor = Colors.orange;}

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: borderColor, width: 1.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: completed,
                              onChanged: (v) => _updateTask(id, {
                                'completed': v,
                                'status': v! ? 'Completed' : 'In progress',
                              }),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(assignee,
                                      style: const TextStyle(
                                          color: Colors.black54)),
                                  const SizedBox(height: 4),
                                  Text(
                                    due is Timestamp
                                        ? "Due: ${due.toDate().month}/${due.toDate().day}/${due.toDate().year}"
                                        : "No due date",
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteTask(id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyView() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.task_alt, size: 64, color: Colors.black26),
            SizedBox(height: 8),
            Text("No tasks yet. Add one above."),
          ],
        ),
      );

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
