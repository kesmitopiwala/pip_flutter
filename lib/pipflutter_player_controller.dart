import 'dart:async';
import 'dart:io';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pip_flutter/pipflutter_player_asms_audio_track.dart';
import 'package:pip_flutter/pipflutter_player_asms_data_holder.dart';
import 'package:pip_flutter/pipflutter_player_asms_subtitle.dart';
import 'package:pip_flutter/pipflutter_player_asms_track.dart';
import 'package:pip_flutter/pipflutter_player_asms_utils.dart';
import 'package:pip_flutter/pipflutter_player_cache_configuration.dart';
import 'package:pip_flutter/pipflutter_player_configuration.dart';
import 'package:pip_flutter/pipflutter_player_controller_event.dart';
import 'package:pip_flutter/pipflutter_player_controller_provider.dart';
import 'package:pip_flutter/pipflutter_player_data_source.dart';
import 'package:pip_flutter/pipflutter_player_data_source_type.dart';
import 'package:pip_flutter/pipflutter_player_drm_type.dart';
import 'package:pip_flutter/pipflutter_player_event.dart';
import 'package:pip_flutter/pipflutter_player_event_type.dart';
import 'package:pip_flutter/pipflutter_player_playlist_configuration.dart';
import 'package:pip_flutter/pipflutter_player_subtitle.dart';
import 'package:pip_flutter/pipflutter_player_subtitles_factory.dart';
import 'package:pip_flutter/pipflutter_player_subtitles_source.dart';
import 'package:pip_flutter/pipflutter_player_subtitles_source_type.dart';
import 'package:pip_flutter/pipflutter_player_translations.dart';
import 'package:pip_flutter/pipflutter_player_utils.dart';
import 'package:pip_flutter/pipflutter_player_video_format.dart';
import 'package:pip_flutter/video_player.dart';
import 'package:pip_flutter/video_player_platform_interface.dart';

///Class used to control overall PipFlutter Player behavior. Main class to change
///state of PipFlutter Player.
class PipFlutterPlayerController {
  static const String _durationParameter = "duration";
  static const String _progressParameter = "progress";
  static const String _bufferedParameter = "buffered";
  static const String _volumeParameter = "volume";
  static const String _speedParameter = "speed";
  static const String _dataSourceParameter = "dataSource";
  static const String _authorizationHeader = "Authorization";

  ///General configuration used in controller instance.
  final PipFlutterPlayerConfiguration pipFlutterPlayerConfiguration;

  ///Playlist configuration used in controller instance.
  final PipFlutterPlayerPlaylistConfiguration?
      pipFlutterPlayerPlaylistConfiguration;

  ///List of event listeners, which listen to events.
  final List<Function(PipFlutterPlayerEvent)?> _eventListeners = [];

  ///List of files to delete once player disposes.
  final List<File> _tempFiles = [];

  ///Stream controller which emits stream when control visibility changes.
  final StreamController<bool> _controlsVisibilityStreamController =
      StreamController.broadcast();

  ///Instance of video player controller which is adapter used to communicate
  ///between flutter high level code and lower level native code.
  VideoPlayerController? videoPlayerController;

  ///Expose all active eventListeners
  List<Function(PipFlutterPlayerEvent)?> get eventListeners =>
      _eventListeners.sublist(1);

  /// Defines a event listener where video player events will be send.
  Function(PipFlutterPlayerEvent)? get eventListener =>
      pipFlutterPlayerConfiguration.eventListener;

  ///Flag used to store full screen mode state.
  bool _isFullScreen = false;

  ///Flag used to store full screen mode state.
  bool get isFullScreen => _isFullScreen;

  ///Time when last progress event was sent
  int _lastPositionSelection = 0;

  ///Currently used data source in player.
  PipFlutterPlayerDataSource? _pipFlutterPlayerDataSource;

  ///Currently used data source in player.
  PipFlutterPlayerDataSource? get pipFlutterPlayerDataSource =>
      _pipFlutterPlayerDataSource;

  ///List of PipFlutterPlayerSubtitlesSources.
  final List<PipFlutterPlayerSubtitlesSource>
      _pipFlutterPlayerSubtitlesSourceList = [];

  ///List of PipFlutterPlayerSubtitlesSources.
  List<PipFlutterPlayerSubtitlesSource>
      get pipFlutterPlayerSubtitlesSourceList =>
          _pipFlutterPlayerSubtitlesSourceList;
  PipFlutterPlayerSubtitlesSource? _pipFlutterPlayerSubtitlesSource;

  ///Currently used subtitles source.
  PipFlutterPlayerSubtitlesSource? get pipFlutterPlayerSubtitlesSource =>
      _pipFlutterPlayerSubtitlesSource;

  ///Subtitles lines for current data source.
  List<PipFlutterPlayerSubtitle> subtitlesLines = [];

  ///List of tracks available for current data source. Used only for HLS / DASH.
  List<PipFlutterPlayerAsmsTrack> _pipFlutterPlayerAsmsTracks = [];

  ///List of tracks available for current data source. Used only for HLS / DASH.
  List<PipFlutterPlayerAsmsTrack> get pipFlutterPlayerAsmsTracks =>
      _pipFlutterPlayerAsmsTracks;

  ///Currently selected player track. Used only for HLS / DASH.
  PipFlutterPlayerAsmsTrack? _pipFlutterPlayerAsmsTrack;

  ///Currently selected player track. Used only for HLS / DASH.
  PipFlutterPlayerAsmsTrack? get pipFlutterPlayerAsmsTrack =>
      _pipFlutterPlayerAsmsTrack;

  ///Timer for next video. Used in playlist.
  Timer? _nextVideoTimer;

  ///Time for next video.
  int? _nextVideoTime;

  ///Stream controller which emits next video time.
  final StreamController<int?> _nextVideoTimeStreamController =
      StreamController.broadcast();

  Stream<int?> get nextVideoTimeStream => _nextVideoTimeStreamController.stream;

  ///Has player been disposed.
  bool _disposed = false;

  ///Was player playing before automatic pause.
  bool? _wasPlayingBeforePause;

  ///Currently used translations
  PipFlutterPlayerTranslations translations = PipFlutterPlayerTranslations();

  ///Has current data source started
  bool _hasCurrentDataSourceStarted = false;

  ///Has current data source initialized
  bool _hasCurrentDataSourceInitialized = false;

