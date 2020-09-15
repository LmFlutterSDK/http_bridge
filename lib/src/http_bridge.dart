part of '../rpc_bridge.dart';

abstract class RPCBridge {
  /// 本地代理端口，不允许指定Host，因为指定Host可能回调导致安全问题，比如 0.0.0.0
  /// 会导致代理服务器暴露在本机处于的网络中，带来风险，所以host默认为 localhost或者
  /// 127.0.0.1
  final int proxyProt;

  /// 桥接的远程服务器如 http://xxx.xxx.xxx:prot
  final Uri remoteURI;

  /// 拦截器
  List<RPCInterceptor> _interceptors = [];
  List<RPCInterceptor> get interceptors => _interceptors;

  RPCBridge({this.proxyProt, this.remoteURI});

  /// 启动代理服务器
  Future<void> daemon();

  /// 关闭代理服务器
  void shutdown();

  /// 处理数据
  void handleRequest(HttpRequest request);
}

/// 在本机打开一个HttpServices用于桥接和捕获特殊的RPC请求，相当于一个本地代理服务器
class RPCBridgeHttp extends RPCBridge {
  HttpServer _bridgeServer;

  RPCBridgeHttp({int proxyProt, Uri remoteURI})
      : super(proxyProt: proxyProt, remoteURI: remoteURI);

  /// 启动代理服务器
  @override
  Future<void> daemon() async {
    HttpServer.bind(InternetAddress.loopbackIPv4, proxyProt)
        .then((server) async {
      _bridgeServer = server;
      _bridgeServer.defaultResponseHeaders
        ..clear()
        ..set('Access-Control-Allow-Credentials', true)
        ..set('Access-Control-Allow-Headers', 'content-type')
        ..set('Access-Control-Allow-Methods', 'POST')
        ..set('Access-Control-Allow-Origin', '*')
        ..set('Access-Control-Max-Age', 600)
        ..set('Connection', 'keep-alive')
        ..date = DateTime.now();

      await for (HttpRequest request in _bridgeServer) {
        handleRequest(request);
      }
    }).catchError((e) {
      if (e is SocketException) {
        if (e.osError.errorCode != 48) print(e.toString());
      }
    });
  }

  @override
  void shutdown() {
    _bridgeServer.close(force: true);
    return;
  }

  @override
  void handleRequest(HttpRequest request) {
    switch (request.method) {
      case 'OPTIONS':
        request.response
          ..statusCode = 204
          ..close();
        return;

      default:
        _handlePostMethod(request);
        return;
    }
  }

  void _handlePostMethod(HttpRequest request) async {
    await for (Uint8List rawBody in request) {
      /// 处理拦截器
      for (RPCInterceptor interceptor in interceptors) {
        /// 如果拦截器需要处理
        if (interceptor.preHandle(request, rawBody, _bridgeServer)) {
          /// 拦截器需要截断处理
          final ret = interceptor.postHandle(request, rawBody, _bridgeServer);

          switch (ret) {

            /// 继续处理
            case InterceptorHandleType.Continue:
              continue;

            /// 不在处理后续的拦截器
            case InterceptorHandleType.Break:
              break;

            /// 拦截器处理了请求，并且已经回复了response
            case InterceptorHandleType.Done:
              return;

            /// 停止请求
            case InterceptorHandleType.Refused:
              request.response
                ..write('Interceptor refused')
                ..close();
          }
        }
      }

      /// 处理逻辑
      http.post(
        remoteURI.toString(),
        body: rawBody,
        headers: {
          'content-type': 'application/json',
        },
      ).then((remoteResponse) {
        request.response
          ..headers.date = DateTime.now()
          ..headers.contentType = ContentType.json
          ..write(remoteResponse.body)
          ..close();
      });
    }
  }
}
