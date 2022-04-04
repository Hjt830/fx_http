import 'package:flutter_test/flutter_test.dart';
import 'package:fx_http/fx_http.dart';

void main() {

  setUp((){
    Log.init(tag: 'fx_http', isDebug: true);
    DioUtils.init("http://user.gmandarin.com/api/", isDebugMode: true, apiSuccessCode: 0, validateApiSuccess: (result)=> (0 == result.code && result.success));
    DioUtils.instance.enableConsoleLogging();
  });

  test('asyncRequestNetwork', () {
    DioUtils.instance.asyncRequestNetwork<Map <String, dynamic>>(Method.get, "symbols", onSuccess: (Map<String, dynamic>? json) {
      Log.d('json: $json');
    }, onError: (int code, String msg) {
      Log.d('code: $code,  msg: $msg');
    });
  });

  test('requestNetwork', () {
     DioUtils.instance.requestNetwork<Map <String, dynamic>>(Method.get, "symbols").then((value) {
      Log.d('value: $value');
    });
  });
}
