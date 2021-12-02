import 'package:pip_flutter/pipflutter_player_asms_audio_track.dart';
import 'package:pip_flutter/pipflutter_player_asms_subtitle.dart';
import 'package:pip_flutter/pipflutter_player_asms_track.dart';

class PipFlutterPlayerAsmsDataHolder {
  List<PipFlutterPlayerAsmsTrack>? tracks;
  List<PipFlutterPlayerAsmsSubtitle>? subtitles;
  List<PipFlutterPlayerAsmsAudioTrack>? audios;

  PipFlutterPlayerAsmsDataHolder({this.tracks, this.subtitles, this.audios});
}
