import 'package:auto_route/auto_route.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:synchronzie/features/health/pages/health_page.dart';
import 'package:synchronzie/features/settings/pages/settings_page.dart';

@RoutePage()
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [const HealthPage(), const SettingsPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CupertinoColors.secondarySystemBackground,
      bottomNavigationBar: CurvedNavigationBar(
        height: 75,
        index: _selectedIndex,
        backgroundColor: CupertinoColors.secondarySystemBackground,
        animationDuration: const Duration(milliseconds: 400),
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.heart, color: Color(0xFFFF2056), size: 24),
              if (_selectedIndex != 0)
                const Text(
                  "Health",
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFFF2056),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.setting_2, color: Color(0xFFFF2056), size: 24),
              if (_selectedIndex != 1)
                const Text(
                  "Settings",
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFFF2056),
                    fontWeight: FontWeight.w600,
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
