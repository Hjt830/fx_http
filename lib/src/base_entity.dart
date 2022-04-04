import 'package:fx_http/fx_http.dart';
import 'package:fx_http/src/utils/log_utils.dart';

/////////////////////////////////////////////////////////////////////////////////
////////////////////////// 所有实体类都需要遵循的接口协议 ///////////////////////////
/////////////////////////////////////////////////////////////////////////////////
abstract class BaseModel {
  BaseModel fromJson(dynamic json);
  Map<String, dynamic> toJson();
  String toString() {
    return this.toJson().toString();
  }
}

////////////////////////////////////////////////////////////////////////
////////////////////////// 基础实体类对应的key ///////////////////////////
////////////////////////////////////////////////////////////////////////
class BaseEntityKey {
  static String code      = 'code';       // int 成功返回0 失败返回其他状态码
  static String data      = 'data';       // hashMap | array | string	数据
  static String message   = 'message';    // String 成功返回空 失败返回其他错误提示
  static String success   = 'success';    // bool 成功返回true 失败返回false
  static String timestamp = 'timestamp';  // double 时间戳

  /// 初始化自定义数据结构字段 (如果字段跟上面相同，则不必调用)
  static void init({String? code, String? data, String? message, String? success, String? timestamp}) {
    if (!TextUtil.isEmpty(code)) { BaseEntityKey.code = code!; }
    if (!TextUtil.isEmpty(data)) { BaseEntityKey.data = data!; }
    if (!TextUtil.isEmpty(message)) { BaseEntityKey.message = data!; }
    if (!TextUtil.isEmpty(success)) { BaseEntityKey.success = success!; }
    if (!TextUtil.isEmpty(timestamp)) { BaseEntityKey.timestamp = timestamp!; }
  }
}

////////////////////////////////////////////////////////////////
////////////////////////// 基础实体类 ///////////////////////////
////////////////////////////////////////////////////////////////
class BaseEntity<T> {
  late double timestamp;
  late bool success;
  late int code;
  late String message;
  T? data;
  List<T> listData = [];
  PageEntity<T> pageData = PageEntity<T>();

  BaseEntity(this.timestamp, this.success, this.code, this.message, this.data);

  // json -> model
  // 尽量使用model来转模型， 避免引入实体类来转模型, 降低偶合。
  BaseEntity.fromJson(Map<String, dynamic> json, {bool isPageData = false, BaseModel? model}) {
    this.timestamp = json[BaseEntityKey.timestamp] != null ? json[BaseEntityKey.timestamp] as double : DateTime.now().millisecondsSinceEpoch.toDouble();
    this.success = json[BaseEntityKey.success] != null ? json[BaseEntityKey.success] as bool : false;
    this.code = json[BaseEntityKey.code] != null ? (int.tryParse(json[BaseEntityKey.code].toString()) ?? ExceptionHandler.unknown_error) : ExceptionHandler.unknown_error;
    this.message = json[BaseEntityKey.message] != null ? json[BaseEntityKey.message].toString() : "未知异常";
    if (DioUtils.apiSuccessCode == this.code && json.containsKey(BaseEntityKey.data) && json[BaseEntityKey.data] != null) {
      // 如果是分页数据
      if (isPageData) {
        var map = json[BaseEntityKey.data];
        pageData.total = map['total'] is! int ? int.tryParse(map['total']) : map['total'];
        pageData.perPage = map['per_page'] is! int ? int.tryParse(map['per_page']) : map['per_page'];
        pageData.currentPage = map['current_page'] is! int ? int.tryParse(map['current_page']) : map['current_page'];
        pageData.data.clear();
        if (map[BaseEntityKey.data] != null) {
          (map[BaseEntityKey.data] as List<dynamic>).forEach((item) {
            T? object = _generateOBJ<T>(item, model: model);
            if (null != object) {
              pageData.data.add(object);
            }
          });
        }
      }
      // 不是分页数据
      else {
        if (json[BaseEntityKey.data] is List) {
          (json[BaseEntityKey.data] as List).forEach((item) {
            T? object = _generateOBJ<T>(item, model: model);
            if (null != object) {
              listData.add(object);
            }
          });
        } else {
          data = _generateOBJ<T>(json[BaseEntityKey.data], model: model);
        }
      }
    }
  }

  S? _generateOBJ<S>(json, {BaseModel? model}) {
    if (S is String) {
      return json.toString() as S;
    } else if (S is Map) {
      return json as S;
    }
    else {
      try {
          if (model != null) {
            // 推荐
            return model.fromJson(json) as S;
          }
          else {
            // 不推荐， 尽量避免这样使用
            // if (S.toString() == 'AppConfigModel') {
            //   return AppConfigModel.fromJson(json) as S;
            // }
            return json;
          }
      } catch (e) {
          Log.e("解析出错: $e");
          Map<String, dynamic> object = json as Map<String, dynamic>;
          object.forEach((key, value) {
            Log.d('object $key : ${value.runtimeType}');
          });
      }
    }
  }
}


class PageEntity<T> {
  int total = 0;
  int perPage = 0;
  int currentPage = 0;
  List<T> data = [];

  @override
  String toString() {
    return 'total: $total  per_page: $perPage  current_page: $currentPage, data: $data';
  }
}