  ///Stream which sends flag whenever visibility of controls changes
  Stream<bool> get controlsVisibilityStream =>
      _controlsVisibilityStreamController.stream;

  ///Current app lifecycle state.
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  ///Flag which determines if controls (UI interface) is shown. When false,
  ///UI won't be shown (show only player surface).
  bool _controlsEnabled = true;

  ///Flag which determines if controls (UI interface) is shown. When false,
  ///UI won't be shown (show only player surface).
  bool get controlsEnabled => _controlsEnabled;

  ///Overridden aspect ratio which will be used instead of aspect ratio passed
  ///in configuration.
  double? _overriddenAspectRatio;

  ///Was Picture in Picture opened.
  bool _wasInPipMode = false;

  ///Was player in fullscreen before Picture in Picture opened.
  bool _wasInFullScreenBeforePiP = false;

  ///Was controls enabled before Picture in Picture opened.
  bool _wasControlsEnabledBeforePiP = false;

  ///GlobalKey of the BetterPlayer widget
  GlobalKey? _pipFlutterPlayerGlobalKey;

  ///Getter of the GlobalKey
  GlobalKey? get pipFlutterPlayerGlobalKey => _pipFlutterPlayerGlobalKey;

  ///StreamSubscription for VideoEvent listener
  StreamSubscription<VideoEvent>? _videoEventStreamSubscription;

  ///Are controls always visible
  bool _controlsAlwaysVisible = false;

  ///Are controls always visible
  bool get controlsAlwaysVisible => _controlsAlwaysVisible;

  ///List of all possible audio tracks returned from ASMS stream
  List<PipFlutterPlayerAsmsAudioTrack>? _pipFlutterPlayerAsmsAudioTracks;

  ///List of all possible audio tracks returned from ASMS stream
  List<PipFlutterPlayerAsmsAudioTrack>? get pipFlutterPlayerAsmsAudioTracks =>
      _pipFlutterPlayerAsmsAudioTracks;

  ///Selected ASMS audio track
  PipFlutterPlayerAsmsAudioTrack? _pipFlutterPlayerAsmsAudioTrack;

  ///Selected ASMS audio track
  PipFlutterPlayerAsmsAudioTrack? get pipFlutterPlayerAsmsAudioTrack =>
      _pipFlutterPlayerAsmsAudioTrack;

  ///Selected videoPlayerValue when error occurred.
  VideoPlayerValue? _videoPlayerValueOnError;

  ///Flag which holds information about player visibility
  bool _isPlayerVisible = true;

  final StreamController<PipFlutterPlayerControllerEvent>
      _controllerEventStreamController = StreamController.broadcast();

  ///Stream of internal controller events. Shouldn't be used inside app. For
  ///normal events, use eventListener.
  Stream<PipFlutterPlayerControllerEvent> get controllerEventStream =>
      _controllerEventStreamController.stream;

  ///Flag which determines whether are ASMS segments loading
  bool _asmsSegmentsLoading = false;

  ///List of loaded ASMS segments
  final List<String> _asmsSegmentsLoaded = [];

  ///Currently displayed [PipFlutterPlayerSubtitle].
  PipFlutterPlayerSubtitle? renderedSubtitle;

  PipFlutterPlayerController(
    this.pipFlutterPlayerConfiguration, {
    this.pipFlutterPlayerPlaylistConfiguration,
    PipFlutterPlayerDataSource? pipFlutterPlayerDataSource,
  }) {
    _eventListeners.add(eventListener);
    if (pipFlutterPlayerDataSource != null) {
      setupDataSource(pipFlutterPlayerDataSource);
    }
  }

  ///Get PipFlutterPlayerController from context. Used in InheritedWidget.
  static PipFlutterPlayerController of(BuildContext context) {
    final pipFlutterPLayerControllerProvider =
        context.dependOnInheritedWidgetOfExactType<
            PipFlutterPlayerControllerProvider>()!;

    return pipFlutterPLayerControllerProvider.controller;
  }

  ///Setup new data source in PipFlutter Player.
  Future setupDataSource(
      PipFlutterPlayerDataSource pipFlutterPlayerDataSource) async {
    postEvent(PipFlutterPlayerEvent(PipFlutterPlayerEventType.setupDataSource,
        parameters: <String, dynamic>{
          _dataSourceParameter: pipFlutterPlayerDataSource,
        }));
    _postControllerEvent(PipFlutterPlayerControllerEvent.setupDataSource);
    _hasCurrentDataSourceStarted = false;
    _hasCurrentDataSourceInitialized = false;
    _pipFlutterPlayerDataSource = pipFlutterPlayerDataSource;
    _pipFlutterPlayerSubtitlesSourceList.clear();

    ///Build videoPlayerController if null
    if (videoPlayerController == null) {
      videoPlayerController = VideoPlayerController(
          bufferingConfiguration:
              pipFlutterPlayerDataSource.bufferingConfiguration);
      videoPlayerController?.addListener(_onVideoPlayerChanged);
    }

    ///Clear asms tracks
    pipFlutterPlayerAsmsTracks.clear();

    ///Setup subtitles
    final List<PipFlutterPlayerSubtitlesSource>?
        pipFlutterPlayerSubtitlesSourceList =
        pipFlutterPlayerDataSource.subtitles;
    if (pipFlutterPlayerSubtitlesSourceList != null) {
      _pipFlutterPlayerSubtitlesSourceList
          .addAll(pipFlutterPlayerDataSource.subtitles!);
    }

    if (_isDataSourceAsms(pipFlutterPlayerDataSource)) {
      _setupAsmsDataSource(pipFlutterPlayerDataSource).then((dynamic value) {
        _setupSubtitles();
      });
    } else {
      _setupSubtitles();
    }

    ///Process data source
    await _setupDataSource(pipFlutterPlayerDataSource);
    setTrack(PipFlutterPlayerAsmsTrack.defaultTrack());
  }

  ///Configure subtitles based on subtitles source.
  void _setupSubtitles() {
    _pipFlutterPlayerSubtitlesSourceList.add(
      PipFlutterPlayerSubtitlesSource(
          type: PipFlutterPlayerSubtitlesSourceType.none),
    );
    final defaultSubtitle = _pipFlutterPlayerSubtitlesSourceList
        .firstWhereOrNull((element) => element.selectedByDefault == true);

    ///Setup subtitles (none is default)
    setupSubtitleSource(
        defaultSubtitle ?? _pipFlutterPlayerSubtitlesSourceList.last,
        sourceInitialize: true);
  }

