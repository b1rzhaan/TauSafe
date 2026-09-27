import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

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
  late web.HTMLIFrameElement frame;
  late String viewType;
  late JSFunction listener;
  bool ready = false;
  @override
  void initState() {
    super.initState();
    viewType = 'terrain-${DateTime.now().microsecondsSinceEpoch}';
    frame = web.HTMLIFrameElement()
      ..src = 'assets/assets/viewer/index.html?v=alpine-6'
      ..title = 'Интерактивный рельеф Алматы';
    frame.style
      ..width = '100%'
      ..height = '100%'
      ..pointerEvents = widget.interactive ? 'auto' : 'none'
      ..border = '0';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (_) => frame);
    listener = ((web.MessageEvent event) {
      if (event.origin != web.window.location.origin ||
          event.source != frame.contentWindow) {
        return;
      }
      final value = event.data.dartify();
      if (value is! String) return;
      try {
        final data = jsonDecode(value) as Map<String, dynamic>;
        if (data['type'] == 'ready') {
          ready = true;
          _send();
        }
        widget.onMessage(data);
      } catch (_) {}
    }).toJS;
    web.window.addEventListener('message', listener);
  }

  void _send() {
    if (ready) {
      for (final c in widget.commands) {
        frame.contentWindow?.postMessage(
          jsonEncode(c).toJS,
          web.window.location.origin.toJS,
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant TerrainView oldWidget) {
    super.didUpdateWidget(oldWidget);
    frame.style.pointerEvents = widget.interactive ? 'auto' : 'none';
    if (jsonEncode(oldWidget.commands) != jsonEncode(widget.commands)) _send();
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: viewType);
}
