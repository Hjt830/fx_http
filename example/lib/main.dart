import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:fx_http/fx_http.dart';
import 'package:sp_util/sp_util.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SpUtil.getInstance();

  Log.init(tag: 'fx_http', isDebug: true);
  DioUtils.init("http://user.gmandarin.com/api/", isDebugMode: true, apiSuccessCode: 0, validateApiSuccess: (result)=> (0 == result.code && result.success));
  DioUtils.instance.enableConsoleLogging();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key) {
    configLoading();
  }

  void configLoading() {
    EasyLoading.instance
      ..displayDuration = const Duration(milliseconds: 2000)
      ..indicatorType = EasyLoadingIndicatorType.fadingCircle
      ..loadingStyle = EasyLoadingStyle.custom
      ..indicatorSize = 45.0
      ..radius = 10.0
      ..progressColor = Colors.transparent
      ..backgroundColor = Colors.transparent
      ..indicatorColor = Colors.transparent
      ..textColor = Colors.white
      ..maskColor = Colors.black26
      ..userInteractions = false
      ..indicatorWidget = const SizedBox(
        width: 70,
        height: 70,
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white)),
      )
      ..dismissOnTap = true
      ..customAnimation = CustomAnimation();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FxHttp',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'FxHttp'),
      builder: EasyLoading.init(
          builder: (BuildContext context, Widget? child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
              child: GestureDetector(
                onTap: () {
                  FocusScopeNode currentFocus = FocusScope.of(context);
                  if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
                    FocusManager.instance.primaryFocus!.unfocus();
                  }
                },
                child: child,
              ),
            );
          }
      )
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: FutureBuilder<List<Map>>(
        future: _requestData(),
        initialData: const [],
        builder: (BuildContext context, AsyncSnapshot<List<Map>> snapshot) {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return ListView.separated(
                itemBuilder: (BuildContext context, int index) {
                  return Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(snapshot.data![index]["name"] ?? "无标题", style: const TextStyle(fontSize: 15, color: Colors.black, fontWeight: FontWeight.bold)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(snapshot.data![index]["category"] ?? "无标题", style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.normal)),
                            const SizedBox(width: 20),
                            Text("点差: ${snapshot.data![index]["spread"] ?? "无标题"}", style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.normal)),
                            const SizedBox(width: 20),
                            Text("精度: ${snapshot.data![index]["digits"] ?? "无标题"}", style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.normal))
                          ],
                        )
                      ]
                    ),
                  );
                },
                separatorBuilder: (BuildContext context, int index) {
                  return Divider(height: 1, color: Colors.grey[300]);
                },
                itemCount: snapshot.data!.length
            );
          }
          else {
            return const Center(
              child: Text("没有数据")
            );
          }
        },
      )// This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Future<List<Map>> _requestData() async {
    EasyLoading.show();
    var result = await DioHttp.requestNetwork<Map>(Method.get, "symbols");
    EasyLoading.dismiss();
    return result.listData;
  }
}


class CustomAnimation extends EasyLoadingAnimation {
  CustomAnimation();

  @override
  Widget buildWidget(
      Widget child,
      AnimationController controller,
      AlignmentGeometry alignment,
      ) {
    double opacity = controller.value;
    return Opacity(
      opacity: opacity,
      child: RotationTransition(
        turns: controller,
        child: child,
      ),
    );
  }
}