  ///Check if given [pipFlutterPlayerDataSource] is HLS / DASH-type data source.
  bool _isDataSourceAsms(
          PipFlutterPlayerDataSource pipFlutterPlayerDataSource) =>
      (PipFlutterPlayerAsmsUtils.isDataSourceHls(
              pipFlutterPlayerDataSource.url) ||
          pipFlutterPlayerDataSource.videoFormat ==
              PipFlutterPlayerVideoFormat.hls) ||
      (PipFlutterPlayerAsmsUtils.isDataSourceDash(
              pipFlutterPlayerDataSource.url) ||
          pipFlutterPlayerDataSource.videoFormat ==
              PipFlutterPlayerVideoFormat.dash);

  ///Configure HLS / DASH data source based on provided data source and configuration.
  ///This method configures tracks, subtitles and audio tracks from given
  ///master playlist.
  Future _setupAsmsDataSource(PipFlutterPlayerDataSource source) async {
    final String? data = await PipFlutterPlayerAsmsUtils.getDataFromUrl(
      pipFlutterPlayerDataSource!.url,
      _getHeaders(),
    );
    if (data != null) {
      final PipFlutterPlayerAsmsDataHolder _response =
          await PipFlutterPlayerAsmsUtils.parse(
              data, pipFlutterPlayerDataSource!.url);

      /// Load tracks
      if (_pipFlutterPlayerDataSource?.useAsmsTracks == true) {
        _pipFlutterPlayerAsmsTracks = _response.tracks ?? [];
      }

      /// Load subtitles
      if (pipFlutterPlayerDataSource?.useAsmsSubtitles == true) {
        final List<PipFlutterPlayerAsmsSubtitle> asmsSubtitles =
            _response.subtitles ?? [];
        for (var asmsSubtitle in asmsSubtitles) {
          _pipFlutterPlayerSubtitlesSourceList.add(
            PipFlutterPlayerSubtitlesSource(
              type: PipFlutterPlayerSubtitlesSourceType.network,
              name: asmsSubtitle.name,
              urls: asmsSubtitle.realUrls,
              asmsIsSegmented: asmsSubtitle.isSegmented,
              asmsSegmentsTime: asmsSubtitle.segmentsTime,
              asmsSegments: asmsSubtitle.segments,
              selectedByDefault: asmsSubtitle.isDefault,
            ),
          );
        }
      }

      ///Load audio tracks
      if (pipFlutterPlayerDataSource?.useAsmsAudioTracks == true &&
          _isDataSourceAsms(pipFlutterPlayerDataSource!)) {
        _pipFlutterPlayerAsmsAudioTracks = _response.audios ?? [];
        if (_pipFlutterPlayerAsmsAudioTracks?.isNotEmpty == true) {
          setAudioTrack(_pipFlutterPlayerAsmsAudioTracks!.first);
        }
      }
    }
  }

  ///Setup subtitles to be displayed from given subtitle source.
  ///If subtitles source is segmented then don't load videos at start. Videos
  ///will load with just in time policy.
  Future<void> setupSubtitleSource(
      PipFlutterPlayerSubtitlesSource subtitlesSource,
      {bool sourceInitialize = false}) async {
    _pipFlutterPlayerSubtitlesSource = subtitlesSource;
    subtitlesLines.clear();
    _asmsSegmentsLoaded.clear();
    _asmsSegmentsLoading = false;

    if (subtitlesSource.type != PipFlutterPlayerSubtitlesSourceType.none) {
      if (subtitlesSource.asmsIsSegmented == true) {
        return;
      }
      final subtitlesParsed =
          await PipFlutterPlayerSubtitlesFactory.parseSubtitles(
              subtitlesSource);
      subtitlesLines.addAll(subtitlesParsed);
    }

    _postEvent(
        PipFlutterPlayerEvent(PipFlutterPlayerEventType.changedSubtitles));
    if (!_disposed && !sourceInitialize) {
      _postControllerEvent(PipFlutterPlayerControllerEvent.changeSubtitles);
    }
  }

  ///Load ASMS subtitles segments for given [position].
  ///Segments are being loaded within range (current video position;endPosition)
  ///where endPosition is based on time segment detected in HLS playlist. If
  ///time segment is not present then 5000 ms will be used. Also time segment
  ///is multiplied by 5 to increase window of duration.
  ///Segments are also cached, so same segment won't load twice. Only one
  ///pack of segments can be load at given time.
  Future _loadAsmsSubtitlesSegments(Duration position) async {
    try {
      if (_asmsSegmentsLoading) {
        return;
      }
      _asmsSegmentsLoading = true;
      final PipFlutterPlayerSubtitlesSource? source =
          _pipFlutterPlayerSubtitlesSource;
      final Duration loadDurationEnd = Duration(
          milliseconds: position.inMilliseconds +
              5 * (_pipFlutterPlayerSubtitlesSource?.asmsSegmentsTime ?? 5000));

      final segmentsToLoad = _pipFlutterPlayerSubtitlesSource?.asmsSegments
          ?.where((segment) {
            return segment.startTime > position &&
                segment.endTime < loadDurationEnd &&
                !_asmsSegmentsLoaded.contains(segment.realUrl);
          })
          .map((segment) => segment.realUrl)
          .toList();

      if (segmentsToLoad != null && segmentsToLoad.isNotEmpty) {
        final subtitlesParsed =
            await PipFlutterPlayerSubtitlesFactory.parseSubtitles(
                PipFlutterPlayerSubtitlesSource(
          type: _pipFlutterPlayerSubtitlesSource!.type,
          headers: _pipFlutterPlayerSubtitlesSource!.headers,
          urls: segmentsToLoad,
        ));

        ///Additional check if current source of subtitles is same as source
        ///used to start loading subtitles. It can be different when user
        ///changes subtitles and there was already pending load.
        if (source == _pipFlutterPlayerSubtitlesSource) {
          subtitlesLines.addAll(subtitlesParsed);
          _asmsSegmentsLoaded.addAll(segmentsToLoad);
        }
      }
      _asmsSegmentsLoading = false;
    } catch (exception) {
      PipFlutterPlayerUtils.log(
          "Load ASMS subtitle segments failed: $exception");
    }
  }

