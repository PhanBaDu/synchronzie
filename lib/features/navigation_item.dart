import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NavigationItem extends StatelessWidget {
  final IconData inactiveIcon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;

  const NavigationItem({
    super.key,
    required this.inactiveIcon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isSelected ? activeIcon : inactiveIcon,
          color: isSelected ? const Color(0xFFFF2056) : const Color(0xFF737373),
          size: 24,
        ),
        if (!isSelected)
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF737373),
              fontWeight: FontWeight.w400,
            ),
          ),
      ],
    );
  }
}
