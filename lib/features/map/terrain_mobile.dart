import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TerrainView extends StatefulWidget {
  const TerrainView({
    super.key,
    required this.onMessage,
    required this.commands,
    this.interactive = true,
  });
  final ValueChanged<Map<String, dynamic>> onMessage;
  final List<Map<String, dynamic>> commands;
  final bool interactive;
  @override
  State<TerrainView> createState() => _TerrainViewState();
}

class _TerrainViewState extends State<TerrainView> {
  late final WebViewController controller;
  bool ready = false;
  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xffe3edf4))
      ..addJavaScriptChannel(
        'TauSafe',
        onMessageReceived: (m) {
          final data = jsonDecode(m.message) as Map<String, dynamic>;
          if (data['type'] == 'ready') {
            ready = true;
            _send();
          }
          widget.onMessage(data);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => request.url.startsWith('file:')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      )
      ..loadFlutterAsset('assets/viewer/index.html');
  }

  void _send() {
    if (ready) {
      for (final c in widget.commands) {
        controller.runJavaScript('window.tauCommand(${jsonEncode(c)});');
      }
    }
  }

  @override
  void didUpdateWidget(covariant TerrainView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (jsonEncode(oldWidget.commands) != jsonEncode(widget.commands)) _send();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !widget.interactive,
    child: WebViewWidget(
      controller: controller,
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
    ),
  );
}
