import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  late WebSocketChannel channel;

  void connect(Function(String) onMessage) {
    channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:8081/ws'),
    );
    channel.stream.listen((message) {
      onMessage(message.toString());
    });
  }

  void dispose() {
    channel.sink.close();
  }
}
