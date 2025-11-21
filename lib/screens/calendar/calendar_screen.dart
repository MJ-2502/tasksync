import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../about_screen.dart';
import '../../theme/app_theme.dart';


class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();
  final _auth = FirebaseAuth.instance;
  final _projectsRef = FirebaseFirestore.instance.collection('projects');

  Map<String, List<Map<String, dynamic>>> _tasksByDate = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTasksForMonth();
  }

  Future<void> _loadTasksForMonth() async {
    if (_auth.currentUser == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final uid = _auth.currentUser!.uid;
      final startOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      final endOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0, 23, 59, 59);
      
      final projectsSnapshot = await _projectsRef
          .where("memberIds", arrayContains: uid)
          .get();
      
      Map<String, List<Map<String, dynamic>>> tasksByDate = {};
      
      for (var projectDoc in projectsSnapshot.docs) {
        final projectData = projectDoc.data();
        final projectName = projectData['title'] ?? 'Untitled';
        
        final tasksSnapshot = await _projectsRef
            .doc(projectDoc.id)
            .collection('tasks')
            .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
            .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
            .get();
        
        for (var taskDoc in tasksSnapshot.docs) {
          final task = taskDoc.data();
          final deadline = task['dueDate'];
          
          if (deadline != null && deadline is Timestamp) {
            final deadlineDate = deadline.toDate();
            final dateKey = DateFormat('yyyy-MM-dd').format(deadlineDate);
            
            if (!tasksByDate.containsKey(dateKey)) {
              tasksByDate[dateKey] = [];
            }
            
            tasksByDate[dateKey]!.add({
              ...task,
              'taskId': taskDoc.id,
              'projectName': projectName,
              'projectId': projectDoc.id,
              'deadlineDate': deadlineDate,
            });
          }
        }
      }
      
      setState(() {
        _tasksByDate = tasksByDate;
      });
    } catch (e) {
      print('Error loading tasks: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getTasksForDate(DateTime date) {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    return _tasksByDate[dateKey] ?? [];
  }

  int _getTaskCountForDate(DateTime date) {
    return _getTasksForDate(date).length;
  }

  bool _hasTasksOnDate(DateTime date) {
    return _getTaskCountForDate(date) > 0;
  }

  int _getCompletedCount(List<Map<String, dynamic>> tasks) {
    return tasks.where((task) => task['completed'] == true).length;
  }

  DateTime _getFirstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  DateTime _getLastDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  int _getDaysInMonth(DateTime date) {
    return _getLastDayOfMonth(date).day;
  }

  int _getFirstWeekday(DateTime date) {
    return _getFirstDayOfMonth(date).weekday;
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
    _loadTasksForMonth();
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
    _loadTasksForMonth();
  }

  void _goToToday() {
    setState(() {
      _focusedMonth = DateTime.now();
      _selectedDate = DateTime.now();
    });
    _loadTasksForMonth();
  }

  Future<void> _toggleTaskCompletion(String projectId, String taskId, bool currentStatus) async {
    try {
      await _projectsRef
          .doc(projectId)
          .collection('tasks')
          .doc(taskId)
          .update({
        'completed': !currentStatus,
        'status': !currentStatus ? 'Completed' : 'In progress',
      });
      
      await _loadTasksForMonth();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!currentStatus ? 'Task completed!' : 'Task reopened'),
            backgroundColor: !currentStatus ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;  // ADD THIS
    final firstWeekday = _getFirstWeekday(_focusedMonth);
    final daysInMonth = _getDaysInMonth(_focusedMonth);
    final monthName = DateFormat('MMMM yyyy').format(_focusedMonth);
    final today = DateTime.now();
    final selectedDateTasks = _getTasksForDate(_selectedDate);
    final completedCount = _getCompletedCount(selectedDateTasks);

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
                          'assets/icons/calendar.png',
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
                        "Calendar",
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
            ),
            // Main content
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.surface,  // CHANGED
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),

                          // Month navigation
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: AppTheme.getShadow(context),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed: _previousMonth,
                                ),
                                Column(
                                  children: [
                                    Text(
                                      monthName,
                                      style: TextStyle(  // CHANGED - removed const
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black87,  // ADDED
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _goToToday,
                                      child: const Text(
                                        'Today',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: _nextMonth,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Calendar grid
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: AppTheme.getShadow(context),
                            ),
                            child: Column(
                              children: [
                                // Weekday headers
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                                      .map((day) => Expanded(
                                            child: Center(
                                              child: Text(
                                                day,
                                                style: TextStyle(  // CHANGED - removed const
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                  color: isDark ? Colors.white60 : Colors.black54,  // CHANGED
                                                ),
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),
                                const SizedBox(height: 12),

                                // Calendar days
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 7,
                                    childAspectRatio: 1,
                                    crossAxisSpacing: 4,
                                    mainAxisSpacing: 4,
                                  ),
                                  itemCount: 42,
                                  itemBuilder: (context, index) {
                                    final dayOffset = index - (firstWeekday - 1);
                                    final dayNumber = dayOffset + 1;

                                    if (dayNumber < 1 || dayNumber > daysInMonth) {
                                      return const SizedBox();
                                    }

                                    final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
                                    final isToday = cellDate.year == today.year &&
                                        cellDate.month == today.month &&
                                        cellDate.day == today.day;
                                    final isSelected = cellDate.year == _selectedDate.year &&
                                        cellDate.month == _selectedDate.month &&
                                        cellDate.day == _selectedDate.day;
                                    final hasTasks = _hasTasksOnDate(cellDate);
                                    final taskCount = _getTaskCountForDate(cellDate);

                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedDate = cellDate;
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFF116DE6)
                                              : isToday
                                                  ? (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE3F2FD))  // CHANGED
                                                  : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          border: isToday && !isSelected
                                              ? Border.all(
                                                  color: const Color(0xFF116DE6),
                                                  width: 1.5,
                                                )
                                              : null,
                                        ),
                                        child: Stack(
                                          children: [
                                            Center(
                                              child: Text(
                                                '$dayNumber',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isToday || isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : (isDark ? Colors.white70 : Colors.black87),  // CHANGED
                                                ),
                                              ),
                                            ),
                                            if (hasTasks)
                                              Positioned(
                                                bottom: 4,
                                                right: 4,
                                                child: Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? Colors.white
                                                        : const Color(0xFFFF5252),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Text(
                                                    '$taskCount',
                                                    style: TextStyle(
                                                      color: isSelected
                                                          ? const Color(0xFF116DE6)
                                                          : Colors.white,
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Stats card
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
                                  children: [
                                    const Icon(
                                      Icons.event,
                                      size: 20,
                                      color: Color(0xFF116DE6),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                                      style: TextStyle(  // CHANGED - removed const
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black87,  // ADDED
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Task completion stats
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8F5E9),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          children: [
                                            const Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                              size: 24,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$completedCount',
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                            const Text(
                                              'Completed',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF3E0),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          children: [
                                            const Icon(
                                              Icons.pending_actions,
                                              color: Colors.orange,
                                              size: 24,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${selectedDateTasks.length - completedCount}',
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange,
                                              ),
                                            ),
                                            const Text(
                                              'Pending',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE3F2FD),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          children: [
                                            const Icon(
                                              Icons.assignment,
                                              color: Color(0xFF116DE6),
                                              size: 24,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${selectedDateTasks.length}',
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF116DE6),
                                              ),
                                            ),
                                            const Text(
                                              'Total',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Tasks list for selected date
                          if (selectedDateTasks.isNotEmpty) ...[
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
                                  Text(  // CHANGED - removed const
                                    'Tasks & Deadlines',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black87, 
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: selectedDateTasks.length,
                                    separatorBuilder: (context, index) => const Divider(height: 20),
                                    itemBuilder: (context, index) {
                                      final task = selectedDateTasks[index];
                                      final isCompleted = task['completed'] == true;
                                      final deadlineDate = task['deadlineDate'] as DateTime;
                                      final timeStr = DateFormat('h:mm a').format(deadlineDate);
                                      final projectId = task['projectId'] as String;
                                      final taskId = task['taskId'] as String;
                                      
                                      return Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          GestureDetector(
                                            onTap: () => _toggleTaskCompletion(
                                              projectId,
                                              taskId,
                                              isCompleted,
                                            ),
                                            child: Icon(
                                              isCompleted
                                                  ? Icons.check_circle
                                                  : Icons.radio_button_unchecked,
                                              color: isCompleted
                                                  ? Colors.green
                                                  : Colors.grey,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  task['title'] ?? 'Untitled Task',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    decoration: isCompleted
                                                        ? TextDecoration.lineThrough
                                                        : null,
                                                    color: isCompleted
                                                        ? (isDark ? Colors.white38 : Colors.black54)
                                                        : (isDark ? Colors.white : Colors.black87), 
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  task['projectName'] ?? 'Unknown Project',
                                                  style: TextStyle( 
                                                    fontSize: 11,
                                                    color: isDark ? Colors.white54 : Colors.black54,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.access_time,
                                                      size: 12,
                                                      color: isDark ? Colors.white38 : Colors.black38, 
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      timeStr,
                                                      style: TextStyle(  
                                                        fontSize: 11,
                                                        color: isDark ? Colors.white38 : Colors.black38,  // CHANGED
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (task['priority'] == true)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.red[50],
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
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
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ] else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFAFAFA), 
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: AppTheme.getShadow(context),
                              ),
                              child: Center(
                                child: Text(
                                  'No tasks scheduled for this day',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.black54,  
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                    if (_isLoading)
                      Container(
                        color: Colors.black12,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}