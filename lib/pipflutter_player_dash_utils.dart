import 'package:pip_flutter/mime_types.dart';
import 'package:pip_flutter/pipflutter_player_asms_audio_track.dart';
import 'package:pip_flutter/pipflutter_player_asms_data_holder.dart';
import 'package:pip_flutter/pipflutter_player_asms_subtitle.dart';
import 'package:pip_flutter/pipflutter_player_asms_track.dart';
import 'package:pip_flutter/pipflutter_player_utils.dart';
import 'package:xml/xml.dart';

///DASH helper class
class PipFlutterPlayerDashUtils {
  static Future<PipFlutterPlayerAsmsDataHolder> parse(
      String data, String masterPlaylistUrl) async {
    List<PipFlutterPlayerAsmsTrack> tracks = [];
    final List<PipFlutterPlayerAsmsAudioTrack> audios = [];
    final List<PipFlutterPlayerAsmsSubtitle> subtitles = [];
    try {
      int audiosCount = 0;
      final document = XmlDocument.parse(data);
      final adaptationSets = document.findAllElements('AdaptationSet');
      adaptationSets.forEach((node) {
        final mimeType = node.getAttribute('mimeType');

        if (mimeType != null) {
          if (MimeTypes.isVideo(mimeType)) {
            tracks = tracks + parseVideo(node);
          } else if (MimeTypes.isAudio(mimeType)) {
            audios.add(parseAudio(node, audiosCount));
            audiosCount += 1;
          } else if (MimeTypes.isText(mimeType)) {
            subtitles.add(parseSubtitle(masterPlaylistUrl, node));
          }
        }
      });
    } catch (exception) {
      PipFlutterPlayerUtils.log("Exception on dash parse: $exception");
    }
    return PipFlutterPlayerAsmsDataHolder(
        tracks: tracks, audios: audios, subtitles: subtitles);
  }

  static List<PipFlutterPlayerAsmsTrack> parseVideo(XmlElement node) {
    final List<PipFlutterPlayerAsmsTrack> tracks = [];

    final representations = node.findAllElements('Representation');

    representations.forEach((representation) {
      final String? id = representation.getAttribute('id');
      final int width = int.parse(representation.getAttribute('width') ?? '0');
      final int height =
          int.parse(representation.getAttribute('height') ?? '0');
      final int bitrate =
          int.parse(representation.getAttribute('bandwidth') ?? '0');
      final int frameRate =
          int.parse(representation.getAttribute('frameRate') ?? '0');
      final String? codecs = representation.getAttribute('codecs');
      final String? mimeType = MimeTypes.getMediaMimeType(codecs ?? '');
      tracks.add(PipFlutterPlayerAsmsTrack(
          id, width, height, bitrate, frameRate, codecs, mimeType));
    });

    return tracks;
  }

  static PipFlutterPlayerAsmsAudioTrack parseAudio(XmlElement node, int index) {
    final String segmentAlignmentStr =
        node.getAttribute('segmentAlignment') ?? '';
    String? label = node.getAttribute('label');
    final String? language = node.getAttribute('lang');
    final String? mimeType = node.getAttribute('mimeType');

    label ??= language;

    return PipFlutterPlayerAsmsAudioTrack(
        id: index,
        segmentAlignment: segmentAlignmentStr.toLowerCase() == 'true',
        label: label,
        language: language,
        mimeType: mimeType);
  }

  static PipFlutterPlayerAsmsSubtitle parseSubtitle(
      String masterPlaylistUrl, XmlElement node) {
    final String segmentAlignmentStr =
        node.getAttribute('segmentAlignment') ?? '';
    String? name = node.getAttribute('label');
    final String? language = node.getAttribute('lang');
    final String? mimeType = node.getAttribute('mimeType');
    String? url =
        node.getElement('Representation')?.getElement('BaseURL')?.text;
    if (url?.contains("http") == false) {
      final Uri masterPlaylistUri = Uri.parse(masterPlaylistUrl);
      final pathSegments = <String>[...masterPlaylistUri.pathSegments];
      pathSegments[pathSegments.length - 1] = url!;
      url = Uri(
              scheme: masterPlaylistUri.scheme,
              host: masterPlaylistUri.host,
              port: masterPlaylistUri.port,
              pathSegments: pathSegments)
          .toString();
    }

    if (url != null && url.startsWith('//')) {
      url = 'https:$url';
    }

    name ??= language;

    return PipFlutterPlayerAsmsSubtitle(
        name: name,
        language: language,
        mimeType: mimeType,
        segmentAlignment: segmentAlignmentStr.toLowerCase() == 'true',
        url: url,
        realUrls: [url ?? '']);
  }
}
