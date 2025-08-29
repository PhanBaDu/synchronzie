import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';

@RoutePage()
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.secondarySystemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white.withOpacity(0.7),
        automaticBackgroundVisibility: false,
        border: Border.all(color: CupertinoColors.systemGrey.withOpacity(0.1)),
        middle: Text('Profile', style: TextStyle(color: CupertinoColors.label)),
      ),
      child: Center(child: Text('Profile Page')),
    );
  }
}
