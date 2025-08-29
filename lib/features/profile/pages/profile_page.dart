import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:synchronzie/shared/colors/colors.dart';

@RoutePage()
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.secondarySystemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        automaticBackgroundVisibility: false,
        border: Border.all(color: CupertinoColors.systemGrey.withOpacity(0.1)),
        middle: Text(
          'Profile',
          style: TextStyle(
            fontFamily: 'Inter',
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: SafeArea(
        child: CupertinoScrollbar(
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  'Welcome to Health Dashboard',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
