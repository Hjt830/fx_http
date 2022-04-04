// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:FxHttp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fx_http/fx_http.dart';
import 'package:sp_util/sp_util.dart';

void main() {
  setUp(() async {
    await SpUtil.getInstance();
    Log.init(tag: 'fx_http', isDebug: true);
    DioUtils.init("http://user.gmandarin.com/api/", isDebugMode: true, apiSuccessCode: 0, validateApiSuccess: (result)=> (0 == result.code && result.success));
    DioUtils.instance.enableConsoleLogging();
  });
  test("test fx_http", () {
    DioUtils.instance.requestNetwork<Map <String, dynamic>>(Method.get, "symbols").then((value) {
      Log.d('value: $value');
    });
  });
}
