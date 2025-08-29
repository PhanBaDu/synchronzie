import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:iconsax/iconsax.dart';
import 'package:synchronzie/features/health/pages/health_page.dart';
import 'package:synchronzie/features/measure/measure_page.dart';
import 'package:synchronzie/features/profile/pages/profile_page.dart';
import 'package:synchronzie/shared/colors/colors.dart';

@RoutePage()
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      backgroundColor: CupertinoColors.secondarySystemBackground,
      tabBar: CupertinoTabBar(
        backgroundColor: CupertinoColors.white,
        border: Border.all(color: AppColors.mutedForeground.withOpacity(0.1)),
        activeColor: AppColors.primary,
        inactiveColor: AppColors.mutedForeground,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              size: 24,
              _selectedIndex == 0 ? Iconsax.heart5 : Iconsax.heart,
              color: _selectedIndex == 0
                  ? AppColors.primary
                  : AppColors.mutedForeground,
            ),
            label: "Health",
          ),
          BottomNavigationBarItem(
            icon: Icon(
              size: 24,
              _selectedIndex == 1 ? Iconsax.add_square5 : Iconsax.add_square,
              color: _selectedIndex == 1
                  ? AppColors.primary
                  : AppColors.mutedForeground,
            ),
            label: "Measure",
          ),
          BottomNavigationBarItem(
            icon: Icon(
              size: 24,
              _selectedIndex == 2
                  ? Iconsax.personalcard5
                  : Iconsax.personalcard,
              color: _selectedIndex == 2
                  ? AppColors.primary
                  : AppColors.mutedForeground,
            ),
            label: "Profile",
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return const HealthPage();
          case 1:
            return const MeasurePage();
          case 2:
            return const ProfilePage();
          default:
            return const HealthPage();
        }
      },
    );
  }
}
