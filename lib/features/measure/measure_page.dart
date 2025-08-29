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
        backgroundColor: CupertinoColors.white,
        automaticBackgroundVisibility: false,
        middle: Text(
          'Measure',
          style: TextStyle(
            fontFamily: 'Inter',
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: SafeArea(
        child: CupertinoScrollbar(
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Column(
              children: [
                Container(height: 30, color: CupertinoColors.white),
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            color: AppColors.primary,
                            width: double.infinity,
                            child: Image.asset('assets/images/heart_rate.png'),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 50, // cách trên 20
                      left: 50, // cách trái 20
                      child: Container(
                        width: 100,
                        height: 100,
                        color: CupertinoColors.activeBlue,
                        child: Center(child: Text("Absolute")),
                      ),
                    ),
                  ],
                ),
                Container(height: 30, color: CupertinoColors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
