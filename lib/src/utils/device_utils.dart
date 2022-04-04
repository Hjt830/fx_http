import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;

class Device {
  static bool get isDesktop => !isWeb && (isWindows || isLinux || isMacOS);
  static bool get isMobile => isAndroid || isIOS;
  static bool get isWeb => kIsWeb;

  static bool get isWindows => TargetPlatform.windows == defaultTargetPlatform;
  static bool get isLinux => TargetPlatform.linux == defaultTargetPlatform;
  static bool get isMacOS => TargetPlatform.macOS == defaultTargetPlatform;
  static bool get isAndroid => TargetPlatform.android == defaultTargetPlatform;
  static bool get isFuchsia => TargetPlatform.fuchsia == defaultTargetPlatform;
  static bool get isIOS => TargetPlatform.iOS == defaultTargetPlatform;
}