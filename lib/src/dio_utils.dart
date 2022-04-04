import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/adapter.dart';
import 'package:fx_http/fx_http.dart';
import 'package:fx_http/src/utils/device_utils.dart';
import 'package:fx_http/src/utils/log_utils.dart';
import 'package:oktoast/oktoast.dart';
import 'package:encrypt/encrypt.dart' as Encrypt;
import 'package:sp_util/sp_util.dart';

import 'base_entity.dart';
import 'error_handler.dart';
import 'intercept.dart';

///*************************************************************///
///*************************************************************///
///*********************** 用户账户管理类 ************************///
///*************************************************************///
///*************************************************************///

/// 简写使用 DioHttp
// ignore: non_constant_identifier_names
DioUtils DioHttp = DioUtils.instance;

/// 用于自定义判断接口返回的数据是否正确
typedef ValidateApiSuccess = bool Function(BaseEntity data);

const FxProxyCacheKey = 'fx_HttpProxyCacheKey';

BaseOptions defaultBaseOptions = BaseOptions(
  sendTimeout: 15000,
  connectTimeout: 15000,
  receiveTimeout: 15000,
  responseType: ResponseType.plain,
  validateStatus: (status) {
    // 不使用http状态码判断状态，使用AdapterInterceptor来处理（适用于标准REST风格）
    if (null != status && 200 <= status && status < 300) {
      return true;
    } else {
      return false;
    }
  },
  contentType: "application/json;charset=utf-8",
  headers: {
    'x-api-lang': 'en',
    'x-app-client':'1.0',
    'x-api-version': 'v1',
    'Accept': 'application/json'
  }
);

class DioUtils {
  static int apiSuccessCode = 0;       // 服务端定义的成功码
  static bool _isDebugMode = false; // 是否是debug模式  (debug模式下会将弹出Toast显示错误信息，方便排查问题)
  static String _baseUrl = '';      // 请求接口的域名  (比如: "https://xyz.com/api/app/")
  static int _sendTimeout = 15;     // 发送超时时间(秒)
  static int _connectTimeout = 15;  // 连接超时时间(秒)
  static int _receiveTimeout = 15;  // 接收超时时间(秒)
  static ValidateApiSuccess validateApiSuccess = defaultValidateApiSuccess;
  static BaseOptions? options;
  static String? _proxyHost;        // 代理ip地址
  static int? _proxyPort;           // 代理端口号

  bool _enableConsoleLogging = false;
  Map<String, CancelToken> _cancelTokenMap = <String, CancelToken>{};

  // 单例
  static DioUtils get instance => DioUtils();
  static final DioUtils _singleton = DioUtils._();
  factory DioUtils() => _singleton;

  Dio get dio => _dio;
  static late Dio _dio;

