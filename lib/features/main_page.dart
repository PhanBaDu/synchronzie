import 'package:auto_route/auto_route.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:synchronzie/features/health/pages/health_page.dart';
import 'package:synchronzie/features/measure/measure_page.dart';
import 'package:synchronzie/features/navigation_item.dart';
import 'package:synchronzie/features/settings/pages/settings_page.dart';

@RoutePage()
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 1;

  final List<Widget> _pages = [
    const HealthPage(),
    const MeasurePage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CupertinoColors.secondarySystemBackground,
      bottomNavigationBar: CurvedNavigationBar(
        height: 75,
        index: _selectedIndex,
        backgroundColor: CupertinoColors.secondarySystemBackground,
        animationDuration: const Duration(milliseconds: 350),
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          NavigationItem(
            inactiveIcon: Iconsax.lovely,
            activeIcon: Iconsax.lovely5,
            label: "Health",
            isSelected: _selectedIndex == 0,
          ),
          NavigationItem(
            inactiveIcon: Iconsax.add_square,
            activeIcon: Iconsax.add_square5,
            label: "Measure", // Sửa label từ "Health" thành "Measure"
            isSelected: _selectedIndex == 1,
          ),
          NavigationItem(
            inactiveIcon: Iconsax.personalcard,
            activeIcon: Iconsax.personalcard5,
            label: "Profile",
            isSelected: _selectedIndex == 2,
          ),
        ],
      ),
      body: _pages[_selectedIndex],
    );
  }
}
