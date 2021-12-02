import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pip_flutter/pipflutter_player_controller.dart';
import 'package:pip_flutter/pipflutter_player_controller_event.dart';
import 'package:pip_flutter/pipflutter_player_controls_configuration.dart';
import 'package:pip_flutter/pipflutter_player_cupertino_controls.dart';
import 'package:pip_flutter/pipflutter_player_material_controls.dart';
import 'package:pip_flutter/pipflutter_player_subtitles_configuration.dart';
import 'package:pip_flutter/pipflutter_player_subtitles_drawer.dart';
import 'package:pip_flutter/pipflutter_player_theme.dart';
import 'package:pip_flutter/pipflutter_player_utils.dart';
import 'package:pip_flutter/video_player.dart';

class PipFlutterPlayerWithControls extends StatefulWidget {
  final PipFlutterPlayerController? controller;

  const PipFlutterPlayerWithControls({Key? key, this.controller})
      : super(key: key);

  @override
  _PipFlutterPlayerWithControlsState createState() =>
      _PipFlutterPlayerWithControlsState();
}

class _PipFlutterPlayerWithControlsState
    extends State<PipFlutterPlayerWithControls> {
  PipFlutterPlayerSubtitlesConfiguration get subtitlesConfiguration =>
      widget.controller!.pipFlutterPlayerConfiguration.subtitlesConfiguration;

  PipFlutterPlayerControlsConfiguration get controlsConfiguration =>
      widget.controller!.pipFlutterPlayerConfiguration.controlsConfiguration;

  final StreamController<bool> playerVisibilityStreamController =
      StreamController();

  bool _initialized = false;

  StreamSubscription? _controllerEventSubscription;

  @override
  void initState() {
    playerVisibilityStreamController.add(true);
    _controllerEventSubscription =
        widget.controller!.controllerEventStream.listen(_onControllerChanged);
    super.initState();
  }

  @override
  void didUpdateWidget(PipFlutterPlayerWithControls oldWidget) {
    if (oldWidget.controller != widget.controller) {
      _controllerEventSubscription?.cancel();
      _controllerEventSubscription =
          widget.controller!.controllerEventStream.listen(_onControllerChanged);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    playerVisibilityStreamController.close();
    _controllerEventSubscription?.cancel();
    super.dispose();
  }

  void _onControllerChanged(PipFlutterPlayerControllerEvent event) {
    setState(() {
      if (!_initialized) {
        _initialized = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final PipFlutterPlayerController pipFlutterPlayerController =
        PipFlutterPlayerController.of(context);

    double? aspectRatio;
    if (pipFlutterPlayerController.isFullScreen) {
      if (pipFlutterPlayerController.pipFlutterPlayerConfiguration
              .autoDetectFullscreenDeviceOrientation ||
          pipFlutterPlayerController
              .pipFlutterPlayerConfiguration.autoDetectFullscreenAspectRatio) {
        aspectRatio = pipFlutterPlayerController
                .videoPlayerController?.value.aspectRatio ??
            1.0;
      } else {
        aspectRatio = pipFlutterPlayerController
                .pipFlutterPlayerConfiguration.fullScreenAspectRatio ??
            PipFlutterPlayerUtils.calculateAspectRatio(context);
      }
    } else {
      aspectRatio = pipFlutterPlayerController.getAspectRatio();
    }

    aspectRatio ??= 16 / 9;
    final innerContainer = Container(
      width: double.infinity,
      color: pipFlutterPlayerController
          .pipFlutterPlayerConfiguration.controlsConfiguration.backgroundColor,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: _buildPlayerWithControls(pipFlutterPlayerController, context),
      ),
    );

    if (pipFlutterPlayerController.pipFlutterPlayerConfiguration.expandToFill) {
      return Center(child: innerContainer);
    } else {
      return innerContainer;
    }
  }

  Container _buildPlayerWithControls(
      PipFlutterPlayerController pipFlutterPlayerController,
      BuildContext context) {
    final configuration =
        pipFlutterPlayerController.pipFlutterPlayerConfiguration;
    var rotation = configuration.rotation;

    if (!(rotation <= 360 && rotation % 90 == 0)) {
      PipFlutterPlayerUtils.log(
          "Invalid rotation provided. Using rotation = 0");
      rotation = 0;
    }
    if (pipFlutterPlayerController.pipFlutterPlayerDataSource == null) {
      return Container();
    }
    _initialized = true;

    final bool placeholderOnTop = pipFlutterPlayerController
        .pipFlutterPlayerConfiguration.placeholderOnTop;
    // ignore: avoid_unnecessary_containers
    return Container(
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          if (placeholderOnTop) _buildPlaceholder(pipFlutterPlayerController),
          Transform.rotate(
            angle: rotation * pi / 180,
            child: _PipFlutterPlayerVideoFitWidget(
              pipFlutterPlayerController,
              pipFlutterPlayerController.pipFlutterPlayerConfiguration.fit,
            ),
          ),
          pipFlutterPlayerController.pipFlutterPlayerConfiguration.overlay ??
              Container(),
          PipFlutterPlayerSubtitlesDrawer(
            pipFlutterPlayerController: pipFlutterPlayerController,
            pipFlutterPlayerSubtitlesConfiguration: subtitlesConfiguration,
            subtitles: pipFlutterPlayerController.subtitlesLines,
            playerVisibilityStream: playerVisibilityStreamController.stream,
          ),
          if (!placeholderOnTop) _buildPlaceholder(pipFlutterPlayerController),
          _buildControls(context, pipFlutterPlayerController),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(
      PipFlutterPlayerController pipFlutterPlayerController) {
    return pipFlutterPlayerController.pipFlutterPlayerDataSource!.placeholder ??
        pipFlutterPlayerController.pipFlutterPlayerConfiguration.placeholder ??
        Container();
  }

  Widget _buildControls(
    BuildContext context,
    PipFlutterPlayerController pipFlutterPlayerController,
  ) {
    if (controlsConfiguration.showControls) {
      PipFlutterPlayerTheme? playerTheme = controlsConfiguration.playerTheme;
      if (playerTheme == null) {
        if (Platform.isAndroid) {
          playerTheme = PipFlutterPlayerTheme.material;
        } else {
          playerTheme = PipFlutterPlayerTheme.cupertino;
        }
      }

      if (controlsConfiguration.customControlsBuilder != null &&
          playerTheme == PipFlutterPlayerTheme.custom) {
        return controlsConfiguration.customControlsBuilder!(
            pipFlutterPlayerController, onControlsVisibilityChanged);
      } else if (playerTheme == PipFlutterPlayerTheme.material) {
        return _buildMaterialControl();
      } else if (playerTheme == PipFlutterPlayerTheme.cupertino) {
        return _buildCupertinoControl();
      }
    }

    return const SizedBox();
  }

  Widget _buildMaterialControl() {
    return PipFlutterPlayerMaterialControls(
      onControlsVisibilityChanged: onControlsVisibilityChanged,
      controlsConfiguration: controlsConfiguration,
    );
  }

  Widget _buildCupertinoControl() {
    return PipFlutterPlayerCupertinoControls(
      onControlsVisibilityChanged: onControlsVisibilityChanged,
      controlsConfiguration: controlsConfiguration,
    );
  }

  void onControlsVisibilityChanged(bool state) {
    playerVisibilityStreamController.add(state);
  }
}

///Widget used to set the proper box fit of the video. Default fit is 'fill'.
class _PipFlutterPlayerVideoFitWidget extends StatefulWidget {
  const _PipFlutterPlayerVideoFitWidget(
    this.pipFlutterPlayerController,
    this.boxFit, {
    Key? key,
  }) : super(key: key);

  final PipFlutterPlayerController pipFlutterPlayerController;
  final BoxFit boxFit;

  @override
  _PipFlutterPlayerVideoFitWidgetState createState() =>
      _PipFlutterPlayerVideoFitWidgetState();
}

class _PipFlutterPlayerVideoFitWidgetState
    extends State<_PipFlutterPlayerVideoFitWidget> {
  VideoPlayerController? get controller =>
      widget.pipFlutterPlayerController.videoPlayerController;

  bool _initialized = false;

  VoidCallback? _initializedListener;

  bool _started = false;

  StreamSubscription? _controllerEventSubscription;

  @override
  void initState() {
    super.initState();
    if (!widget.pipFlutterPlayerController.pipFlutterPlayerConfiguration
        .showPlaceholderUntilPlay) {
      _started = true;
    } else {
      _started = widget.pipFlutterPlayerController.hasCurrentDataSourceStarted;
    }

    _initialize();
  }

  @override
  void didUpdateWidget(_PipFlutterPlayerVideoFitWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pipFlutterPlayerController.videoPlayerController !=
        controller) {
      if (_initializedListener != null) {
        oldWidget.pipFlutterPlayerController.videoPlayerController!
            .removeListener(_initializedListener!);
      }
      _initialized = false;
      _initialize();
    }
  }

  void _initialize() {
    if (controller?.value.initialized == false) {
      _initializedListener = () {
        if (!mounted) {
          return;
        }

        if (_initialized != controller!.value.initialized) {
          _initialized = controller!.value.initialized;
          setState(() {});
        }
      };
      controller!.addListener(_initializedListener!);
    } else {
      _initialized = true;
    }

    _controllerEventSubscription =
        widget.pipFlutterPlayerController.controllerEventStream.listen((event) {
      if (event == PipFlutterPlayerControllerEvent.play) {
        if (!_started) {
          setState(() {
            _started =
                widget.pipFlutterPlayerController.hasCurrentDataSourceStarted;
          });
        }
      }
      if (event == PipFlutterPlayerControllerEvent.setupDataSource) {
        setState(() {
          _started = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initialized && _started) {
      return Center(
        child: ClipRect(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: FittedBox(
              fit: widget.boxFit,
              child: SizedBox(
                width: controller!.value.size?.width ?? 0,
                height: controller!.value.size?.height ?? 0,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        ),
      );
    } else {
      return const SizedBox();
    }
  }

  @override
  void dispose() {
    if (_initializedListener != null) {
      widget.pipFlutterPlayerController.videoPlayerController!
          .removeListener(_initializedListener!);
    }
    _controllerEventSubscription?.cancel();
    super.dispose();
  }
}
