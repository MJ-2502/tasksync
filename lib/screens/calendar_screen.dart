import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();

  // Get the first day of the month
  DateTime _getFirstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  // Get the last day of the month
  DateTime _getLastDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  // Get the number of days in the month
  int _getDaysInMonth(DateTime date) {
    return _getLastDayOfMonth(date).day;
  }

  // Get the weekday of the first day (1 = Monday, 7 = Sunday)
  int _getFirstWeekday(DateTime date) {
    return _getFirstDayOfMonth(date).weekday;
  }

  // Navigate to previous month
  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  // Navigate to next month
  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  // Navigate to today
  void _goToToday() {
    setState(() {
      _focusedMonth = DateTime.now();
      _selectedDate = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstWeekday = _getFirstWeekday(_focusedMonth);
    final daysInMonth = _getDaysInMonth(_focusedMonth);
    final monthName = DateFormat('MMMM yyyy').format(_focusedMonth);
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
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
                  const Text(
                    "Calendar",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                      const SizedBox(height: 8),

                      // Month navigation
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!, width: 1),
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
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!, width: 1),
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
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              color: Colors.black54,
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
                              itemCount: 42, // 6 weeks
                              itemBuilder: (context, index) {
                                // Calculate the actual day number
                                final dayOffset = index - (firstWeekday - 1);
                                final dayNumber = dayOffset + 1;

                                // Check if this cell should show a day from current month
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
                                              ? const Color(0xFFE3F2FD)
                                              : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: isToday && !isSelected
                                          ? Border.all(
                                              color: const Color(0xFF116DE6),
                                              width: 1.5,
                                            )
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$dayNumber',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isToday || isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selected date info
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
                                const Icon(
                                  Icons.event,
                                  size: 20,
                                  color: Color(0xFF116DE6),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No events scheduled',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
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