  // 构造方法
  DioUtils._() {
    if (null == DioUtils.options) {
      Log.e("请初始化DioUtils后再使用，DioUtils.init / DioUtils.initOption");
      DioUtils.options = defaultBaseOptions;
    }
    _dio = Dio(DioUtils.options);
    (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate =
        (HttpClient client) {
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    };
    // 读取抓包代理缓存, 并设置代理
    var proxyCache = SpUtil.getString(FxProxyCacheKey);
    if (proxyCache != null && proxyCache.isNotEmpty) {
      try {
        Map<String, dynamic> map = json.decode(proxyCache);
        _proxyHost = map['host'];
        _proxyPort = map['port'];
        if ((Device.isMobile || Device.isDesktop) && _proxyHost != null && _proxyHost!.isNotEmpty && _proxyPort != null && _proxyPort! > 0) {
          /// Fiddler抓包代理配置 https://www.jianshu.com/p/d831b1f7c45b
          (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (HttpClient client) {
            client.findProxy = (uri) {
              return 'PROXY $_proxyHost:$_proxyPort';
            };
          };
        }
      } catch(e) {
        print('读取抓包代理缓存失败: $e');
      }
    }
  }

  // 默认的验证api接口返回结果正确的方式
  static ValidateApiSuccess get defaultValidateApiSuccess {
    return (BaseEntity data) => (DioUtils.apiSuccessCode == data.code) && data.success;
  }

  ////////////////////////////////////////////////////////////////
  /////////////// 初始化DioUtils 必须初始化才能使用 //////////////////
  ////////////////////////////////////////////////////////////////

  /// 初始化DioUtil的参数 (也可以使用initOption)  **** 切记在使用DioUtils前初始化，推荐在main入口函数中调用 ****
  /// baseUrl           请求地址
  /// isDebugMode       调试模式, debug时会打印接口日志到控制台，弹出接口错误提示
  /// apiSuccessCode    api接口正确码
  /// sendTimeout       发送超时时间 (秒)
  /// connectTimeout    请求超时时间 (秒)
  /// receiveTimeout    接收超时时间 (秒)
  /// validateApiSuccess    根据返回的数据判断是否请求成功的闭包
  static init(String baseUrl, {bool isDebugMode = false, int apiSuccessCode = 0, int sendTimeout = 15, int connectTimeout = 15, int receiveTimeout = 15, ValidateApiSuccess? validateApiSuccess}) {
    _baseUrl = baseUrl;
    _isDebugMode = isDebugMode;
    _sendTimeout = sendTimeout;
    _connectTimeout = connectTimeout;
    _receiveTimeout = receiveTimeout;
    DioUtils.apiSuccessCode = apiSuccessCode;
    DioUtils.options = defaultBaseOptions.copyWith(
      sendTimeout: _sendTimeout * 1000,
      connectTimeout: _connectTimeout * 1000,
      receiveTimeout: _receiveTimeout * 1000,
      baseUrl: _baseUrl
    );
    if (null != validateApiSuccess) {
      DioUtils.validateApiSuccess = validateApiSuccess;
    }
  }

  /// 初始化DioUtil的参数  **** 切记在使用DioUtils前初始化，推荐在main入口函数中调用 ****
  /// options           构建dio时用到的配置
  /// isDebugMode       调试模式, debug时会打印接口日志到控制台，弹出接口错误提示
  /// apiSuccessCode    api接口正确码
  /// validateApiSuccess    根据返回的数据判断是否请求成功的闭包
  static initOption(BaseOptions options, {bool isDebugMode = false, int apiSuccessCode = 0, ValidateApiSuccess? validateApiSuccess}) {
    DioUtils.options = options;
    DioUtils.apiSuccessCode = apiSuccessCode;
    if (null != validateApiSuccess) {
      DioUtils.validateApiSuccess = validateApiSuccess;
    }
  }

  /// 更改设置 (这里的更改是全局的 ====== 请注意使用)
  /// baseUrl       请求地址
  /// headers       请求头
  void updateOptions({String? baseUrl, Map<String, dynamic>? headers}) {
    if (null != baseUrl && !TextUtil.isEmpty(baseUrl)) {
      _dio.options.baseUrl = baseUrl;
    }
    if (null != headers && headers.isNotEmpty) {
      _dio.options.headers.addAll(headers);
    }
    cancelAllRequest();
  }
  /// 取消所有请求
  void cancelAllRequest() {
    _cancelTokenMap.removeWhere((key, value) {
      if (!value.isCancelled) {
        value.cancel(["主动取消了请求"]);
      }
      return true;
    });
  }
  /// 根据请求地址取消特定请求 (请求)
  /// url  请求路径 比如：'trade/open'
  bool cancelRequest({String? url}) {
    if (null != url && !TextUtil.isEmpty(url) && _cancelTokenMap.containsKey(url)) {
      if (!_cancelTokenMap[url]!.isCancelled) {
        _cancelTokenMap[url]!.cancel(["主动取消了请求"]);
      }
    }
    return false;
  }

  ////////////////////////////////////////////////////////////////
  /////////////////////////// public method //////////////////////

  /// 是否开启控制台日志 - 仅针对debug｜profile（release模式下默认关闭）
  void enableConsoleLogging({bool enable = true}) {
    if (_isDebugMode) {
      _enableConsoleLogging = enable;
      // 先移除相同的拦截器，避免重复添加
      _dio.interceptors.removeWhere((element) => element is LoggingInterceptor);
      if (enable) {
        _dio.interceptors.add(LoggingInterceptor());
      }
    }
  }
  /// 是否开启window日志 - 仅针对debug｜profile（release模式下默认关闭）& 非web
  void enableWindowLogging({bool enable = true}) {
    if (_isDebugMode && !Device.isWeb) {
      // 先移除相同的拦截器，避免重复添加
      _dio.interceptors.removeWhere((element) => element is AdapterInterceptor);
      if (enable) {
        _dio.interceptors.add(AdapterInterceptor());
      }
    }
  }
  /// 添加自定义拦截器 (可以添加请求头)
  void addInterceptors(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
  }
  /// 开启抓包 (仅适用于非web端)
  void openProxy(String proxyIp, int proxyPort) {
    if ((Device.isMobile || Device.isDesktop) && proxyIp.isNotEmpty && proxyPort > 0) {
      /// Fiddler抓包代理配置 https://www.jianshu.com/p/d831b1f7c45b
      _proxyHost = proxyIp;
      _proxyPort = proxyPort;
      (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate =
          (HttpClient client) {
        client.findProxy = (uri) {
          return 'PROXY $proxyIp:$proxyPort';
        };
      };
      SpUtil.putString(FxProxyCacheKey, json.encode({'host': proxyIp, 'port': proxyPort}));
    }
  }
  // 关闭抓包
  void closeProxy() {
    _proxyHost = null;
    _proxyPort = null;
    SpUtil.remove(FxProxyCacheKey);
    // 移除代理
    (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate =
        (HttpClient client) {
      client.findProxy = (uri) {
        return 'DIRECT';
      };
    };
  }

  /// brief http请求 (通过回调函数回调结果)
  /// @param method             请求方式
  /// @param api                接口地址
  /// @param params             post请求参数
  /// @param queryParameters    get请求参数
  /// @param isShow             请求时是否显示吐司
  /// @param isPageData         是否是分页数据
  /// @param isList             是否是列表数据
  /// @param model              要解析的数据模型
  /// @param onSuccess          请求成功回调 (返回数据)
  /// @param onSuccessList      请求成功回调 (返回列表数据)
  /// @param onPageSuccessList  请求成功回调 (返回分页列表数据)
  /// @param onError            请求失败回调
  /// @param cancelToken        取消请求的token
  /// @param options            对请求的设置
  void asyncRequestNetwork<T>(Method method, String api, {
    dynamic params,
    Map<String, dynamic>? queryParameters,
    bool isShow : false,      // 是否显示加载吐司
    bool isPageData : false,  // 是否是分页数据
    bool isList : false,
    BaseModel? model,
    Function(T? t)? onSuccess,
    Function(List<T> list)? onSuccessList,
    Function(List<T> list, int total, int perPage, int currentPage)? onPageSuccessList,
    Function(int code, String msg)? onError,
    CancelToken? cancelToken,
    Options? options
  }) {
    String m = getRequestMethod(method);
    Stream.fromFuture(_request<T>(m, api, data: params, isPageData: isPageData, isShow: isShow, model: model, queryParameters: queryParameters, options: options, cancelToken: cancelToken))
        .asBroadcastStream()
        .listen((result) {

        if (result.code == 0) {
          if (isPageData) {
            if (onPageSuccessList != null) {
              onPageSuccessList(result.pageData.data, result.pageData.total, result.pageData.perPage, result.pageData.currentPage);
            }
          }
          else {
            if (isList) {
              if (onSuccessList != null) {
                onSuccessList(result.listData);
              }
            } else {
              if (onSuccess != null) {
                onSuccess(result.data);
              }
            }
          }
        } else {
          _onError(result.code, result.message, '$_baseUrl$api', false, onError: onError);
        }
    }, onError: (e) {
      bool isToastInit = EasyLoading.instance.overlayEntry != null;
      if (isToastInit && isShow) {
        EasyLoading.dismiss();
      }
      _cancelLogPrint(e, api);
      NetError error = ExceptionHandler.handleException(e);
      _onError(error.code, error.msg, '$_baseUrl$api', true, onError: onError);
    });
  }

  /// brief http请求 (通过Future方式请求，可以使用await阻塞直到获取到结果)
  /// @param method             请求方式
  /// @param url                接口地址
  /// @param isPageData         是否是分页数据
  /// @param params             post请求参数
  /// @param queryParameters    get请求参数
  /// @param model              要解析的数据模型
  /// @param cancelToken        取消请求的token
  /// @param options            对请求的设置
  Future<BaseEntity<T>> requestNetwork<T>(Method method, String url, {
    bool isPageData = false,
    bool isShow = false,      // 是否显示加载吐司
    dynamic params,
    Map<String, dynamic>? queryParameters,
    BaseModel? model,
    CancelToken? cancelToken,
    Options? options
  }) {
    String m = getRequestMethod(method);
    return _request<T>(m, url,
        isPageData: isPageData,
        isShow: isShow,
        data: params,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        model: model
    );
  }

  /// brief 上传图片 (通过Future方式请求，可以使用await阻塞直到获取到结果)
  /// @param url                接口地址
  /// @param filePath           图片地址
  /// @param attachmentType     上传附件类型
  /// @param customAttachmentType     上传附件类型 (attachmentType为custom时，取customAttachmentType的值， 若为空默认为"system")
  /// @param fileName           图片名字
  /// @param mime               图片格式
  /// @param showProgress       是否显示上传进度
  /// @param onSendProgress     发送文件进度回调
  /// @param onReceiveProgress  接收文件进度回调
  /// @param cancelToken        取消请求的token
  /// @param options            对请求的设置
  Future<BaseEntity<T>>uploadImage<T>(String url, String filePath, AttachmentType attachmentType, {
    String? customAttachmentType,
    String? fileName,
    String mime = 'png',
    bool showProgress = false,
    bool isShow = false,      // 是否显示加载吐司
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    Options? options
  }) async {
      assert(!Device.isWeb, "此上传图片方法不适用于web端");

      try {
        String path = filePath;
        String name = fileName ?? DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(1000).toString();
        String type = (AttachmentType.custom == attachmentType) ? customAttachmentType??'system' : getAttachmentType(attachmentType);
        FormData formData = FormData.fromMap({
          "file": await MultipartFile.fromFile(path, filename: name),
          "type": type
        });
        bool isToastInit = EasyLoading.instance.overlayEntry != null;
        if (isToastInit && isShow) EasyLoading.show();
        var response = await _dio.post(url, data: formData, cancelToken: cancelToken, options: options, onReceiveProgress: onReceiveProgress, onSendProgress: (int count, int total) {
          if (isToastInit && showProgress && total > 0) {
            double progress = count * 1.0/total * 1.0;
            EasyLoading.showProgress(progress, status: '${progress.toStringAsFixed(0)}%');
            if (progress == 1.0) {
              EasyLoading.dismiss(animation: true);
            }
          }
          if (null != onSendProgress) {
            onSendProgress(count, total);
          }
        });
        if (isToastInit && isShow) EasyLoading.dismiss();
        Map<String, dynamic> _map = await compute(_parseData, response.data.toString());
        return BaseEntity.fromJson(_map, isPageData: false);
      } catch(e) {
        bool isToastInit = EasyLoading.instance.overlayEntry != null;
        if (isToastInit && isShow) EasyLoading.dismiss();
        if (_isDebugMode && !Device.isWeb) {  // debug模式下显示error
          showToast('url: $url, code: ${ExceptionHandler.parse_error}, msg: 数据解析错误');
        }  else {
          Log.e('url: $url, exception: $e');
        }
        return BaseEntity(0, false, ExceptionHandler.parse_error, "数据解析错误", null);
      }
  }

  /// brief 下载文件 (通过Future方式请求，可以使用await阻塞直到获取到结果)
  /// @param uri                文件地址
  /// @param savePath           文件保存地址
  /// @param showProgress       是否显示下载进度
  /// @param deleteOnError      下载失败后删除文件
  /// @param onReceiveProgress  接收文件进度回调
  /// @param cancelToken        取消请求的token
  /// @param options            对请求的设置
  Future<bool>downloadFile(Uri uri, String savePath, AttachmentType attachmentType, {
    Map? data,
    bool showProgress = false,
    bool deleteOnError = true,
    bool isShow = false,      // 是否显示加载吐司
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    Options? options
  }) async {
      assert(!Device.isWeb, "此下载文件方法不适用于web端");

      try {
        bool isToastInit = EasyLoading.instance.overlayEntry != null;
        if (isToastInit && isShow) EasyLoading.show();
        var response = await _dio.downloadUri(uri, savePath, data: data, cancelToken: cancelToken, deleteOnError: deleteOnError, options: options, onReceiveProgress: (int count, int total) {
          if (isToastInit && showProgress && total > 0) {
            double progress = count * 1.0 / total * 1.0;
            EasyLoading.showProgress(progress, status: '${progress.toStringAsFixed(0)}%');
            if (progress == 1.0) {
              EasyLoading.dismiss(animation: true);
            }
          }
          if (null != onReceiveProgress) {
            onReceiveProgress(count, total);
          }
        });
        if (isToastInit && isShow) EasyLoading.dismiss();
        if (null != response.statusCode && response.statusCode! >= 200 && response.statusCode! < 300) {
          return true;
        } else {
          return false;
        }
      } catch(e) {
        Log.d('DioUtils download exception: $e');
        bool isToastInit = EasyLoading.instance.overlayEntry != null;
        if (isToastInit && isShow) EasyLoading.dismiss();
        return false;
      }
  }

  // web上传图片
  /*Future<void> uploadImageForWeb(String url, String imageFilePath, String filename, Uint8List imageBytes, Attachment_type attachmentType, {void onData(var event), Function onError, void onDone(), bool cancelOnError}) async {
    String urlStr = ApiConfig.getBaseURL() + url;
    var tokenType = SpUtil.getString(AppConfig.tokenType);
    tokenType = TextUtil.isEmpty(tokenType) ? 'Bearer' : tokenType;
    var accessToken = SpUtil.getString(ApiConfig.accessToken);
    String appVersion = '1.0';
    String apiVersion = 'v1';
    String language = Translations.getHttpHeaderLangCode();
    var headers = Map<String, String>();
    if (accessToken.isNotEmpty) {
      headers['Authorization'] = '$tokenType $accessToken';
    }
    headers['Accept'] = 'application/json';
    headers['Content-Type'] = "multipart/form-data";
    headers['x-api-lang']   = language;
    headers['x-api-version'] = apiVersion;
    headers['x-app-version'] = appVersion;

    var stream = new http.ByteStream.fromBytes(imageBytes);
    int length = imageBytes.length;
    var request = new http.MultipartRequest("POST", Uri.parse(urlStr));
    var multipartFile = new http.MultipartFile('file', stream, length,
        filename: filename,
        contentType: MediaType('image', 'png'));
    request.files.add(multipartFile);
    request.headers.addAll(headers);
    request.fields.addAll({"type": ((attachmentType.toString()).split('.').last).toString()});
    EasyLoading.show();
    var response = await request.send();
    response.stream.transform(utf8.decoder).listen((value) {
      EasyLoading.dismiss();
      var result = json.decode(value);
      if (onData != null) onData(result);
    }, onError: (e){
      EasyLoading.dismiss();
      if (onError != null) onError(e);
    }, onDone: (){
      EasyLoading.dismiss();
      if (onDone != null) onDone();
    }, cancelOnError: cancelOnError);
  }*/

  /////////////////////////////////////////////////////////////////
  /////////////////////////// private method //////////////////////

  // 数据返回格式统一，统一处理异常
  Future<BaseEntity<T>> _request<T>(String method, String url, {
    bool isPageData = false,
    bool isShow = false,
    BaseModel? model,
    dynamic data, Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options
  }) async {
    try {
      // 添加cancelToken到列表
      CancelToken theToken = cancelToken??CancelToken();
      _cancelTokenMap[url] = theToken;
      // 显示弹窗
      bool isToastInit = EasyLoading.instance.overlayEntry != null;
      if (isToastInit && isShow) EasyLoading.show();
      // 解析数据
      var response = await _dio.request(url, data: data, queryParameters: queryParameters, options: _checkOptions(method, options: options), cancelToken: theToken);
      // 从列表中移除cancelToken
      if (_cancelTokenMap.values.contains(theToken)) _cancelTokenMap.remove(url);
      // 移除弹窗
      if (isToastInit && isShow) EasyLoading.dismiss();

      Map<String, dynamic> _map = await compute(_parseData, response.data.toString());
      BaseEntity<T> result = BaseEntity.fromJson(_map, isPageData: isPageData, model: model);
      // 请求错误时的弹窗
      if (!Device.isWeb && isShow && !DioUtils.validateApiSuccess(result) && !TextUtil.isEmpty(result.message)) {
        showToast(result.message);
      }
      return result;
    } catch(e) {
      bool isToastInit = EasyLoading.instance.overlayEntry != null;
      if (isToastInit && isShow) EasyLoading.dismiss();
      if (_isDebugMode && !Device.isWeb) {  // debug模式下显示error
        showToast('url: $url, code: ${ExceptionHandler.parse_error}, msg: 数据解析错误');
      } else {
        Log.e('url: $url, exception: $e');
      }
      return BaseEntity(0, false, ExceptionHandler.parse_error, "数据解析错误", null);
    }
  }

  Options _checkOptions(method, {Options? options}) {
    Options newOptions = (options == null) ? Options() : options;
    newOptions.method = method;
    return newOptions;
  }

  void _cancelLogPrint(dynamic e, String url) {
    if (e is DioError && CancelToken.isCancel(e)) {
      Log.e('取消请求接口： $url');
    }
  }

  void _onError(int code, String msg, String url, bool isHttpException, {Function(int code, String mag)? onError}) {
    String type = isHttpException ? "" : "服务端逻辑处理报错";
    Log.e('接口请求异常 ($type)： url: $url, code: $code, msg: $msg');
    if (onError != null) {
      onError(code, msg);
    }
  }

  Map<String, dynamic> _getDefaultHttpHeader() {
    return {
      'x-api-lang': 'en',
      'x-app-client':'1.0',
      'x-api-version': 'v1',
      'Accept': 'application/json'
    };
  }
}

Map<String, dynamic> _parseData(String data) {
  return json.decode(data);
}

// 附件上传类型
enum AttachmentType {
  identityCard,     // id卡
  avatar,           // 头像
  bank,             // 银行卡
  voucher,          // 券
  system,           // 系统
  message,          // 消息
  custom
}
// http请求方式
enum Method {
  get,
  post,
  put,
  patch,
  delete,
  head
}
String getAttachmentType(AttachmentType type) {
  String m;
  switch(type) {
    case AttachmentType.identityCard:
      m = 'identityCard';
      break;
    case AttachmentType.avatar:
      m = 'avatar';
      break;
    case AttachmentType.bank:
      m = 'bank';
      break;
    case AttachmentType.voucher:
      m = 'voucher';
      break;
    case AttachmentType.system:
      m = 'system';
      break;
    case AttachmentType.message:
      m = 'message';
      break;
    case AttachmentType.custom:
      m = 'system';
      break;
  }
  return m;
}
String getRequestMethod(Method method) {
  String m;
  switch(method) {
    case Method.get:
      m = 'GET';
      break;
    case Method.post:
      m = 'POST';
      break;
    case Method.put:
      m = 'PUT';
      break;
    case Method.patch:
      m = 'PATCH';
      break;
    case Method.delete:
      m = 'DELETE';
      break;
    case Method.head:
      m = 'HEAD';
      break;
  }
  return m;
}


////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///////////// 使用新的Dio发起请求，可以自定义baseUrl，path...等所有参数 /////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////


extension newDioRequest on DioUtils {

  /// brief http请求 (通过回调函数回调结果)
  /// @param method             请求方式
  /// @param url                接口地址
  /// @param params             post请求参数
  /// @param queryParameters    get请求参数
  /// @param isShow             请求时是否显示吐司
  /// @param isPageData         是否是分页数据
  /// @param isList             是否是列表数据
  /// @param model              要解析的数据模型
  /// @param onSuccess          请求成功回调 (返回数据)
  /// @param onSuccessList      请求成功回调 (返回列表数据)
  /// @param onPageSuccessList  请求成功回调 (返回分页列表数据)
  /// @param onError            请求失败回调
  /// @param cancelToken        取消请求的token
  /// @param options            对请求的设置
  /// @param needDecrypt        是否需要对结果解密
  /// @param secret             解密密钥
  /// @param interceptors       要添加的拦截器
  /// @param isJson             后台返回的结果是否是json字符串
  void newAsyncRequestNetwork<T>(String baseUrl, String path, Method method, {
    dynamic params,
    Map<String, dynamic>? queryParameters,
    bool isShow = false,      // 是否显示加载吐司
    bool isPageData = false,  // 是否是分页数据
    bool isList = false,
    BaseModel? model,
    Function(T? t)? onSuccess,
    Function(List<T> list)? onSuccessList,
    Function(List<T> list, int total, int perPage, int currentPage)? onPageSuccessList,
    Function(int code, String msg)? onError,
    CancelToken? cancelToken,
    Options? options,
    bool needDecrypt = false,
    String? secret,
    List<Interceptor>? interceptors,
    int sendTimeout = 15,
    int connectTimeout = 15,
    int receiveTimeout = 15,
    bool isJson = true
  }) {
    String m = getRequestMethod(method);
    Stream.fromFuture(
        _requestWithNewDio<T>(baseUrl, path, m,
            isPageData: isPageData,
            isShow: isShow,
            data: params,
            queryParameters: queryParameters,
            options: options,
            cancelToken: cancelToken,
            model: model,
            needDecrypt: needDecrypt,
            secret: secret,
            interceptors: interceptors,
            sendTimeout: sendTimeout,
            connectTimeout: connectTimeout,
            receiveTimeout: receiveTimeout,
            isJson: isJson
        )
    ).asBroadcastStream()
     .listen((result) {

      if (result.code == 0) {
        if (isPageData) {
          if (onPageSuccessList != null) {
            onPageSuccessList(result.pageData.data, result.pageData.total, result.pageData.perPage, result.pageData.currentPage);
          }
        }
        else {
          if (isList) {
            if (onSuccessList != null) {
              onSuccessList(result.listData);
            }
          } else {
            if (onSuccess != null) {
              onSuccess(result.data);
            }
          }
        }
      } else {
        _onError(result.code, result.message, '$baseUrl$path', false, onError: onError);
      }
    }, onError: (e) {
      bool isToastInit = EasyLoading.instance.overlayEntry != null;
      if (isToastInit && isShow) {
        EasyLoading.dismiss();
      }
      _cancelLogPrint(e, '$baseUrl$path');
      NetError error = ExceptionHandler.handleException(e);
      _onError(error.code, error.msg, '$baseUrl$path', true, onError: onError);
    });
  }

  /// brief http请求 (通过Future方式请求，可以使用await阻塞直到获取到结果)
  /// @param method             请求方式
  /// @param url                接口地址
  /// @param isPageData         是否是分页数据
  /// @param params             post请求参数
  /// @param queryParameters    get请求参数
  /// @param model              要解析的数据模型
  /// @param cancelToken        取消请求的token
  /// @param options            对请求的设置
  /// @param needDecrypt        是否需要对结果解密
  /// @param secret             解密密钥
  /// @param interceptors       要添加的拦截器
  /// @param isJson             后台返回的结果是否是json字符串
  Future<BaseEntity<T>> newRequestNetwork<T>(String baseUrl, String path, Method method, {
    dynamic params,
    Map<String, dynamic>? queryParameters,
    bool isShow : false,      // 是否显示加载吐司
    bool isPageData : false,  // 是否是分页数据
    BaseModel? model,
    CancelToken? cancelToken,
    Options? options,
    bool needDecrypt = false,
    String? secret,
    List<Interceptor>? interceptors,
    int sendTimeout = 15,
    int connectTimeout = 15,
    int receiveTimeout = 15,
    bool isJson = true
  }) {
    String m = getRequestMethod(method);
    return _requestWithNewDio<T>(baseUrl, path, m,
        isPageData: isPageData,
        isShow: isShow,
        data: params,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        model: model,
        needDecrypt: needDecrypt,
        secret: secret,
        interceptors: interceptors,
        sendTimeout: sendTimeout,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        isJson: isJson
    );
  }

  /// 数据返回格式统一，统一处理异常
  /// @param needDecrypt        是否需要对结果解密
  /// @param secret             解密密钥, 当needDecrypt为true时必传，否则报错
  /// @param interceptors       要添加的拦截器
  /// @param isJson             后台返回的结果是否是json字符串
  Future<BaseEntity<T>> _requestWithNewDio<T>(String baseUrl, String path, String method, {
      bool isPageData = false,
      bool isShow = false,
      BaseModel? model,
      dynamic data,
      Map<String, dynamic>? queryParameters,
      CancelToken? cancelToken,
      Options? options,
      bool needDecrypt = false,
      String? secret,
      List<Interceptor>? interceptors,
      int sendTimeout = 15,
      int connectTimeout = 15,
      int receiveTimeout = 15,
      bool isJson = true
      }) async {
    try {
      assert(!needDecrypt || (needDecrypt && !TextUtil.isEmpty(secret)), "needDecrypt为true时，secret不可为空, url: $baseUrl$path");

      var baseOption = BaseOptions(
        sendTimeout: sendTimeout * 1000,
        connectTimeout: connectTimeout * 1000,
        receiveTimeout: receiveTimeout * 1000,
        responseType: ResponseType.plain,
        validateStatus: (status) {
          // 不使用http状态码判断状态，使用AdapterInterceptor来处理（适用于标准REST风格）
          return true;
        },
        baseUrl: baseUrl,
        headers: _getDefaultHttpHeader(),
        contentType: "application/json;charset=utf-8",
      );
      Dio newDio = Dio(baseOption);
      // 添加控制台打印拦截器
      if (DioUtils._isDebugMode && _enableConsoleLogging) {
        newDio.interceptors.add(LoggingInterceptor(isJson: isJson));
      }
      // 添加传入的拦截器
      if (null != interceptors && interceptors.length > 0) {
        newDio.interceptors.addAll(interceptors);
      }
      // 忽略证书校验 (测试打的新的0.1.3的tag)
      (newDio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate =
          (HttpClient client) {
        client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      };
      // 添加代理, 用于抓包
      if (!Device.isWeb && !TextUtil.isEmpty(DioUtils._proxyHost) && null != DioUtils._proxyPort && DioUtils._proxyPort! > 0) {
        (newDio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate =
            (HttpClient client) {
          client.findProxy = (uri) {
            return 'PROXY ${DioUtils._proxyHost}:${DioUtils._proxyPort}';
          };
        };
      }
      // 显示弹窗
      bool isToastInit = EasyLoading.instance.overlayEntry != null;
      if (isToastInit && isShow) EasyLoading.show();
      // 解析数据
      var response = await newDio.request(path, data: data, queryParameters: queryParameters, options: _checkOptions(method, options: options), cancelToken: cancelToken);
      // 移除弹窗
      if (isToastInit && isShow) EasyLoading.dismiss();

      String responseDataStr = response.data.toString();
      // 如果需要解密
      if (needDecrypt) {
        if (TextUtil.isEmpty(secret)) {
          return BaseEntity(0, false, ExceptionHandler.forbidden, '当needDecrypt为true时secret必传 url: $baseUrl$path', null);
        }
        // 解密
        responseDataStr = _aesDecryptString(responseDataStr, secret!);
      }
      Map<String, dynamic> _map = await compute(_parseData, responseDataStr);
      BaseEntity<T> result = BaseEntity.fromJson(_map, isPageData: isPageData, model: model);
      // 请求错误时的弹窗
      if (!Device.isWeb && isShow && (0 != result.code || !result.success) && !TextUtil.isEmpty(result.message)) {
        showToast(result.message);
      }
      return result;
    } catch(e) {
      bool isToastInit = EasyLoading.instance.overlayEntry != null;
      if (isToastInit && isShow) EasyLoading.dismiss();
      if (DioUtils._isDebugMode && !Device.isWeb) {  // debug模式下显示error
        showToast('url: $baseUrl$path, code: ${ExceptionHandler.parse_error}, msg: 数据解析错误');
      } else {
        Log.e('url: $baseUrl$path, exception: $e');
      }
      return BaseEntity(0, false, ExceptionHandler.parse_error, "数据解析错误", null);
    }
  }

  // aes - cbc 默认key解密
  String _aesDecryptString(String encryptString, String secret) {
    final key = Encrypt.Key.fromUtf8(secret);
    final iv = Encrypt.IV.fromUtf8(secret);
    final encryter = Encrypt.Encrypter(Encrypt.AES(key, mode: Encrypt.AESMode.cbc));
    return encryter.decrypt64(encryptString, iv: iv);
  }
}