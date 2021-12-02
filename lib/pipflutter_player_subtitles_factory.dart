import 'dart:convert';
import 'dart:io';
import 'package:pip_flutter/pipflutter_player_subtitles_source.dart';
import 'package:pip_flutter/pipflutter_player_utils.dart';

import 'pipflutter_player_subtitle.dart';
import 'pipflutter_player_subtitles_source_type.dart';

class PipFlutterPlayerSubtitlesFactory {
  static Future<List<PipFlutterPlayerSubtitle>> parseSubtitles(
      PipFlutterPlayerSubtitlesSource source) async {
    switch (source.type) {
      case PipFlutterPlayerSubtitlesSourceType.file:
        return _parseSubtitlesFromFile(source);
      case PipFlutterPlayerSubtitlesSourceType.network:
        return _parseSubtitlesFromNetwork(source);
      case PipFlutterPlayerSubtitlesSourceType.memory:
        return _parseSubtitlesFromMemory(source);
      default:
        return [];
    }
  }

  static Future<List<PipFlutterPlayerSubtitle>> _parseSubtitlesFromFile(
      PipFlutterPlayerSubtitlesSource source) async {
    try {
      final List<PipFlutterPlayerSubtitle> subtitles = [];
      for (final String? url in source.urls!) {
        final file = File(url!);
        if (file.existsSync()) {
          final String fileContent = await file.readAsString();
          final subtitlesCache = _parseString(fileContent);
          subtitles.addAll(subtitlesCache);
        } else {
          PipFlutterPlayerUtils.log("$url doesn't exist!");
        }
      }
      return subtitles;
    } catch (exception) {
      PipFlutterPlayerUtils.log(
          "Failed to read subtitles from file: $exception");
    }
    return [];
  }

  static Future<List<PipFlutterPlayerSubtitle>> _parseSubtitlesFromNetwork(
      PipFlutterPlayerSubtitlesSource source) async {
    try {
      final client = HttpClient();
      final List<PipFlutterPlayerSubtitle> subtitles = [];
      for (final String? url in source.urls!) {
        final request = await client.getUrl(Uri.parse(url!));
        source.headers?.keys.forEach((key) {
          final value = source.headers![key];
          if (value != null) {
            request.headers.add(key, value);
          }
        });
        final response = await request.close();
        final data = await response.transform(const Utf8Decoder()).join();
        final cacheList = _parseString(data);
        subtitles.addAll(cacheList);
      }
      client.close();

      PipFlutterPlayerUtils.log("Parsed total subtitles: ${subtitles.length}");
      return subtitles;
    } catch (exception) {
      PipFlutterPlayerUtils.log(
          "Failed to read subtitles from network: $exception");
    }
    return [];
  }

  static List<PipFlutterPlayerSubtitle> _parseSubtitlesFromMemory(
      PipFlutterPlayerSubtitlesSource source) {
    try {
      return _parseString(source.content!);
    } catch (exception) {
      PipFlutterPlayerUtils.log(
          "Failed to read subtitles from memory: $exception");
    }
    return [];
  }

  static List<PipFlutterPlayerSubtitle> _parseString(String value) {
    List<String> components = value.split('\r\n\r\n');
    if (components.length == 1) {
      components = value.split('\n\n');
    }

    // Skip parsing files with no cues
    if (components.length == 1) {
      return [];
    }

    final List<PipFlutterPlayerSubtitle> subtitlesObj = [];

    final bool isWebVTT = components.contains("WEBVTT");
    for (final component in components) {
      if (component.isEmpty) {
        continue;
      }
      final subtitle = PipFlutterPlayerSubtitle(component, isWebVTT);
      if (subtitle.start != null &&
          subtitle.end != null &&
          subtitle.texts != null) {
        subtitlesObj.add(subtitle);
      }
    }

    return subtitlesObj;
  }
}
