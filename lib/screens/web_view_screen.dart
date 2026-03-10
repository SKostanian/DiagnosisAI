import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatefulWidget {
  final String title;
  final String assetPath;

  const WebViewScreen({
    required this.title,
    required this.assetPath,
    super.key,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  var _isLoading = true;
  Color? _backgroundColor;

  @override
  void initState() {
    super.initState();
    // Flutter package (2026) Dart packages.
    // Available at: https://pub.dev/packages/webview_flutter (Accessed: March 10, 2026).
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) => setState(() => _isLoading = true),
          onPageFinished: (String url) => setState(() => _isLoading = false),
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${error.description}')),
            );
          },
        ),
      );
    // Webview_flutter_wkwebview example (2026) Dart packages.
    // Available at: https://pub.dev/packages/webview_flutter_wkwebview/example (Accessed: March 10, 2026).
    _controller.loadFlutterAsset(widget.assetPath);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_backgroundColor == null) {
      _backgroundColor = Theme.of(context).scaffoldBackgroundColor;
      _controller.setBackgroundColor(_backgroundColor!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
