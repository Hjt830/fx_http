# fx_http

### name: fx_http
### version: 0.0.1
### author: kenter
### homePage: https://github.com/teeup-flutter/fx_http.git
### description: Teeup flutter的组件库基础设施建 -- 网络请求工具库

## Getting Started

### 核心类 DioUtil
使用前必须先初始化，指定接口服务器地址:
```
    DioUtils.init("https://user.gqfxcn.com/api/", true);
```

主要有三个方法可以使用:
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
      void asyncRequestNetwork<T>(Method method, String url, {
        dynamic params,
        Map<String, dynamic> queryParameters,
        bool isShow : false,      // 是否显示加载吐司
        bool isPageData : false,  // 是否是分页数据
        bool isList : false,
        BaseModel model,
        Function(T t) onSuccess,
        Function(List<T> list) onSuccessList,
        Function(List<T> list, int total, int perPage, int currentPage)onPageSuccessList,
        Function(int code, String msg) onError,
        CancelToken cancelToken,
        Options options
      }) {}
```

```
      /// brief http请求 (通过Future方式请求，可以使用await阻塞直到获取到结果)
      /// @param method             请求方式
      /// @param url                接口地址
      /// @param params             post请求参数
      /// @param queryParameters    get请求参数
      /// @param model              要解析的数据模型
      /// @param cancelToken        取消请求的token
      /// @param options            对请求的设置
      Future<BaseEntity<T>> requestNetwork<T>(Method method, String url, {
        dynamic params,
        Map<String, dynamic> queryParameters,
        BaseModel model,
        CancelToken cancelToken,
        Options options
      }) {}
```

上传图片

```
      /// brief 上传图片 (通过Future方式请求，可以使用await阻塞直到获取到结果)
      /// @param url                接口地址
      /// @param filePath           图片地址
      /// @param attachmentType     上传附件类型
      /// @param fileName           图片名字
      /// @param mime               图片格式
      /// @param showProgress       是否显示上传进度
      /// @param onSendProgress     发送文件进度回调
      /// @param onReceiveProgress  接收文件进度回调
      /// @param cancelToken        取消请求的token
      /// @param options            对请求的设置
      Future<BaseEntity<T>>uploadImage<T>(String url, String filePath, AttachmentType attachmentType, {
        String fileName,
        String mime = 'png',
        bool showProgress = false,
        ProgressCallback onSendProgress,
        ProgressCallback onReceiveProgress,
        CancelToken cancelToken,
        Options options
      }) {}
```

### 核心实体类 BaseModel
建议所有<#自定义类型#>都实现BaseModel的抽象方法，方便接口请求数据可以统一的转模型，提高数据模型的标准性

```
    class Test implements BaseModel {
        int _age;
        String _sex;
        
        Test.fromJson(dynamic json) {
            _age = json["age"];
            _sex = json["sex"];
        }
        
        @override
        BaseModel fromJson(json) {
          return Test.fromJson(json);
        }
    
        @override
        Map<String, dynamic> toJson() {
            var map = <String, dynamic>{};
            map["age"] = _age;
            map["sex"] = _sex;
            return map;
        }
    }
```

### 打印工具 Log
使用前必须先初始化，可以指定tag, 指定运行模式(release模式下，Log.e, Log.json 不会在控制台输出):

```
    Log.init(tag: 'fx_http', isDebug: true);
    Log.d('Hello, Teeup Flutter Developers');
```