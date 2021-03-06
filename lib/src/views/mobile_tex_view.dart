import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tex/flutter_tex.dart';
import 'package:flutter_tex/src/utils/core_utils.dart';
import 'package:flutter_tex/src/utils/tex_view_server.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TeXViewState extends State<TeXView> with AutomaticKeepAliveClientMixin {
  static int instanceCount = 0;
  WebViewController _controller;
  int _port = 5353 + instanceCount;
  TeXViewServer _server;
  double _height = 1;
  String _lastData;
  String _lastRenderingEngine;

  TeXViewState() {
    _server = TeXViewServer(_port);
    instanceCount += 1;
    _server.start(_handleRequest /*, (ws){

    }*/
        );
  }

  @override
  bool get wantKeepAlive => widget.keepAlive ?? true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    updateKeepAlive();
    _initTeXView();
    return IndexedStack(
      index: widget.showLoadingWidget ? _height == 1 ? 1 : 0 : 0,
      children: <Widget>[
        Container(
          height: widget.height ?? _height,
          child: WebView(
            onPageFinished: (message) {
              if (widget.onPageFinished != null) {
                widget.onPageFinished(message);
              }
            },
            onWebViewCreated: (controller) {
              this._controller = controller;
              _initTeXView();
            },
            javascriptChannels: Set.from([
              JavascriptChannel(
                  name: 'RenderedTeXViewHeight',
                  onMessageReceived: _renderedTeXViewHeightHandler),
              JavascriptChannel(
                  name: 'OnTapCallback',
                  onMessageReceived: (javascriptMessage) {
                    widget.child.onTapManager(javascriptMessage.message);
                  }),
            ]),
            javascriptMode: JavascriptMode.unrestricted,
          ),
        ),
        widget.loadingWidget ??
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  CircularProgressIndicator(),
                  Divider(
                    height: 5,
                    color: Colors.transparent,
                  ),
                  Text("Rendering TeXView...!")
                ],
              ),
            )
      ],
    );
  }

  @override
  void dispose() {
    _server.close();
    instanceCount -= 1;
    super.dispose();
  }

  String getJsonData() {
    return CoreUtils.getRawData(widget.child, widget?.style);
  }

  void _handleRequest(HttpRequest request) {
    try {
      if (request.method == 'GET' &&
          request.requestedUri.pathSegments[0] == 'rawData' &&
          request.requestedUri.port == _port)
        request.response.write(getJsonData());
    } catch (e) {
      print('Exception in handleRequest: $e');
    }
  }

  void _initTeXView() {
    if (_controller != null &&
        (getJsonData() != _lastData ||
            widget.renderingEngine.getEngineName() != _lastRenderingEngine)) {
      if (widget.showLoadingWidget) {
        _height = 1;
      }
      _controller.loadUrl(
          "http://localhost:$_port/packages/flutter_tex/js/${widget.renderingEngine?.getEngineName()}/index.html?port=$_port&instanceCount=$instanceCount&configurations=${Uri.encodeComponent(widget.renderingEngine?.getConfigurations())}");
      this._lastData = getJsonData();
      this._lastRenderingEngine = widget.renderingEngine.getEngineName();
    }
  }

  void _renderedTeXViewHeightHandler(JavascriptMessage javascriptMessage) {
    double viewHeight = double.parse(javascriptMessage.message);
    if (_height != viewHeight) {
      setState(() {
        _height = viewHeight;
      });
    }
    if (widget.onRenderFinished != null) {
      widget.onRenderFinished(_height);
    }
  }
}
