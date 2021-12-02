///Internal events of PipFlutterPlayerController, used in widgets to update state.
enum PipFlutterPlayerControllerEvent {
  ///Fullscreen mode has started.
  openFullscreen,

  ///Fullscreen mode has ended.
  hideFullscreen,

  ///Subtitles changed.
  changeSubtitles,

  ///New data source has been set.
  setupDataSource,

  //Video has started.
  play
}
