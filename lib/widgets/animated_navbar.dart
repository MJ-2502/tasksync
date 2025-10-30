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
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
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
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
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
            child:SizedBox(
              width: 50, // same for all
              height: 40,
              child: Icon(
              icon,
              color: isSelected
                  ? const Color.fromARGB(255, 17, 109, 230)
                  : Colors.grey,
              size: isSelected ? 35 : 26,
            ),
            )
            
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? const Color.fromARGB(255, 17, 109, 230)
                  : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
