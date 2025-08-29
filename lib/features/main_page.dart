import 'package:auto_route/auto_route.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:synchronzie/features/health/pages/health_page.dart';
import 'package:synchronzie/features/measure/measure_page.dart';
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
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectedIndex != 0 ? Iconsax.lovely : Iconsax.lovely5,
                color: _selectedIndex != 0
                    ? Color(0xFF737373)
                    : Color(0xFFFF2056),
                size: 24,
              ),
              if (_selectedIndex != 0)
                const Text(
                  "Health",
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF737373),
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectedIndex != 1 ? Iconsax.add_square : Iconsax.add_square5,
                color: _selectedIndex != 1
                    ? Color(0xFF737373)
                    : Color(0xFFFF2056),
                size: 24,
              ),
              if (_selectedIndex != 1)
                const Text(
                  "Health",
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF737373),
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectedIndex != 2
                    ? Iconsax.personalcard
                    : Iconsax.personalcard5,
                color: _selectedIndex != 2
                    ? Color(0xFF737373)
                    : Color(0xFFFF2056),
                size: 24,
              ),
              if (_selectedIndex != 2)
                const Text(
                  "Profile",
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF737373),
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _pages[_selectedIndex],
    );
  }
}
