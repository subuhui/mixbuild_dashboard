import 'package:flutter/widgets.dart';

class ResponsiveLayout {
  const ResponsiveLayout._(this.width);

  factory ResponsiveLayout.of(BuildContext context) {
    return ResponsiveLayout._(MediaQuery.sizeOf(context).width);
  }

  factory ResponsiveLayout.fromWidth(double width) {
    return ResponsiveLayout._(width);
  }

  final double width;

  static const double compactBreakpoint = 840;
  static const double mediumBreakpoint = 1180;
  static const double wideBreakpoint = 1440;

  bool get isCompact => width < compactBreakpoint;
  bool get isMedium => width >= compactBreakpoint && width < mediumBreakpoint;
  bool get isWide => width >= mediumBreakpoint;
  bool get isExtraWide => width >= wideBreakpoint;

  EdgeInsets get shellPadding {
    if (isCompact) {
      return const EdgeInsets.all(12);
    }
    if (isMedium) {
      return const EdgeInsets.all(18);
    }
    return const EdgeInsets.all(24);
  }

  EdgeInsets get contentPadding {
    if (isCompact) {
      return const EdgeInsets.fromLTRB(14, 14, 14, 10);
    }
    if (isMedium) {
      return const EdgeInsets.fromLTRB(18, 18, 18, 12);
    }
    return const EdgeInsets.fromLTRB(20, 18, 20, 12);
  }

  double get navRailWidth => isCompact ? 280 : 252;
  double get detailSidebarWidth => isMedium ? 320 : 380;
}
