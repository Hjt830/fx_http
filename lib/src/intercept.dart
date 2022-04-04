import 'dart:convert';
import 'dart:core';

import 'package:dio/dio.dart';
import 'package:fx_http/fx_http.dart';
import 'package:fx_http/src/utils/log_utils.dart';
import 'package:sprintf/sprintf.dart';
import 'error_handler.dart';

class LoggingInterceptor extends Interceptor {

  LoggingInterceptor({this.isJson = true});

  final bool isJson;
  late DateTime _startTime;
  late DateTime _endTime;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _startTime = DateTime.now();
    Log.d('----------Start----------');
    if (options.queryParameters.isEmpty) {
      Log.d('RequestUrl: ' + options.baseUrl + options.path);
      Log.d('RequestData: ${options.data.toString()}');
    } else {
      Log.d('RequestUrl: ' + options.baseUrl + options.path + '?' + Transformer.urlEncodeMap(options.queryParameters));
    }
    Log.d('RequestMethod: ' + options.method);
    Log.d('RequestHeaders:' + options.headers.toString());
    Log.d('RequestContentType: ${options.contentType}');
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _endTime = DateTime.now();
    int duration = _endTime.difference(_startTime).inMilliseconds;
    if (response.statusCode == ExceptionHandler.success) {
       Log.d('ResponseCode: ${response.statusCode}  ResponseUrl: ${response.requestOptions.baseUrl + response.requestOptions.path}');
    } else {
       Log.e('ResponseCode: ${response.statusCode}  ResponseUrl: ${response.requestOptions.baseUrl + response.requestOptions.path}');
    }
    // 输出结果
    if (this.isJson) {
      Log.json(response.data.toString());
    } else {
      Log.d(response.data);
    }
    Log.d('----------End: $duration 毫秒----------');
    super.onResponse(response, handler);
  }
  
  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    Log.e('----------Error Start-----------');
    Log.e('----------request:${err.requestOptions.baseUrl}${err.requestOptions.path}-----------');
    Log.e('----------error:$err-----------');
    Log.e('----------Error End-----------');
    super.onError(err, handler);
  }
}

class AdapterInterceptor extends Interceptor{

  static const String _kMsg = 'msg';
  static const String _kSlash = '\'';
  static const String _kMessage = 'message';

  static const String _kDefaultText = '\"无返回信息\"';
  static const String _kNotFound = '未找到查询信息';

  static const String _kFailureFormat = '{\"code\":%d,\"message\":\"%s\"}';
  static const String _kSuccessFormat = '{\"code\":0,\"data\":%s,\"message\":\"\"}';
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    Response r = adapterData(response);
    super.onResponse(r, handler);
  }
  
  @override
  void onError(DioError error, ErrorInterceptorHandler handler) {
    if (error.response != null) {
      adapterData(error.response!);
    }
    super.onError(error, handler);
  }

  Response adapterData(Response response) {
    String result;
    String content = (response.data == null) ? '' : response.data.toString();
    /// 成功时，直接格式化返回
    if (response.statusCode == ExceptionHandler.success || response.statusCode == ExceptionHandler.success_not_content) {
      if (content.isEmpty) {
        content = _kDefaultText;
      }
      result = sprintf(_kSuccessFormat, [content]);
      response.statusCode = ExceptionHandler.success;
    }
    else {
      if (response.statusCode == ExceptionHandler.not_found) {
        /// 错误数据格式化后，按照成功数据返回
        result = sprintf(_kFailureFormat, [response.statusCode, _kNotFound]);
        response.statusCode = ExceptionHandler.success;
      } else {
        if (content.isEmpty) {
          // 一般为网络断开等异常
          result = content;
        } else {
          String msg;
          try {
            content = content.replaceAll("\\", '');
            if (_kSlash == content.substring(0, 1)) {
              content = content.substring(1, content.length - 1);
            }
            Map<String, dynamic> map = json.decode(content);
            if (map.containsKey(_kMessage)) {
              msg = map[_kMessage];
            } else if (map.containsKey(_kMsg)) {
              msg = map[_kMsg];
            } else {
              msg = '未知异常';
            }
            result = sprintf(_kFailureFormat, [response.statusCode, msg]);
            // 401 token失效时，单独处理，其他一律为成功
            if (response.statusCode == ExceptionHandler.unauthorized) {
              response.statusCode = ExceptionHandler.unauthorized;
            } else {
              response.statusCode = ExceptionHandler.success;
            }
          } catch (e) {
            Log.d('异常信息：$e');
            // 解析异常直接按照返回原数据处理（一般为返回500,503 HTML页面代码）
            result = sprintf(_kFailureFormat, [response.statusCode, '服务器异常(${response.statusCode})']);
          }
        }
      }
    }
    response.data = result;
    return response;
  }
}

