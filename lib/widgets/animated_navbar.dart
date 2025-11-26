import 'package:flutter/material.dart';

class AnimatedNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  const AnimatedNavBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  @override
  State<AnimatedNavBar> createState() => _AnimatedNavBarState();
}

class _AnimatedNavBarState extends State<AnimatedNavBar> {
  final Duration _duration = const Duration(milliseconds: 300);
  final Curve _curve = Curves.easeOutQuint;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;  

    return Container(
      padding: const EdgeInsets.only(top: 2),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Container(
        height: 75,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black45 : Colors.black12,
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(icon: Icons.event, label: "Calendar", index: 0),
          _buildNavItem(icon: Icons.home, label: "Home", index: 1),
          _buildNavItem(icon: Icons.person, label: "Profile", index: 2),
        ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;  
    bool isSelected = widget.currentIndex == index;

    return GestureDetector(
      onTap: () => widget.onItemSelected(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: _duration,
            curve: _curve,
            transform: Matrix4.translationValues(0, isSelected ? -4 : 0, 0),
            child: SizedBox(
              width: 50,
              height: 40,
              child: Icon(
                icon,
                color: isSelected
                    ? const Color(0xFF116DE6)  // Keep primary blue when selected
                    : (isDark ? Colors.grey[400] : Colors.grey),  // CHANGED - lighter grey for dark mode
                size: isSelected ? 35 : 26,
              ),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedOpacity(
            duration: _duration,
            curve: _curve,
            opacity: isSelected ? 1.0 : 0.0,
            child: AnimatedContainer(
              duration: _duration,
              curve: _curve,
              height: isSelected ? 15 : 0,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF116DE6),  // Always primary blue when visible
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}