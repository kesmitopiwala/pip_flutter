import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pip_flutter/pipflutter_player_configuration.dart';
import 'package:pip_flutter/pipflutter_player_controller.dart';
import 'package:pip_flutter/pipflutter_player_controller_event.dart';
import 'package:pip_flutter/pipflutter_player_controller_provider.dart';
import 'package:pip_flutter/pipflutter_player_data_source.dart';
import 'package:pip_flutter/pipflutter_player_data_source_type.dart';
import 'package:pip_flutter/pipflutter_player_event.dart';
import 'package:pip_flutter/pipflutter_player_event_type.dart';
import 'package:pip_flutter/pipflutter_player_utils.dart';
import 'package:pip_flutter/pipflutter_player_with_controls.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wakelock/wakelock.dart';

///Widget which uses provided controller to render video player.
class PipFlutterPlayer extends StatefulWidget {
  const PipFlutterPlayer({Key? key, required this.controller})
      : super(key: key);

  factory PipFlutterPlayer.network(
    String url, {
    PipFlutterPlayerConfiguration? pipFlutterPlayerConfiguration,
  }) =>
      PipFlutterPlayer(
        controller: PipFlutterPlayerController(
          pipFlutterPlayerConfiguration ??
              const PipFlutterPlayerConfiguration(),
          pipFlutterPlayerDataSource: PipFlutterPlayerDataSource(
              PipFlutterPlayerDataSourceType.network, url),
        ),
      );

  factory PipFlutterPlayer.file(
    String url, {
    PipFlutterPlayerConfiguration? pipFlutterPlayerConfiguration,
  }) =>
      PipFlutterPlayer(
        controller: PipFlutterPlayerController(
          pipFlutterPlayerConfiguration ??
              const PipFlutterPlayerConfiguration(),
          pipFlutterPlayerDataSource: PipFlutterPlayerDataSource(
              PipFlutterPlayerDataSourceType.file, url),
        ),
      );

  final PipFlutterPlayerController controller;

  @override
  _PipFlutterPlayerState createState() {
    return _PipFlutterPlayerState();
  }
}