  ///Get VideoFormat from PipFlutterPlayerVideoFormat (adapter method which translates
  ///to video_player supported format).
  VideoFormat? _getVideoFormat(
      PipFlutterPlayerVideoFormat? pipFlutterPlayerVideoFormat) {
    if (pipFlutterPlayerVideoFormat == null) {
      return null;
    }
    switch (pipFlutterPlayerVideoFormat) {
      case PipFlutterPlayerVideoFormat.dash:
        return VideoFormat.dash;
      case PipFlutterPlayerVideoFormat.hls:
        return VideoFormat.hls;
      case PipFlutterPlayerVideoFormat.ss:
        return VideoFormat.ss;
      case PipFlutterPlayerVideoFormat.other:
        return VideoFormat.other;
    }
  }

  ///Internal method which invokes videoPlayerController source setup.
  Future _setupDataSource(
      PipFlutterPlayerDataSource pipFlutterPlayerDataSource) async {
    switch (pipFlutterPlayerDataSource.type) {
      case PipFlutterPlayerDataSourceType.network:
        await videoPlayerController?.setNetworkDataSource(
          pipFlutterPlayerDataSource.url,
          headers: _getHeaders(),
          useCache: _pipFlutterPlayerDataSource!.cacheConfiguration?.useCache ??
              false,
          maxCacheSize:
              _pipFlutterPlayerDataSource!.cacheConfiguration?.maxCacheSize ??
                  0,
          maxCacheFileSize: _pipFlutterPlayerDataSource!
                  .cacheConfiguration?.maxCacheFileSize ??
              0,
          cacheKey: _pipFlutterPlayerDataSource?.cacheConfiguration?.key,
          showNotification: _pipFlutterPlayerDataSource
              ?.notificationConfiguration?.showNotification,
          title: _pipFlutterPlayerDataSource?.notificationConfiguration?.title,
          author:
              _pipFlutterPlayerDataSource?.notificationConfiguration?.author,
          imageUrl:
              _pipFlutterPlayerDataSource?.notificationConfiguration?.imageUrl,
          notificationChannelName: _pipFlutterPlayerDataSource
              ?.notificationConfiguration?.notificationChannelName,
          overriddenDuration: _pipFlutterPlayerDataSource!.overriddenDuration,
          formatHint: _getVideoFormat(_pipFlutterPlayerDataSource!.videoFormat),
          licenseUrl: _pipFlutterPlayerDataSource?.drmConfiguration?.licenseUrl,
          certificateUrl:
              _pipFlutterPlayerDataSource?.drmConfiguration?.certificateUrl,
          drmHeaders: _pipFlutterPlayerDataSource?.drmConfiguration?.headers,
          activityName: _pipFlutterPlayerDataSource
              ?.notificationConfiguration?.activityName,
          clearKey: _pipFlutterPlayerDataSource?.drmConfiguration?.clearKey,
          videoExtension: _pipFlutterPlayerDataSource!.videoExtension,
        );

        break;
      case PipFlutterPlayerDataSourceType.file:
        final file = File(pipFlutterPlayerDataSource.url);
        if (!file.existsSync()) {
          PipFlutterPlayerUtils.log(
              "File ${file.path} doesn't exists. This may be because "
              "you're acessing file from native path and Flutter doesn't "
              "recognize this path.");
        }

        await videoPlayerController?.setFileDataSource(
            File(pipFlutterPlayerDataSource.url),
            showNotification: _pipFlutterPlayerDataSource
                ?.notificationConfiguration?.showNotification,
            title:
                _pipFlutterPlayerDataSource?.notificationConfiguration?.title,
            author:
                _pipFlutterPlayerDataSource?.notificationConfiguration?.author,
            imageUrl: _pipFlutterPlayerDataSource
                ?.notificationConfiguration?.imageUrl,
            notificationChannelName: _pipFlutterPlayerDataSource
                ?.notificationConfiguration?.notificationChannelName,
            overriddenDuration: _pipFlutterPlayerDataSource!.overriddenDuration,
            activityName: _pipFlutterPlayerDataSource
                ?.notificationConfiguration?.activityName,
            clearKey: _pipFlutterPlayerDataSource?.drmConfiguration?.clearKey);
        break;
      case PipFlutterPlayerDataSourceType.memory:
        final file = await _createFile(_pipFlutterPlayerDataSource!.bytes!,
            extension: _pipFlutterPlayerDataSource!.videoExtension);

        if (file.existsSync()) {
          await videoPlayerController?.setFileDataSource(file,
              showNotification: _pipFlutterPlayerDataSource
                  ?.notificationConfiguration?.showNotification,
              title:
                  _pipFlutterPlayerDataSource?.notificationConfiguration?.title,
              author: _pipFlutterPlayerDataSource
                  ?.notificationConfiguration?.author,
              imageUrl: _pipFlutterPlayerDataSource
                  ?.notificationConfiguration?.imageUrl,
              notificationChannelName: _pipFlutterPlayerDataSource
                  ?.notificationConfiguration?.notificationChannelName,
              overriddenDuration:
                  _pipFlutterPlayerDataSource!.overriddenDuration,
              activityName: _pipFlutterPlayerDataSource
                  ?.notificationConfiguration?.activityName,
              clearKey:
                  _pipFlutterPlayerDataSource?.drmConfiguration?.clearKey);
          _tempFiles.add(file);
        } else {
          throw ArgumentError("Couldn't create file from memory.");
        }
        break;

      default:
        throw UnimplementedError(
            "${pipFlutterPlayerDataSource.type} is not implemented");
    }
    await _initializeVideo();
  }

  ///Create file from provided list of bytes. File will be created in temporary
  ///directory.
  Future<File> _createFile(List<int> bytes,
      {String? extension = "temp"}) async {
    final String dir = (await getTemporaryDirectory()).path;
    final File temp = File(
        '$dir/pipflutter_player_${DateTime.now().millisecondsSinceEpoch}.$extension');
    await temp.writeAsBytes(bytes);
    return temp;
  }

  ///Initializes video based on configuration. Invoke actions which need to be
  ///run on player start.
  Future _initializeVideo() async {
    setLooping(pipFlutterPlayerConfiguration.looping);
    _videoEventStreamSubscription?.cancel();
    _videoEventStreamSubscription = null;

    _videoEventStreamSubscription = videoPlayerController
        ?.videoEventStreamController.stream
        .listen(_handleVideoEvent);

    final fullScreenByDefault =
        pipFlutterPlayerConfiguration.fullScreenByDefault;
    if (pipFlutterPlayerConfiguration.autoPlay) {
      if (fullScreenByDefault && !isFullScreen) {
        enterFullScreen();
      }
      if (_isAutomaticPlayPauseHandled()) {
        if (_appLifecycleState == AppLifecycleState.resumed &&
            _isPlayerVisible) {
          await play();
        } else {
          _wasPlayingBeforePause = true;
        }
      } else {
        await play();
      }
    } else {
      if (fullScreenByDefault) {
        enterFullScreen();
      }
    }

    final startAt = pipFlutterPlayerConfiguration.startAt;
    if (startAt != null) {
      seekTo(startAt);
    }
  }

