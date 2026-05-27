import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hikari_novel_flutter/main.dart';
import 'package:hikari_novel_flutter/network/request.dart';
import 'package:hikari_novel_flutter/network/wenku8_webview_transport.dart';

class Wenku8WebViewTransportHost extends StatefulWidget {
  const Wenku8WebViewTransportHost({super.key});

  @override
  State<Wenku8WebViewTransportHost> createState() =>
      _Wenku8WebViewTransportHostState();
}

class _Wenku8WebViewTransportHostState
    extends State<Wenku8WebViewTransportHost> {
  InAppWebViewController? _controller;

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      Wenku8WebViewTransport.detach(controller);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Wenku8WebViewTransport.hostRequired,
      builder: (context, required, _) {
        if (!required) {
          return const SizedBox.shrink();
        }
        return Positioned(
          left: -4,
          top: -4,
          width: 2,
          height: 2,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: InAppWebView(
                gestureRecognizers:
                    const <Factory<OneSequenceGestureRecognizer>>{},
                initialUrlRequest: URLRequest(url: WebUri('about:blank')),
                initialSettings: InAppWebViewSettings(
                  isInspectable: kDebugMode,
                  userAgent: Request.webViewUserAgentOverride,
                  javaScriptEnabled: true,
                  useHybridComposition: false,
                  loadsImagesAutomatically: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  cacheEnabled: true,
                  clearCache: false,
                  transparentBackground: false,
                  supportMultipleWindows: false,
                  useShouldOverrideUrlLoading: false,
                ),
                webViewEnvironment: webViewEnvironment,
                onWebViewCreated: (controller) {
                  _controller = controller;
                  Wenku8WebViewTransport.attach(controller);
                },
                onLoadStart: (controller, uri) {
                  Wenku8WebViewTransport.notifyLoadStart(controller, uri);
                },
                onLoadStop: (controller, uri) {
                  Wenku8WebViewTransport.notifyLoadStop(controller, uri);
                },
                onProgressChanged: (controller, progress) {
                  Wenku8WebViewTransport.notifyLoadProgress(
                    controller,
                    progress,
                  );
                },
                onReceivedError: (controller, request, error) {
                  if (request.isForMainFrame == true) {
                    Wenku8WebViewTransport.notifyLoadError(
                      controller,
                      error.description,
                    );
                  }
                },
                onReceivedHttpError: (controller, request, errorResponse) {
                  if (request.isForMainFrame == true) {
                    Wenku8WebViewTransport.notifyLoadError(
                      controller,
                      'HTTP ${errorResponse.statusCode}',
                    );
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
