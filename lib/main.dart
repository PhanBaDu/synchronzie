import 'package:flutter/cupertino.dart';
import 'package:synchronzie/shared/routes/app_router.dart';

// dart run build_runner build --delete-conflicting-outputs
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = AppRouter();

    return CupertinoApp.router(
      routerConfig: router.config(),
      title: 'Synchronzie',
      theme: CupertinoThemeData(primaryColor: CupertinoColors.systemBlue),
    );
  }
}
