import 'package:flutter/material.dart';
import '../core/constants.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < AppConstants.phoneBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= AppConstants.phoneBreakpoint &&
      MediaQuery.of(context).size.width < AppConstants.tabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= AppConstants.tabletBreakpoint;

  static double responsivePadding(BuildContext context) {
    if (isMobile(context)) return AppConstants.defaultPadding;
    if (isTablet(context)) return AppConstants.largePadding;
    return AppConstants.extraLargePadding;
  }

  static double responsiveWidth(BuildContext context, {double maxWidth = 600}) {
    final width = MediaQuery.of(context).size.width;
    if (width > maxWidth) return maxWidth;
    return width;
  }

  static int crossAxisCount(BuildContext context, {double itemWidth = 150}) {
    final width = MediaQuery.of(context).size.width;
    return (width / itemWidth).floor();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    if (size.width >= AppConstants.tabletBreakpoint && desktop != null) {
      return desktop!;
    }

    if (size.width >= AppConstants.phoneBreakpoint && tablet != null) {
      return tablet!;
    }

    return mobile;
  }
}

// Responsive grid view for library items
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double itemWidth;
  final double spacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.itemWidth = 150,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / itemWidth).floor();

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 1,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}
