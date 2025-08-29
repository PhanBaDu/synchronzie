import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:synchronzie/shared/colors/colors.dart';

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
        isSelected
            ? ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.customGradient.createShader(bounds),
                child: Icon(activeIcon, color: Colors.white, size: 24),
              )
            : Icon(inactiveIcon, color: AppColors.mutedForeground, size: 24),
        if (!isSelected)
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }
}
