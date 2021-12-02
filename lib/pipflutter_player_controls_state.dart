import 'dart:io';
import 'dart:math';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pip_flutter/pipflutter_player_asms_audio_track.dart';
import 'package:pip_flutter/pipflutter_player_asms_track.dart';
import 'package:pip_flutter/pipflutter_player_clickable_widget.dart';
import 'package:pip_flutter/pipflutter_player_controls_configuration.dart';
import 'package:pip_flutter/pipflutter_player_event.dart';
import 'package:pip_flutter/pipflutter_player_event_type.dart';
import 'package:pip_flutter/pipflutter_player_subtitles_source.dart';
import 'package:pip_flutter/pipflutter_player_subtitles_source_type.dart';
import 'package:pip_flutter/pipflutter_player_utils.dart';
import 'package:pip_flutter/video_player.dart';
import 'pipflutter_player_controller.dart';

///Base class for both material and cupertino controls
abstract class PipFlutterPlayerControlsState<T extends StatefulWidget>
    extends State<T> {
  ///Min. time of buffered video to hide loading timer (in milliseconds)
  static const int _bufferingInterval = 20000;

  PipFlutterPlayerController? get pipFlutterPlayerController;

  PipFlutterPlayerControlsConfiguration
      get pipFlutterPlayerControlsConfiguration;

  VideoPlayerValue? get latestValue;

  bool controlsNotVisible = true;

  void cancelAndRestartTimer();

  bool isVideoFinished(VideoPlayerValue? videoPlayerValue) {
    return videoPlayerValue?.position != null &&
        videoPlayerValue?.duration != null &&
        videoPlayerValue!.position.inMilliseconds != 0 &&
        videoPlayerValue.duration!.inMilliseconds != 0 &&
        videoPlayerValue.position >= videoPlayerValue.duration!;
  }

  void skipBack() {
    if (latestValue != null) {
      cancelAndRestartTimer();
      final beginning = const Duration().inMilliseconds;
      final skip = (latestValue!.position -
              Duration(
                  milliseconds: pipFlutterPlayerControlsConfiguration
                      .backwardSkipTimeInMilliseconds))
          .inMilliseconds;
      pipFlutterPlayerController!
          .seekTo(Duration(milliseconds: max(skip, beginning)));
    }
  }

  void skipForward() {
    if (latestValue != null) {
      cancelAndRestartTimer();
      final end = latestValue!.duration!.inMilliseconds;
      final skip = (latestValue!.position +
              Duration(
                  milliseconds: pipFlutterPlayerControlsConfiguration
                      .forwardSkipTimeInMilliseconds))
          .inMilliseconds;
      pipFlutterPlayerController!
          .seekTo(Duration(milliseconds: min(skip, end)));
    }
  }

  void onShowMoreClicked() {
    _showModalBottomSheet([_buildMoreOptionsList()]);
  }

  Widget _buildMoreOptionsList() {
    final translations = pipFlutterPlayerController!.translations;
    return SingleChildScrollView(
      // ignore: avoid_unnecessary_containers
      child: Container(
        child: Column(
          children: [
            if (pipFlutterPlayerControlsConfiguration.enablePlaybackSpeed)
              _buildMoreOptionsListRow(
                  pipFlutterPlayerControlsConfiguration.playbackSpeedIcon,
                  translations.overflowMenuPlaybackSpeed, () {
                Navigator.of(context).pop();
                _showSpeedChooserWidget();
              }),
            if (pipFlutterPlayerControlsConfiguration.enableSubtitles)
              _buildMoreOptionsListRow(
                  pipFlutterPlayerControlsConfiguration.subtitlesIcon,
                  translations.overflowMenuSubtitles, () {
                Navigator.of(context).pop();
                _showSubtitlesSelectionWidget();
              }),
            if (pipFlutterPlayerControlsConfiguration.enableQualities)
              _buildMoreOptionsListRow(
                  pipFlutterPlayerControlsConfiguration.qualitiesIcon,
                  translations.overflowMenuQuality, () {
                Navigator.of(context).pop();
                _showQualitiesSelectionWidget();
              }),
            if (pipFlutterPlayerControlsConfiguration.enableAudioTracks)
              _buildMoreOptionsListRow(
                  pipFlutterPlayerControlsConfiguration.audioTracksIcon,
                  translations.overflowMenuAudioTracks, () {
                Navigator.of(context).pop();
                _showAudioTracksSelectionWidget();
              }),
            if (pipFlutterPlayerControlsConfiguration
                .overflowMenuCustomItems.isNotEmpty)
              ...pipFlutterPlayerControlsConfiguration.overflowMenuCustomItems
                  .map(
                (customItem) => _buildMoreOptionsListRow(
                  customItem.icon,
                  customItem.title,
                  () {
                    Navigator.of(context).pop();
                    customItem.onClicked.call();
                  },
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildMoreOptionsListRow(
      IconData icon, String name, void Function() onTap) {
    return PipFlutterPlayerMaterialClickableWidget(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(
              icon,
              color:
                  pipFlutterPlayerControlsConfiguration.overflowMenuIconsColor,
            ),
            const SizedBox(width: 16),
            Text(
              name,
              style: _getOverflowMenuElementTextStyle(false),
            ),
          ],
        ),
      ),
    );
  }

  void _showSpeedChooserWidget() {
    _showModalBottomSheet([
      _buildSpeedRow(0.25),
      _buildSpeedRow(0.5),
      _buildSpeedRow(0.75),
      _buildSpeedRow(1.0),
      _buildSpeedRow(1.25),
      _buildSpeedRow(1.5),
      _buildSpeedRow(1.75),
      _buildSpeedRow(2.0),
    ]);
  }

  Widget _buildSpeedRow(double value) {
    final bool isSelected =
        pipFlutterPlayerController!.videoPlayerController!.value.speed == value;

    return PipFlutterPlayerMaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        pipFlutterPlayerController!.setSpeed(value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            SizedBox(width: isSelected ? 8 : 16),
            Visibility(
                visible: isSelected,
                child: Icon(
                  Icons.check_outlined,
                  color: pipFlutterPlayerControlsConfiguration
                      .overflowModalTextColor,
                )),
            const SizedBox(width: 16),
            Text(
              "$value x",
              style: _getOverflowMenuElementTextStyle(isSelected),
            )
          ],
        ),
      ),
    );
  }

  ///Latest value can be null
  bool isLoading(VideoPlayerValue? latestValue) {
    if (latestValue != null) {
      if (!latestValue.isPlaying && latestValue.duration == null) {
        return true;
      }

      final Duration position = latestValue.position;

      Duration? bufferedEndPosition;
      if (latestValue.buffered.isNotEmpty == true) {
        bufferedEndPosition = latestValue.buffered.last.end;
      }

      if (bufferedEndPosition != null) {
        final difference = bufferedEndPosition - position;

        if (latestValue.isPlaying &&
            latestValue.isBuffering &&
            difference.inMilliseconds < _bufferingInterval) {
          return true;
        }
      }
    }
    return false;
  }

  void _showSubtitlesSelectionWidget() {
    final subtitles = List.of(
        pipFlutterPlayerController!.pipFlutterPlayerSubtitlesSourceList);
    final noneSubtitlesElementExists = subtitles.firstWhereOrNull((source) =>
            source.type == PipFlutterPlayerSubtitlesSourceType.none) !=
        null;
    if (!noneSubtitlesElementExists) {
      subtitles.add(PipFlutterPlayerSubtitlesSource(
          type: PipFlutterPlayerSubtitlesSourceType.none));
    }

    _showModalBottomSheet(
        subtitles.map((source) => _buildSubtitlesSourceRow(source)).toList());
  }

  Widget _buildSubtitlesSourceRow(
      PipFlutterPlayerSubtitlesSource subtitlesSource) {
    final selectedSourceType =
        pipFlutterPlayerController!.pipFlutterPlayerSubtitlesSource;
    final bool isSelected = (subtitlesSource == selectedSourceType) ||
        (subtitlesSource.type == PipFlutterPlayerSubtitlesSourceType.none &&
            subtitlesSource.type == selectedSourceType!.type);

    return PipFlutterPlayerMaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        pipFlutterPlayerController!.setupSubtitleSource(subtitlesSource);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            SizedBox(width: isSelected ? 8 : 16),
            Visibility(
                visible: isSelected,
                child: Icon(
                  Icons.check_outlined,
                  color: pipFlutterPlayerControlsConfiguration
                      .overflowModalTextColor,
                )),
            const SizedBox(width: 16),
            Text(
              subtitlesSource.type == PipFlutterPlayerSubtitlesSourceType.none
                  ? pipFlutterPlayerController!.translations.generalNone
                  : subtitlesSource.name ??
                      pipFlutterPlayerController!.translations.generalDefault,
              style: _getOverflowMenuElementTextStyle(isSelected),
            ),
          ],
        ),
      ),
    );
  }

  ///Build both track and resolution selection
  ///Track selection is used for HLS / DASH videos
  ///Resolution selection is used for normal videos
  void _showQualitiesSelectionWidget() {
    // HLS / DASH
    final List<String> asmsTrackNames = pipFlutterPlayerController!
            .pipFlutterPlayerDataSource!.asmsTrackNames ??
        [];
    final List<PipFlutterPlayerAsmsTrack> asmsTracks =
        pipFlutterPlayerController!.pipFlutterPlayerAsmsTracks;
    final List<Widget> children = [];
    for (var index = 0; index < asmsTracks.length; index++) {
      final track = asmsTracks[index];

      String? preferredName;
      if (track.height == 0 && track.width == 0 && track.bitrate == 0) {
        preferredName = pipFlutterPlayerController!.translations.qualityAuto;
      } else {
        preferredName =
            asmsTrackNames.length > index ? asmsTrackNames[index] : null;
      }
      children.add(_buildTrackRow(asmsTracks[index], preferredName));
    }

    // normal videos
    final resolutions =
        pipFlutterPlayerController!.pipFlutterPlayerDataSource!.resolutions;
    resolutions?.forEach((key, value) {
      children.add(_buildResolutionSelectionRow(key, value));
    });

    if (children.isEmpty) {
      children.add(
        _buildTrackRow(PipFlutterPlayerAsmsTrack.defaultTrack(),
            pipFlutterPlayerController!.translations.qualityAuto),
      );
    }

    _showModalBottomSheet(children);
  }

  Widget _buildTrackRow(
      PipFlutterPlayerAsmsTrack track, String? preferredName) {
    final int width = track.width ?? 0;
    final int height = track.height ?? 0;
    final int bitrate = track.bitrate ?? 0;
    final String mimeType = (track.mimeType ?? '').replaceAll('video/', '');
    final String trackName = preferredName ??
        "${width}x$height ${PipFlutterPlayerUtils.formatBitrate(bitrate)} $mimeType";

    final PipFlutterPlayerAsmsTrack? selectedTrack =
        pipFlutterPlayerController!.pipFlutterPlayerAsmsTrack;
    final bool isSelected = selectedTrack != null && selectedTrack == track;

    return PipFlutterPlayerMaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        pipFlutterPlayerController!.setTrack(track);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            SizedBox(width: isSelected ? 8 : 16),
            Visibility(
                visible: isSelected,
                child: Icon(
                  Icons.check_outlined,
                  color: pipFlutterPlayerControlsConfiguration
                      .overflowModalTextColor,
                )),
            const SizedBox(width: 16),
            Text(
              trackName,
              style: _getOverflowMenuElementTextStyle(isSelected),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolutionSelectionRow(String name, String url) {
    final bool isSelected =
        url == pipFlutterPlayerController!.pipFlutterPlayerDataSource!.url;
    return PipFlutterPlayerMaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        pipFlutterPlayerController!.setResolution(url);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            SizedBox(width: isSelected ? 8 : 16),
            Visibility(
                visible: isSelected,
                child: Icon(
                  Icons.check_outlined,
                  color: pipFlutterPlayerControlsConfiguration
                      .overflowModalTextColor,
                )),
            const SizedBox(width: 16),
            Text(
              name,
              style: _getOverflowMenuElementTextStyle(isSelected),
            ),
          ],
        ),
      ),
    );
  }

  void _showAudioTracksSelectionWidget() {
    //HLS / DASH
    final List<PipFlutterPlayerAsmsAudioTrack>? asmsTracks =
        pipFlutterPlayerController!.pipFlutterPlayerAsmsAudioTracks;
    final List<Widget> children = [];
    final PipFlutterPlayerAsmsAudioTrack? selectedAsmsAudioTrack =
        pipFlutterPlayerController!.pipFlutterPlayerAsmsAudioTrack;
    if (asmsTracks != null) {
      for (var index = 0; index < asmsTracks.length; index++) {
        final bool isSelected = selectedAsmsAudioTrack != null &&
            selectedAsmsAudioTrack == asmsTracks[index];
        children.add(_buildAudioTrackRow(asmsTracks[index], isSelected));
      }
    }

    if (children.isEmpty) {
      children.add(
        _buildAudioTrackRow(
          PipFlutterPlayerAsmsAudioTrack(
            label: pipFlutterPlayerController!.translations.generalDefault,
          ),
          true,
        ),
      );
    }

    _showModalBottomSheet(children);
  }

  Widget _buildAudioTrackRow(
      PipFlutterPlayerAsmsAudioTrack audioTrack, bool isSelected) {
    return PipFlutterPlayerMaterialClickableWidget(
      onTap: () {
        Navigator.of(context).pop();
        pipFlutterPlayerController!.setAudioTrack(audioTrack);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            SizedBox(width: isSelected ? 8 : 16),
            Visibility(
                visible: isSelected,
                child: Icon(
                  Icons.check_outlined,
                  color: pipFlutterPlayerControlsConfiguration
                      .overflowModalTextColor,
                )),
            const SizedBox(width: 16),
            Text(
              audioTrack.label!,
              style: _getOverflowMenuElementTextStyle(isSelected),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _getOverflowMenuElementTextStyle(bool isSelected) {
    return TextStyle(
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      color: isSelected
          ? pipFlutterPlayerControlsConfiguration.overflowModalTextColor
          : pipFlutterPlayerControlsConfiguration.overflowModalTextColor
              .withOpacity(0.7),
    );
  }

  void _showModalBottomSheet(List<Widget> children) {
    Platform.isAndroid
        ? _showMaterialBottomSheet(children)
        : _showCupertinoModalBottomSheet(children);
  }

  void _showCupertinoModalBottomSheet(List<Widget> children) {
    showCupertinoModalPopup<void>(
      barrierColor: Colors.transparent,
      context: context,
      useRootNavigator: pipFlutterPlayerController
              ?.pipFlutterPlayerConfiguration.useRootNavigator ??
          false,
      builder: (context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: pipFlutterPlayerControlsConfiguration.overflowModalColor,
                /*shape: RoundedRectangleBorder(side: Bor,borderRadius: 24,)*/
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24.0),
                    topRight: Radius.circular(24.0)),
              ),
              child: Column(
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMaterialBottomSheet(List<Widget> children) {
    showModalBottomSheet<void>(
      backgroundColor: Colors.transparent,
      context: context,
      useRootNavigator: pipFlutterPlayerController
              ?.pipFlutterPlayerConfiguration.useRootNavigator ??
          false,
      builder: (context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: pipFlutterPlayerControlsConfiguration.overflowModalColor,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24.0),
                    topRight: Radius.circular(24.0)),
              ),
              child: Column(
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }

  ///Builds directionality widget which wraps child widget and forces left to
  ///right directionality.
  Widget buildLTRDirectionality(Widget child) {
    return Directionality(textDirection: TextDirection.ltr, child: child);
  }

  ///Called when player controls visibility should be changed.
  void changePlayerControlsNotVisible(bool notVisible) {
    setState(() {
      if (notVisible) {
        pipFlutterPlayerController?.postEvent(PipFlutterPlayerEvent(
            PipFlutterPlayerEventType.controlsHiddenStart));
      }
      controlsNotVisible = notVisible;
    });
  }
}