  ///Method which is invoked when full screen changes.
  Future<void> _onFullScreenStateChanged() async {
    if (videoPlayerController?.value.isPlaying == true && !_isFullScreen) {
      enterFullScreen();
      videoPlayerController?.removeListener(_onFullScreenStateChanged);
    }
  }

  ///Enables full screen mode in player. This will trigger route change.
  void enterFullScreen() {
    _isFullScreen = true;
    _postControllerEvent(PipFlutterPlayerControllerEvent.openFullscreen);
  }

  ///Disables full screen mode in player. This will trigger route change.
  void exitFullScreen() {
    _isFullScreen = false;
    _postControllerEvent(PipFlutterPlayerControllerEvent.hideFullscreen);
  }

  ///Enables/disables full screen mode based on current fullscreen state.
  void toggleFullScreen() {
    _isFullScreen = !_isFullScreen;
    if (_isFullScreen) {
      _postControllerEvent(PipFlutterPlayerControllerEvent.openFullscreen);
    } else {
      _postControllerEvent(PipFlutterPlayerControllerEvent.hideFullscreen);
    }
  }

  ///Start video playback. Play will be triggered only if current lifecycle state
  ///is resumed.
  Future<void> play() async {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }

    if (_appLifecycleState == AppLifecycleState.resumed) {
      await videoPlayerController!.play();
      _hasCurrentDataSourceStarted = true;
      _wasPlayingBeforePause = null;
      _postEvent(PipFlutterPlayerEvent(PipFlutterPlayerEventType.play));
      _postControllerEvent(PipFlutterPlayerControllerEvent.play);
    }
  }

  ///Enables/disables looping (infinity playback) mode.
  Future<void> setLooping(bool looping) async {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }

    await videoPlayerController!.setLooping(looping);
  }

  ///Stop video playback.
  Future<void> pause() async {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }

    await videoPlayerController!.pause();
    _postEvent(PipFlutterPlayerEvent(PipFlutterPlayerEventType.pause));
  }

  ///Move player to specific position/moment of the video.
  Future<void> seekTo(Duration moment) async {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }
    if (videoPlayerController?.value.duration == null) {
      throw StateError("The video has not been initialized yet.");
    }

    await videoPlayerController!.seekTo(moment);

    _postEvent(PipFlutterPlayerEvent(PipFlutterPlayerEventType.seekTo,
        parameters: <String, dynamic>{_durationParameter: moment}));

    final Duration? currentDuration = videoPlayerController!.value.duration;
    if (currentDuration == null) {
      return;
    }
    if (moment > currentDuration) {
      _postEvent(PipFlutterPlayerEvent(PipFlutterPlayerEventType.finished));
    } else {
      cancelNextVideoTimer();
    }
  }

  ///Set volume of player. Allows values from 0.0 to 1.0.
  Future<void> setVolume(double volume) async {
    if (volume < 0.0 || volume > 1.0) {
      PipFlutterPlayerUtils.log("Volume must be between 0.0 and 1.0");
      throw ArgumentError("Volume must be between 0.0 and 1.0");
    }
    if (videoPlayerController == null) {
      PipFlutterPlayerUtils.log("The data source has not been initialized");
      throw StateError("The data source has not been initialized");
    }
    await videoPlayerController!.setVolume(volume);
    _postEvent(PipFlutterPlayerEvent(
      PipFlutterPlayerEventType.setVolume,
      parameters: <String, dynamic>{_volumeParameter: volume},
    ));
  }

  ///Set playback speed of video. Allows to set speed value between 0 and 2.
  Future<void> setSpeed(double speed) async {
    if (speed <= 0 || speed > 2) {
      PipFlutterPlayerUtils.log("Speed must be between 0 and 2");
      throw ArgumentError("Speed must be between 0 and 2");
    }
    if (videoPlayerController == null) {
      PipFlutterPlayerUtils.log("The data source has not been initialized");
      throw StateError("The data source has not been initialized");
    }
    await videoPlayerController?.setSpeed(speed);
    _postEvent(
      PipFlutterPlayerEvent(
        PipFlutterPlayerEventType.setSpeed,
        parameters: <String, dynamic>{
          _speedParameter: speed,
        },
      ),
    );
  }

  ///Flag which determines whenever player is playing or not.
  bool? isPlaying() {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }
    return videoPlayerController!.value.isPlaying;
  }

  ///Flag which determines whenever player is loading video data or not.
  bool? isBuffering() {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }
    return videoPlayerController!.value.isBuffering;
  }

  ///Show or hide controls manually
  void setControlsVisibility(bool isVisible) {
    _controlsVisibilityStreamController.add(isVisible);
  }

  ///Enable/disable controls (when enabled = false, controls will be always hidden)
  void setControlsEnabled(bool enabled) {
    if (!enabled) {
      _controlsVisibilityStreamController.add(false);
    }
    _controlsEnabled = enabled;
  }

  ///Internal method, used to trigger CONTROLS_VISIBLE or CONTROLS_HIDDEN event
  ///once controls state changed.
  void toggleControlsVisibility(bool isVisible) {
    _postEvent(isVisible
        ? PipFlutterPlayerEvent(PipFlutterPlayerEventType.controlsVisible)
        : PipFlutterPlayerEvent(PipFlutterPlayerEventType.controlsHiddenEnd));
  }

  ///Send player event. Shouldn't be used manually.
  void postEvent(PipFlutterPlayerEvent pipFlutterPlayerEvent) {
    _postEvent(pipFlutterPlayerEvent);
  }

  ///Send player event to all listeners.
  void _postEvent(PipFlutterPlayerEvent pipFlutterPlayerEvent) {
    for (final Function(PipFlutterPlayerEvent)? eventListener
        in _eventListeners) {
      if (eventListener != null) {
        eventListener(pipFlutterPlayerEvent);
      }
    }
  }

  ///Listener used to handle video player changes.
  void _onVideoPlayerChanged() async {
    final VideoPlayerValue currentVideoPlayerValue =
        videoPlayerController?.value ??
            VideoPlayerValue(duration: const Duration());

    if (currentVideoPlayerValue.hasError) {
      _videoPlayerValueOnError ??= currentVideoPlayerValue;
      _postEvent(
        PipFlutterPlayerEvent(
          PipFlutterPlayerEventType.exception,
          parameters: <String, dynamic>{
            "exception": currentVideoPlayerValue.errorDescription
          },
        ),
      );
    }
    if (currentVideoPlayerValue.initialized &&
        !_hasCurrentDataSourceInitialized) {
      _hasCurrentDataSourceInitialized = true;
      _postEvent(PipFlutterPlayerEvent(PipFlutterPlayerEventType.initialized));
    }
    if (currentVideoPlayerValue.isPip) {
      _wasInPipMode = true;
    } else if (_wasInPipMode) {
      _postEvent(PipFlutterPlayerEvent(PipFlutterPlayerEventType.pipStop));
      _wasInPipMode = false;
      if (!_wasInFullScreenBeforePiP) {
        exitFullScreen();
      }
      if (_wasControlsEnabledBeforePiP) {
        setControlsEnabled(true);
      }
      videoPlayerController?.refresh();
    }

    if (_pipFlutterPlayerSubtitlesSource?.asmsIsSegmented == true) {
      _loadAsmsSubtitlesSegments(currentVideoPlayerValue.position);
    }

    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPositionSelection > 500) {
      _lastPositionSelection = now;
      _postEvent(
        PipFlutterPlayerEvent(
          PipFlutterPlayerEventType.progress,
          parameters: <String, dynamic>{
            _progressParameter: currentVideoPlayerValue.position,
            _durationParameter: currentVideoPlayerValue.duration
          },
        ),
      );
    }
  }

  ///Add event listener which listens to player events.
  void addEventsListener(Function(PipFlutterPlayerEvent) eventListener) {
    _eventListeners.add(eventListener);
  }

  ///Remove event listener. This method should be called once you're disposing
  ///PipFlutter Player.
  void removeEventsListener(Function(PipFlutterPlayerEvent) eventListener) {
    _eventListeners.remove(eventListener);
  }

  ///Flag which determines whenever player is playing live data source.
  bool isLiveStream() {
    if (_pipFlutterPlayerDataSource == null) {
      PipFlutterPlayerUtils.log("The data source has not been initialized");
      throw StateError("The data source has not been initialized");
    }
    return _pipFlutterPlayerDataSource!.liveStream == true;
  }

  ///Flag which determines whenever player data source has been initialized.
  bool? isVideoInitialized() {
    if (videoPlayerController == null) {
      PipFlutterPlayerUtils.log("The data source has not been initialized");
      throw StateError("The data source has not been initialized");
    }
    return videoPlayerController?.value.initialized;
  }

  ///Start timer which will trigger next video. Used in playlist. Do not use
  ///manually.
  void startNextVideoTimer() {
    if (_nextVideoTimer == null) {
      if (pipFlutterPlayerPlaylistConfiguration == null) {
        PipFlutterPlayerUtils.log(
            "BettterPlayerPlaylistConifugration has not been set!");
        throw StateError(
            "BettterPlayerPlaylistConifugration has not been set!");
      }

      _nextVideoTime =
          pipFlutterPlayerPlaylistConfiguration!.nextVideoDelay.inSeconds;
      _nextVideoTimeStreamController.add(_nextVideoTime);
      if (_nextVideoTime == 0) {
        return;
      }

      _nextVideoTimer =
          Timer.periodic(const Duration(milliseconds: 1000), (_timer) async {
        if (_nextVideoTime == 1) {
          _timer.cancel();
          _nextVideoTimer = null;
        }
        if (_nextVideoTime != null) {
          _nextVideoTime = _nextVideoTime! - 1;
        }
        _nextVideoTimeStreamController.add(_nextVideoTime);
      });
    }
  }

  ///Cancel next video timer. Used in playlist. Do not use manually.
  void cancelNextVideoTimer() {
    _nextVideoTime = null;
    _nextVideoTimeStreamController.add(_nextVideoTime);
    _nextVideoTimer?.cancel();
    _nextVideoTimer = null;
  }

  ///Play next video form playlist. Do not use manually.
  void playNextVideo() {
    _nextVideoTime = 0;
    _nextVideoTimeStreamController.add(_nextVideoTime);
    _postEvent(
        PipFlutterPlayerEvent(PipFlutterPlayerEventType.changedPlaylistItem));
    cancelNextVideoTimer();
  }

  ///Setup track parameters for currently played video. Can be only used for HLS or DASH
  ///data source.
  void setTrack(PipFlutterPlayerAsmsTrack track) {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }
    _postEvent(PipFlutterPlayerEvent(PipFlutterPlayerEventType.changedTrack,
        parameters: <String, dynamic>{
          "id": track.id,
          "width": track.width,
          "height": track.height,
          "bitrate": track.bitrate,
          "frameRate": track.frameRate,
          "codecs": track.codecs,
          "mimeType": track.mimeType,
        }));

    videoPlayerController!
        .setTrackParameters(track.width, track.height, track.bitrate);
    _pipFlutterPlayerAsmsTrack = track;
  }

  ///Check if player can be played/paused automatically
  bool _isAutomaticPlayPauseHandled() {
    return !(_pipFlutterPlayerDataSource
                ?.notificationConfiguration?.showNotification ==
            true) &&
        pipFlutterPlayerConfiguration.handleLifecycle;
  }

  ///Listener which handles state of player visibility. If player visibility is
  ///below 0.0 then video will be paused. When value is greater than 0, video
  ///will play again. If there's different handler of visibility then it will be
  ///used. If showNotification is set in data source or handleLifecycle is false
  /// then this logic will be ignored.
  void onPlayerVisibilityChanged(double visibilityFraction) async {
    _isPlayerVisible = visibilityFraction > 0;
    if (_disposed) {
      return;
    }
    _postEvent(PipFlutterPlayerEvent(
        PipFlutterPlayerEventType.changedPlayerVisibility));

    if (_isAutomaticPlayPauseHandled()) {
      if (pipFlutterPlayerConfiguration.playerVisibilityChangedBehavior !=
          null) {
        pipFlutterPlayerConfiguration
            .playerVisibilityChangedBehavior!(visibilityFraction);
      } else {
        if (visibilityFraction == 0) {
          _wasPlayingBeforePause ??= isPlaying();
          pause();
        } else {
          if (_wasPlayingBeforePause == true && !isPlaying()!) {
            play();
          }
        }
      }
    }
  }

  ///Set different resolution (quality) for video
  void setResolution(String url) async {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }
    final position = await videoPlayerController!.position;
    final wasPlayingBeforeChange = isPlaying()!;
    pause();
    await setupDataSource(pipFlutterPlayerDataSource!.copyWith(url: url));
    seekTo(position!);
    if (wasPlayingBeforeChange) {
      play();
    }
    _postEvent(PipFlutterPlayerEvent(
      PipFlutterPlayerEventType.changedResolution,
      parameters: <String, dynamic>{"url": url},
    ));
  }

  ///Setup translations for given locale. In normal use cases it shouldn't be
  ///called manually.
  void setupTranslations(Locale locale) {
    // ignore: unnecessary_null_comparison
    if (locale != null) {
      final String languageCode = locale.languageCode;
      translations = pipFlutterPlayerConfiguration.translations
              ?.firstWhereOrNull((translations) =>
                  translations.languageCode == languageCode) ??
          _getDefaultTranslations(locale);
    } else {
      PipFlutterPlayerUtils.log("Locale is null. Couldn't setup translations.");
    }
  }

  ///Setup default translations for selected user locale. These translations
  ///are pre-build in.
  PipFlutterPlayerTranslations _getDefaultTranslations(Locale locale) {
    final String languageCode = locale.languageCode;
    switch (languageCode) {
      case "pl":
        return PipFlutterPlayerTranslations.polish();
      case "zh":
        return PipFlutterPlayerTranslations.chinese();
      case "hi":
        return PipFlutterPlayerTranslations.hindi();
      case "tr":
        return PipFlutterPlayerTranslations.turkish();
      case "vi":
        return PipFlutterPlayerTranslations.vietnamese();
      case "es":
        return PipFlutterPlayerTranslations.spanish();
      default:
        return PipFlutterPlayerTranslations();
    }
  }

  ///Flag which determines whenever current data source has started.
  bool get hasCurrentDataSourceStarted => _hasCurrentDataSourceStarted;

  ///Set current lifecycle state. If state is [AppLifecycleState.resumed] then
  ///player starts playing again. if lifecycle is in [AppLifecycleState.paused]
  ///state, then video playback will stop. If showNotification is set in data
  ///source or handleLifecycle is false then this logic will be ignored.
  void setAppLifecycleState(AppLifecycleState appLifecycleState) {
    if (_isAutomaticPlayPauseHandled()) {
      _appLifecycleState = appLifecycleState;
      if (appLifecycleState == AppLifecycleState.resumed) {
        if (_wasPlayingBeforePause == true && _isPlayerVisible) {
          play();
        }
      }
      if (appLifecycleState == AppLifecycleState.paused) {
        _wasPlayingBeforePause ??= isPlaying();
        pause();
      }
    }
  }

  // ignore: use_setters_to_change_properties
  ///Setup overridden aspect ratio.
  void setOverriddenAspectRatio(double aspectRatio) {
    _overriddenAspectRatio = aspectRatio;
  }

  ///Get aspect ratio used in current video. If aspect ratio is null, then
  ///aspect ratio from PipFlutterPlayerConfiguration will be used. Otherwise
  ///[_overriddenAspectRatio] will be used.
  double? getAspectRatio() {
    return _overriddenAspectRatio ?? pipFlutterPlayerConfiguration.aspectRatio;
  }

  ///Enable Picture in Picture (PiP) mode. [pipFlutterPlayerGlobalKey] is required
  ///to open PiP mode in iOS. When device is not supported, PiP mode won't be
  ///open.
  Future<void>? enablePictureInPicture(
      GlobalKey pipFlutterPlayerGlobalKey) async {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }

    final bool isPipSupported =
        (await videoPlayerController!.isPictureInPictureSupported()) ?? false;

    if (isPipSupported) {
      _wasInFullScreenBeforePiP = _isFullScreen;
      _wasControlsEnabledBeforePiP = _controlsEnabled;
      setControlsEnabled(false);
      if (Platform.isAndroid) {
        _wasInFullScreenBeforePiP = _isFullScreen;
        await videoPlayerController?.enablePictureInPicture(
            left: 0, top: 0, width: 0, height: 0);
        enterFullScreen();
        _postEvent(PipFlutterPlayerEvent(PipFlutterPlayerEventType.pipStart));
        return;
      }
      if (Platform.isIOS) {
        final RenderBox? renderBox = pipFlutterPlayerGlobalKey.currentContext!
            .findRenderObject() as RenderBox?;
        if (renderBox == null) {
          PipFlutterPlayerUtils.log(
              "Can't show PiP. RenderBox is null. Did you provide valid global"
              " key?");
          return;
        }
        final Offset position = renderBox.localToGlobal(Offset.zero);
        return videoPlayerController?.enablePictureInPicture(
          left: position.dx,
          top: position.dy,
          width: renderBox.size.width,
          height: renderBox.size.height,
        );
      } else {
        PipFlutterPlayerUtils.log("Unsupported PiP in current platform.");
      }
    } else {
      PipFlutterPlayerUtils.log(
          "Picture in picture is not supported in this device. If you're "
          "using Android, please check if you're using activity v2 "
          "embedding.");
    }
  }

  ///Disable Picture in Picture mode if it's enabled.
  Future<void>? disablePictureInPicture() {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }
    return videoPlayerController!.disablePictureInPicture();
  }

  // ignore: use_setters_to_change_properties
  ///Set GlobalKey of PipFlutterPlayer. Used in PiP methods called from controls.
  void setPipFlutterPlayerGlobalKey(GlobalKey pipFlutterPlayerGlobalKey) {
    _pipFlutterPlayerGlobalKey = pipFlutterPlayerGlobalKey;
  }

  ///Check if picture in picture mode is supported in this device.
  Future<bool> isPictureInPictureSupported() async {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }

    final bool isPipSupported =
        (await videoPlayerController!.isPictureInPictureSupported()) ?? false;

    return isPipSupported && !_isFullScreen;
  }

  ///Handle VideoEvent when remote controls notification / PiP is shown
  void _handleVideoEvent(VideoEvent event) async {
    switch (event.eventType) {
      case VideoEventType.play:
        _postEvent(PipFlutterPlayerEvent(PipFlutterPlayerEventType.play));
        break;
      case VideoEventType.pause:
        _postEvent(PipFlutterPlayerEvent(PipFlutterPlayerEventType.pause));
        break;
      case VideoEventType.seek:
        _postEvent(PipFlutterPlayerEvent(PipFlutterPlayerEventType.seekTo));
        break;
      case VideoEventType.completed:
        final VideoPlayerValue? videoValue = videoPlayerController?.value;
        _postEvent(
          PipFlutterPlayerEvent(
            PipFlutterPlayerEventType.finished,
            parameters: <String, dynamic>{
              _progressParameter: videoValue?.position,
              _durationParameter: videoValue?.duration
            },
          ),
        );
        break;
      case VideoEventType.bufferingStart:
        _postEvent(
            PipFlutterPlayerEvent(PipFlutterPlayerEventType.bufferingStart));
        break;
      case VideoEventType.bufferingUpdate:
        _postEvent(PipFlutterPlayerEvent(
            PipFlutterPlayerEventType.bufferingUpdate,
            parameters: <String, dynamic>{
              _bufferedParameter: event.buffered,
            }));
        break;
      case VideoEventType.bufferingEnd:
        _postEvent(
            PipFlutterPlayerEvent(PipFlutterPlayerEventType.bufferingEnd));
        break;
      default:

        ///TODO: Handle when needed
        break;
    }
  }

  ///Setup controls always visible mode
  void setControlsAlwaysVisible(bool controlsAlwaysVisible) {
    _controlsAlwaysVisible = controlsAlwaysVisible;
    _controlsVisibilityStreamController.add(controlsAlwaysVisible);
  }

  ///Retry data source if playback failed.
  Future retryDataSource() async {
    await _setupDataSource(_pipFlutterPlayerDataSource!);
    if (_videoPlayerValueOnError != null) {
      final position = _videoPlayerValueOnError!.position;
      await seekTo(position);
      await play();
      _videoPlayerValueOnError = null;
    }
  }

  ///Set [audioTrack] in player. Works only for HLS or DASH streams.
  void setAudioTrack(PipFlutterPlayerAsmsAudioTrack audioTrack) {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }

    if (audioTrack.language == null) {
      _pipFlutterPlayerAsmsAudioTrack = null;
      return;
    }

    _pipFlutterPlayerAsmsAudioTrack = audioTrack;
    videoPlayerController!.setAudioTrack(audioTrack.label, audioTrack.id);
  }

  ///Enable or disable audio mixing with other sound within device.
  void setMixWithOthers(bool mixWithOthers) {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }

    videoPlayerController!.setMixWithOthers(mixWithOthers);
  }

  ///Clear all cached data. Video player controller must be initialized to
  ///clear the cache.
  Future<void> clearCache() async {
    return VideoPlayerController.clearCache();
  }

  ///Build headers map that will be used to setup video player controller. Apply
  ///DRM headers if available.
  Map<String, String?> _getHeaders() {
    final headers = pipFlutterPlayerDataSource!.headers ?? {};
    if (pipFlutterPlayerDataSource?.drmConfiguration?.drmType ==
            PipFlutterPlayerDrmType.token &&
        pipFlutterPlayerDataSource?.drmConfiguration?.token != null) {
      headers[_authorizationHeader] =
          pipFlutterPlayerDataSource!.drmConfiguration!.token!;
    }
    return headers;
  }

  ///PreCache a video. On Android, the future succeeds when
  ///the requested size, specified in
  ///[PipFlutterPlayerCacheConfiguration.preCacheSize], is downloaded or when the
  ///complete file is downloaded if the file is smaller than the requested size.
  ///On iOS, the whole file will be downloaded, since [maxCacheFileSize] is
  ///currently not supported on iOS. On iOS, the video format must be in this
  ///list: https://github.com/sendyhalim/Swime/blob/master/Sources/MimeType.swift
  Future<void> preCache(
      PipFlutterPlayerDataSource pipFlutterPlayerDataSource) async {
    final cacheConfig = pipFlutterPlayerDataSource.cacheConfiguration ??
        const PipFlutterPlayerCacheConfiguration(useCache: true);

    final dataSource = DataSource(
      sourceType: DataSourceType.network,
      uri: pipFlutterPlayerDataSource.url,
      useCache: true,
      headers: pipFlutterPlayerDataSource.headers,
      maxCacheSize: cacheConfig.maxCacheSize,
      maxCacheFileSize: cacheConfig.maxCacheFileSize,
      cacheKey: cacheConfig.key,
      videoExtension: pipFlutterPlayerDataSource.videoExtension,
    );

    return VideoPlayerController.preCache(dataSource, cacheConfig.preCacheSize);
  }

  ///Stop pre cache for given [pipFlutterPlayerDataSource]. If there was no pre
  ///cache started for given [pipFlutterPlayerDataSource] then it will be ignored.
  Future<void> stopPreCache(
      PipFlutterPlayerDataSource pipFlutterPlayerDataSource) async {
    return VideoPlayerController.stopPreCache(pipFlutterPlayerDataSource.url,
        pipFlutterPlayerDataSource.cacheConfiguration?.key);
  }

  /// Add controller internal event.
  void _postControllerEvent(PipFlutterPlayerControllerEvent event) {
    if (!_controllerEventStreamController.isClosed) {
      _controllerEventStreamController.add(event);
    }
  }

  ///Dispose PipFlutterPlayerController. When [forceDispose] parameter is true, then
  ///autoDispose parameter will be overridden and controller will be disposed
  ///(if it wasn't disposed before).
  void dispose({bool forceDispose = false}) {
    if (!pipFlutterPlayerConfiguration.autoDispose && !forceDispose) {
      return;
    }
    if (!_disposed) {
      if (videoPlayerController != null) {
        pause();
        videoPlayerController!.removeListener(_onFullScreenStateChanged);
        videoPlayerController!.removeListener(_onVideoPlayerChanged);
        videoPlayerController!.dispose();
      }
      _eventListeners.clear();
      _nextVideoTimer?.cancel();
      _nextVideoTimeStreamController.close();
      _controlsVisibilityStreamController.close();
      _videoEventStreamSubscription?.cancel();
      _disposed = true;
      _controllerEventStreamController.close();

      ///Delete files async
      for (var file in _tempFiles) {
        file.delete();
      }
    }
  }
}
