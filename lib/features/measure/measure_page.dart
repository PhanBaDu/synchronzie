import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:synchronzie/shared/colors/colors.dart';

@RoutePage()
class MeasurePage extends StatelessWidget {
  const MeasurePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.secondarySystemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white.withOpacity(0.7),
        automaticBackgroundVisibility: false,
        border: Border.all(color: CupertinoColors.systemGrey.withOpacity(0.1)),
        middle: ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.customGradient.createShader(bounds),
          child: Text(
            'Measure',
            style: TextStyle(
              fontFamily: 'Inter',
              color: CupertinoColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      child: Center(child: Text('Measure')),
    );
  }
}
