part of '../../rpc_bridge_ext.dart';

/// 测试拦截器，处理所有请求但是打印参数
class InterceptorPrinter extends RPCInterceptor {
  InterceptorPrinter() : super(identifier: 'rpc_bridge.ext.interceptor.printer');

  /// 进入处理之前，返回true则为处理，否则截断不在继续发送
  bool preHandle(HttpRequest request, Uint8List body, HttpServer server) {
    final jsonObject = jsonDecode(utf8.decode(body));
    print('-> ${jsonObject['method']} : ${jsonObject['params']}');
    return false;
  }

  /// 处理过程
  InterceptorHandleType postHandle(
      HttpRequest request, Uint8List body, HttpServer server) {
    return InterceptorHandleType.Continue;
  }
}
