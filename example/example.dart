import 'package:lm_rpc_bridge/rpc_bridge.dart';

Future<void> main() async {
    RPCBridgeHttp bridge = RPCBridgeHttp(proxyProt: 4444, remoteURI: Uri.parse('http://127.0.0.1'));
    bridge.daemon();
}