class _PipFlutterPlayerState extends State<PipFlutterPlayer>
    with WidgetsBindingObserver {
  PipFlutterPlayerConfiguration get _pipFlutterPlayerConfiguration =>
      widget.controller.pipFlutterPlayerConfiguration;

  bool _isFullScreen = false;

  ///State of navigator on widget created
  late NavigatorState _navigatorState;

  ///Flag which determines if widget has initialized
  bool _initialized = false;

  ///Subscription for controller events
  StreamSubscription? _controllerEventSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    if (!_initialized) {
      final navigator = Navigator.of(context);
      setState(() {
        _navigatorState = navigator;
      });
      _setup();
      _initialized = true;
    }
    super.didChangeDependencies();
  }

  Future<void> _setup() async {
    _controllerEventSubscription =
        widget.controller.controllerEventStream.listen(onControllerEvent);

    //Default locale
    var locale = const Locale("en", "US");
    try {
      if (mounted) {
        final contextLocale = Localizations.localeOf(context);
        locale = contextLocale;
      }
    } catch (exception) {
      PipFlutterPlayerUtils.log(exception.toString());
    }
    widget.controller.setupTranslations(locale);
  }

  @override
  void dispose() {
    ///If somehow PipFlutterPlayer widget has been disposed from widget tree and
    ///full screen is on, then full screen route must be pop and return to normal
    ///state.
    if (_isFullScreen) {
      Wakelock.disable();
      _navigatorState.maybePop();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays:
              _pipFlutterPlayerConfiguration.systemOverlaysAfterFullScreen);
      SystemChrome.setPreferredOrientations(
          _pipFlutterPlayerConfiguration.deviceOrientationsAfterFullScreen);
    }

    WidgetsBinding.instance!.removeObserver(this);
    _controllerEventSubscription?.cancel();
    widget.controller.dispose();
    VisibilityDetectorController.instance
        .forget(Key("${widget.controller.hashCode}_key"));
    super.dispose();
  }

  @override
  void didUpdateWidget(PipFlutterPlayer oldWidget) {
    if (oldWidget.controller != widget.controller) {
      _controllerEventSubscription?.cancel();
      _controllerEventSubscription =
          widget.controller.controllerEventStream.listen(onControllerEvent);
    }
    super.didUpdateWidget(oldWidget);
  }

  void onControllerEvent(PipFlutterPlayerControllerEvent event) {
    switch (event) {
      case PipFlutterPlayerControllerEvent.openFullscreen:
        onFullScreenChanged();
        break;
      case PipFlutterPlayerControllerEvent.hideFullscreen:
        onFullScreenChanged();
        break;
      default:
        setState(() {});
        break;
    }
  }

  // ignore: avoid_void_async
  Future<void> onFullScreenChanged() async {
    final controller = widget.controller;
    if (controller.isFullScreen && !_isFullScreen) {
      _isFullScreen = true;
      controller.postEvent(
          PipFlutterPlayerEvent(PipFlutterPlayerEventType.openFullscreen));
      await _pushFullScreenWidget(context);
    } else if (_isFullScreen) {
      Navigator.of(context, rootNavigator: true).pop();
      _isFullScreen = false;
      controller.postEvent(
          PipFlutterPlayerEvent(PipFlutterPlayerEventType.hideFullscreen));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PipFlutterPlayerControllerProvider(
      controller: widget.controller,
      child: _buildPlayer(),
    );
  }

  Widget _buildFullScreenVideo(
      BuildContext context,
      Animation<double> animation,
      PipFlutterPlayerControllerProvider controllerProvider) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        alignment: Alignment.center,
        color: Colors.black,
        child: controllerProvider,
      ),
    );
  }

  AnimatedWidget _defaultRoutePageBuilder(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      PipFlutterPlayerControllerProvider controllerProvider) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        return _buildFullScreenVideo(context, animation, controllerProvider);
      },
    );
  }

  Widget _fullScreenRoutePageBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final controllerProvider = PipFlutterPlayerControllerProvider(
        controller: widget.controller, child: _buildPlayer());

    final routePageBuilder = _pipFlutterPlayerConfiguration.routePageBuilder;
    if (routePageBuilder == null) {
      return _defaultRoutePageBuilder(
          context, animation, secondaryAnimation, controllerProvider);
    }

    return routePageBuilder(
        context, animation, secondaryAnimation, controllerProvider);
  }

  Future<dynamic> _pushFullScreenWidget(BuildContext context) async {
    final TransitionRoute<void> route = PageRouteBuilder<void>(
      settings: const RouteSettings(),
      pageBuilder: _fullScreenRoutePageBuilder,
    );

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (_pipFlutterPlayerConfiguration.autoDetectFullscreenDeviceOrientation ==
        true) {
      final aspectRatio =
          widget.controller.videoPlayerController?.value.aspectRatio ?? 1.0;
      List<DeviceOrientation> deviceOrientations;
      if (aspectRatio < 1.0) {
        deviceOrientations = [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown
        ];
      } else {
        deviceOrientations = [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight
        ];
      }
      await SystemChrome.setPreferredOrientations(deviceOrientations);
    } else {
      await SystemChrome.setPreferredOrientations(
        widget.controller.pipFlutterPlayerConfiguration
            .deviceOrientationsOnFullScreen,
      );
    }

    if (!_pipFlutterPlayerConfiguration.allowedScreenSleep) {
      Wakelock.enable();
    }

    await Navigator.of(context, rootNavigator: true).push(route);
    _isFullScreen = false;
    widget.controller.exitFullScreen();

    // The wakelock plugins checks whether it needs to perform an action internally,
    // so we do not need to check Wakelock.isEnabled.
    Wakelock.disable();

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: _pipFlutterPlayerConfiguration.systemOverlaysAfterFullScreen);
    await SystemChrome.setPreferredOrientations(
        _pipFlutterPlayerConfiguration.deviceOrientationsAfterFullScreen);
  }

  Widget _buildPlayer() {
    return VisibilityDetector(
      key: Key("${widget.controller.hashCode}_key"),
      onVisibilityChanged: (VisibilityInfo info) =>
          widget.controller.onPlayerVisibilityChanged(info.visibleFraction),
      child: PipFlutterPlayerWithControls(
        controller: widget.controller,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    widget.controller.setAppLifecycleState(state);
  }
}

///Page route builder used in fullscreen mode.
typedef PipFlutterPlayerRoutePageBuilder = Widget Function(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    PipFlutterPlayerControllerProvider controllerProvider);
