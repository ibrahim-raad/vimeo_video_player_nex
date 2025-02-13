import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Vimeo video player with customizable controls and event callbacks using the InAppWebView
class VimeoVideoPlayer extends StatefulWidget {
  /// Defines the Vimeo video URL to be played
  ///
  /// Example: `https://vimeo.com/9042721855/473c6b2o0a`
  ///
  /// [videoUrl] is required and cannot be empty
  final String videoUrl;

  /// Used to auto-play the video once initialized
  ///
  /// Default value: [false]
  final bool isAutoPlay;

  /// Used to play the video in a loop after it ends
  ///
  /// Default value: [false]
  final bool isLooping;

  /// Used to play the video with the sound muted
  ///
  /// Default value: [false]
  final bool isMuted;

  /// Used to display the video title
  ///
  /// Default value: [false]
  final bool showTitle;

  /// Used to display the video byline/author
  ///
  /// Default value: [false]
  final bool showByline;

  /// Used to display the video playback controls
  ///
  /// Default value: [true]
  final bool showControls;

  /// Used to enable Do Not Track (DNT) mode
  /// When enabled, the player will not track any viewing information
  ///
  /// Default value: [true]
  final bool enableDNT;

  /// Defines the background color of the InAppWebView
  ///
  /// Default Value: [Colors.black]
  final Color backgroundColor;

  /// Defines a callback function triggered when the player is ready to play the video
  final VoidCallback? onReady;

  /// Defines a callback function triggered when the video begins playing
  final VoidCallback? onPlay;

  /// Defines a callback function triggered when the video is paused
  final VoidCallback? onPause;

  /// Defines a callback function triggered when the video playback finishes
  final VoidCallback? onFinish;

  /// Defines a callback function triggered when the video playback position is modified
  final VoidCallback? onSeek;

  /// Defines a callback function triggered when the WebView is created
  final Function(InAppWebViewController controller)? onInAppWebViewCreated;

  /// Defines a callback function triggered when the WebView starts to load an url
  final Function(InAppWebViewController controller, WebUri? url)?
      onInAppWebViewLoadStart;

  /// Defines a callback function triggered when the WebView finishes loading an url
  final Function(InAppWebViewController controller, WebUri? url)?
      onInAppWebViewLoadStop;

  /// Defines a callback function triggered when the WebView encounters an error loading a request
  final Function(InAppWebViewController controller, WebResourceRequest request,
      WebResourceError error)? onInAppWebViewReceivedError;

  VimeoVideoPlayer({
    super.key,
    required this.videoUrl,
    this.isAutoPlay = false,
    this.isLooping = false,
    this.isMuted = false,
    this.showTitle = false,
    this.showByline = false,
    this.showControls = true,
    this.enableDNT = true,
    this.backgroundColor = Colors.black,
    this.onReady,
    this.onPlay,
    this.onPause,
    this.onFinish,
    this.onSeek,
    this.onInAppWebViewCreated,
    this.onInAppWebViewLoadStart,
    this.onInAppWebViewLoadStop,
    this.onInAppWebViewReceivedError,
  }) : assert(videoUrl.isNotEmpty, 'videoUrl cannot be empty!');

  @override
  State<VimeoVideoPlayer> createState() => _VimeoVideoPlayerState();
}

class _VimeoVideoPlayerState extends State<VimeoVideoPlayer> {
  late final InAppWebViewController _webViewController;
  final Completer<void> _controllerCompleter = Completer<void>();

  /// Seek to a specific time in the video
  Future<void> seekTo(Duration time) async {
    if (!_controllerCompleter.isCompleted) {
      await _controllerCompleter.future;
    }
    await _webViewController.evaluateJavascript(source: '''
      player.setCurrentTime(${time.inSeconds});
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialSettings: InAppWebViewSettings(
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        useHybridComposition: true,
      ),
      initialData: InAppWebViewInitialData(
        data: _buildHtmlContent(),
        baseUrl: WebUri("https://player.vimeo.com"),
      ),
      onConsoleMessage: (controller, consoleMessage) {
        final message = consoleMessage.message;
        dev.log('onConsoleMessage :: $message');
        if (message.startsWith('vimeo:')) {
          _manageVimeoPlayerEvent(message.substring(6));
        }
      },
      onWebViewCreated: (controller) {
        _webViewController = controller;
        _controllerCompleter.complete();
        widget.onInAppWebViewCreated?.call(controller);
      },
      onLoadStart: widget.onInAppWebViewLoadStart,
      onLoadStop: widget.onInAppWebViewLoadStop,
      onReceivedError: widget.onInAppWebViewReceivedError,
    );
  }

  /// Builds the HTML content for the Vimeo player
  String _buildHtmlContent() {
    return '''
    <!DOCTYPE html>
    <html>
      <head>
        <style>
          body {
            margin: 0;
            padding: 0;
            background-color: ${_colorToHex(widget.backgroundColor)};
          }
          .video-container {
            position: relative;
            width: 100%;
            height: 100vh;
          }
          iframe {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
          }
        </style>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <script src="https://player.vimeo.com/api/player.js"></script>
      </head>
      <body>
        <div class="video-container">
          <iframe 
            id="player"
            src="${_buildIframeUrl()}"
            frameborder="0"
            allow="autoplay; fullscreen; picture-in-picture"
            allowfullscreen 
            webkitallowfullscreen 
            mozallowfullscreen>
          </iframe>
        </div>
        <script>
          const player = new Vimeo.Player('player');
          player.ready().then(() => console.log('vimeo:onReady'));
          player.on('play', () => console.log('vimeo:onPlay'));
          player.on('pause', () => console.log('vimeo:onPause'));
          player.on('ended', () => console.log('vimeo:onFinish'));
          player.on('seeked', () => console.log('vimeo:onSeek'));
        </script>
      </body>
    </html>
    ''';
  }

  /// Builds the iframe URL from the video URL
  String _buildIframeUrl() {
    final uri = Uri.parse(widget.videoUrl);
    final segments = uri.pathSegments;

    // Extract video ID and hash from the URL
    final videoId = segments.isNotEmpty ? segments[0] : '';
    final hash = segments.length >= 2 ? segments[1] : '';

    return 'https://player.vimeo.com/video/$videoId?h=$hash&'
        'autoplay=${widget.isAutoPlay ? 1 : 0}'
        '&loop=${widget.isLooping ? 1 : 0}'
        '&muted=${widget.isMuted ? 1 : 0}'
        '&title=${widget.showTitle ? 1 : 0}'
        '&byline=${widget.showByline ? 1 : 0}'
        '&controls=${widget.showControls ? 1 : 0}'
        '&dnt=${widget.enableDNT ? 1 : 0}';
  }

  /// Manage Vimeo player events received from the WebView
  void _manageVimeoPlayerEvent(String event) {
    debugPrint('Vimeo event: $event');
    switch (event) {
      case 'onReady':
        widget.onReady?.call();
        break;
      case 'onPlay':
        widget.onPlay?.call();
        break;
      case 'onPause':
        widget.onPause?.call();
        break;
      case 'onFinish':
        widget.onFinish?.call();
        break;
      case 'onSeek':
        widget.onSeek?.call();
        break;
    }
  }

  /// Converts Color to a hexadecimal string
  String _colorToHex(Color color) {
    final hex = color.value.toRadixString(16).padLeft(8, '0');
    return '#${hex.substring(2)}'; // Remove the leading 'ff' for opacity
  }
}
