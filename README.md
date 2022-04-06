# fx_http

一个基础的flutter网络请求工具，包含多种请求方式，自动数据转模型

可在 pub.dev 搜索 **'fx_http'** 使用

### 核心类 DioUtil
#### 1、配置 -- 使用前必须先初始化，指定接口服务器地址:
```
  /// 初始化DioUtil的参数 (也可以使用initOption)  **** 切记在使用DioUtils前初始化，推荐在main入口函数中调用 ****
  /// baseUrl           请求地址
  /// isDebugMode       调试模式, debug时会打印接口日志到控制台，弹出接口错误提示
  /// apiSuccessCode    api接口正确码
  /// sendTimeout       发送超时时间 (秒)
  /// connectTimeout    请求超时时间 (秒)
  /// receiveTimeout    接收超时时间 (秒)
  /// validateApiSuccess    根据返回的数据判断是否请求成功的闭包
  static init(String baseUrl, {bool isDebugMode = false, int apiSuccessCode = 0, int sendTimeout = 15, int connectTimeout = 15, int receiveTimeout = 15, ValidateApiSuccess? validateApiSuccess});

  /// 初始化
  DioUtils.init("https://github.com/", isDebugMode: true, apiSuccessCode: 0);

  也可以使用 DioUtils.initOption 初始化，自由度更高。
```

##### 1.1 可以开启debugMode下的控制台日志，使用前必须初始化打印工具（推荐在main入口函数中调用），可以指定tag, 指定运行模式(release模式下，Log.e, Log.json 不会在控制台输出):

```
  Log.init(tag: 'fx_http', isDebug: true);
  Log.d('Hello, Teeup Flutter Developers');
    
  /// 是否开启控制台日志 - 仅针对debug｜profile（release模式下默认关闭）
  void enableConsoleLogging({bool enable = true})
```

##### 1.2、如果需要切换接口的服务器地址，可以使用**updateOptions**方法来修改，后面所有的接口请求都会使用新的地址发器请求。
```
  /// 更改设置 (这里的更改是全局的 ====== 请注意使用)
  /// baseUrl       请求地址
  /// headers       请求头
  void updateOptions({String? baseUrl, Map<String, dynamic>? headers});
```
##### 1.3、添加拦截器（可以添加拦截器用于在请求发起前，或者收到response后做一些事情）
```
  /// 添加自定义拦截器 (可以添加请求头)
  void addInterceptors(Interceptor interceptor)
```
##### 1.4、开启代理抓包，可用于测试接口
```
  /// 开启抓包 (仅适用于非web端)
  void openProxy(String proxyIp, int proxyPort);
  // 关闭抓包
  void closeProxy();
```

##### 1.5、如果想取消所有请求，可以使用**cancelAllRequest**，如果想取消特定请求，可以使用**cancelRequest**
```
  /// 取消所有请求
  void cancelAllRequest();

  /// 根据请求地址取消特定请求 (请求)
  /// url  请求路径 比如：'trade/open'
  bool cancelRequest({String? url})
```

#### 2、发起请求，主要有四个方法可以使用:

##### 2.1 异步请求方式，采用异步回调的方式返回结果，数据直接在onSuccess、onSuccessList或者onPageSuccessList中获取。单个请求时可用这个方法，如果有多个请求互相依赖时使用这种方式会形成嵌套调用，就不推荐了。
```
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
  });
```

##### 2.2 Future请求方式，可以使用await阻塞同步返回结果，也可以使用then异步返回结果。单个、多个都可以使用该方法，数据需要自己从返回值里面取一下。 特别适用于FutureBuilder构建的组建中。
```
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
  })
```

##### 2.3 上传图片｜文件，Future请求方式，可以使用await阻塞同步返回结果，也可以使用then异步返回结果。
```
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
  })
```
##### 2.4 下载图片｜文件，Future请求方式，可以使用await阻塞同步返回结果，也可以使用then异步返回结果。
```
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
  });
```

#### 3、临时需要发起不同于主接口请求，但是又不想改变主服务器地址的，可以直接指定服务器接口地址，使用以下两个方法：

##### 3.1 异步请求方式，采用异步回调的方式返回结果，数据直接在onSuccess、onSuccessList或者onPageSuccessList中获取。单个请求时可用这个方法，如果有多个请求互相依赖时使用这种方式会形成嵌套调用，就不推荐了。
```
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
  })
```
##### 3.2 Future请求方式，可以使用await阻塞同步返回结果，也可以使用then异步返回结果。单个、多个都可以使用该方法，数据需要自己从返回值里面取一下。 特别适用于FutureBuilder构建的组建中。
```
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
  })
```

### 4、核心实体抽象类 BaseModel
建议所有**自定义模型**都实现BaseModel的抽象方法，方便接口请求数据可以统一的转模型，提高数据模型的标准性

```
  class TestModel implements BaseModel {
      int _age;
      String _sex;
      
      TestModel.fromJson(dynamic json) {
          _age = json["age"];
          _sex = json["sex"];
      }
      
      @override
      BaseModel fromJson(json) {
        return TestModel.fromJson(json);
      }
  
      @override
      Map<String, dynamic> toJson() {
          var map = <String, dynamic>{};
          map["age"] = _age;
          map["sex"] = _sex;
          return map;
      }
  }

  // 使用如下，传入model，返回的就已经是传入的model类型的数据了
  BaseEntity<TestModel> result = await DioHttp.requestNetwork<TestModel>(Method.get, Api.Symbol_List, queryParameters: params, model: TestModel());
  if (result.code == 0 && null != result.data) {
    Log.d(result.data!);
  }
```