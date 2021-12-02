import 'package:flutter/material.dart';
import 'package:pip_flutter/pipflutter_player_controller.dart';

///Widget which is used to inherit PipFlutterPlayerController through widget tree.
class PipFlutterPlayerControllerProvider extends InheritedWidget {
  const PipFlutterPlayerControllerProvider({
    Key? key,
    required this.controller,
    required Widget child,
  }) : super(key: key, child: child);

  final PipFlutterPlayerController controller;

  @override
  bool updateShouldNotify(PipFlutterPlayerControllerProvider old) =>
      controller != old.controller;
}
