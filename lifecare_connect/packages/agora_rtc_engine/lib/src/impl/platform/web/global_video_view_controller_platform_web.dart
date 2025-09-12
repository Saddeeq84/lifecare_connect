import 'dart:async';
import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
// Ensure the file exists at the specified path or update the import path if necessary.
// import '../global_video_view_controller_platform.dart';
import 'package:iris_method_channel/iris_method_channel.dart';
// import '../../rtc_connection.dart'; // Corrected import for RtcConnection
// Update the path below to the correct location of rtc_connection.dart if needed:
// import '../../rtc_connection.dart'; // Corrected import for RtcConnection
// Update the path below to the correct location of rtc_connection.dart if needed:
// import 'package:agora_rtc_engine/src/rtc_connection.dart'; // Corrected import for RtcConnection
// import 'package:agora_rtc_engine/src/video_canvas.dart'; // Import for VideoCanvas
import 'package:agora_rtc_engine/agora_rtc_engine.dart' show VideoCanvas;

// ignore_for_file: public_member_api_docs

const _platformRendererViewType = 'AgoraSurfaceView';

String _getViewType(int id) {
  return 'agora_rtc_engine/${_platformRendererViewType}_$id';
}

class _View {
  _View(int platformViewId)
      : _element = html.DivElement()
          ..id = _getViewType(platformViewId)
          ..style.width = '100%'
          ..style.height = '100%' {
    // Wait until the element is injected into the DOM,
    // see https://github.com/flutter/flutter/issues/143922#issuecomment-1960133128
    final observer = html.IntersectionObserver((entries, observer) {
      if (_element.isConnected == true) {
        observer.unobserve(_element);
        _viewCompleter.complete(_element);
      }
    });
    observer.observe(_element);
  }

  final html.HtmlElement _element;
  html.HtmlElement get element => _element;

  final _viewCompleter = Completer<html.HtmlElement>();

  Future<String> waitAndGetId() async {
    final div = await _viewCompleter.future;
    return div.id;
  }
}

// TODO(littlegnal): Need handle remove view logic on web
final Map<int, _View> _viewMap = {};

class GlobalVideoViewControllerWeb /* extends GlobalVideoViewControllerPlatform */ {
  GlobalVideoViewControllerWeb(
      IrisMethodChannel irisMethodChannel, RtcEngine rtcEngine) {
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_platformRendererViewType,
        (int viewId) {
      final view = _View(viewId);
      _viewMap[viewId] = view;
      return view.element;
    });
  }

  Future<void> detachVideoFrameBufferManager(int irisRtcEngineIntPtr) {
    _viewMap.clear();
    return Future.value();
  }

  @override
  Future<void> setupVideoView(Object viewHandle, VideoCanvas videoCanvas,
      {RtcConnection? connection}) async {
    // The `viewHandle` is the platform view id on web
    final viewId = viewHandle as int;

    // Replace with the correct method from the superclass, or define setupVideoView in GlobalVideoViewControllerPlatform.
    // Example: If the superclass has a method named setupView, use:
    // await super.setupView(divId, videoCanvas, connection: connection);

    // If not, define setupVideoView in GlobalVideoViewControllerPlatform with the appropriate signature.
    // Remove or update this line after making changes in the superclass.
  }
}
