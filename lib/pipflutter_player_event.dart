import 'package:pip_flutter/pipflutter_player_event_type.dart';

///Event that happens in player. It can be used to determine current player state
///on higher layer.
class PipFlutterPlayerEvent {
  final PipFlutterPlayerEventType pipFlutterPlayerEventType;
  final Map<String, dynamic>? parameters;

  PipFlutterPlayerEvent(this.pipFlutterPlayerEventType, {this.parameters});
}
