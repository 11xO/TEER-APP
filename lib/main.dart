import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

// ═══════════════════════════════════════════════════════════════
// ✅ رابط موقعك الفعلي على GitHub Pages
// ═══════════════════════════════════════════════════════════════
const String websiteUrl = 'https://11xo.github.io/TEER/';
// ═══════════════════════════════════════════════════════════════

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TEERApp());
}

class TEERApp extends StatelessWidget {
  const TEERApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TEER',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF8b5cf6),
        useMaterial3: true,
      ),
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _controller = WebViewController()
        ..loadRequest(Uri.parse(websiteUrl));
      return;
    }

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFf8fafc))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (!mounted) return;
            setState(() => _loadingProgress = 0);
          },
          onProgress: (int progress) {
            if (!mounted) return;
            setState(() => _loadingProgress = progress);
          },
          onPageFinished: (String url) {
            if (!mounted) return;
            setState(() => _loadingProgress = 100);
            _clearWebViewCache();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) async {
            final url = request.url;

            // فتح واتساب / تليفون / بريد خارج التطبيق
            if (url.startsWith('whatsapp://') ||
                url.startsWith('tel:') ||
                url.startsWith('mailto:') ||
                url.startsWith('sms:') ||
                url.contains('wa.me') ||
                url.contains('api.whatsapp.com')) {
              try {
                await launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalApplication);
              } catch (e) {
                debugPrint('Launch failed: $e');
              }
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..enableZoom(false);

    _clearCacheAndLoadWebsite();

    // إعدادات Android
    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(kDebugMode);
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

  Future<void> _clearCacheAndLoadWebsite() async {
    await _clearWebViewCache();
    await _controller.loadRequest(
      Uri.parse(websiteUrl),
      headers: const <String, String>{
        'Cache-Control': 'no-cache, no-store, must-revalidate',
      },
    );
  }

  Future<void> _clearWebViewCache() async {
    try {
      await _controller.clearCache();
    } catch (error, stackTrace) {
      debugPrint('Failed to clear WebView cache: $error\n$stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: const Color(0xFFf8fafc),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loadingProgress < 100)
              Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(
                  value: _loadingProgress / 100,
                  minHeight: 2,
                ),
              ),
          ],
        ),
      ),
    );

    if (kIsWeb) return scaffold;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canGoBack = await _controller.canGoBack();
        if (canGoBack) {
          await _controller.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: scaffold,
    );
  }
}