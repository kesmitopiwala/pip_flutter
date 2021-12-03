# pip_flutter

A Flutter plugin for Android for make video in picture in picture mode.

![](https://github.com/kesmitopiwala/pip_flutter/blob/master/assets/pictureinpicturevideo.gif)

<br>

# Picture in Picture Mode Flutter
<br>

<br>

| Picture in Picture Mode                                                                                    | Disable Picture in Picture Mode                                                                                      |
| -------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| ![](https://github.com/kesmitopiwala/pip_flutter/blob/master/assets/pipmode.png) | ![](https://github.com/kesmitopiwala/pip_flutter/blob/master/assets/disablepipmode.png) |

<br>


A flutter package pip flutter which will help to put your video in pip mode.

## Features 💚

- Put your video in Picture in Picture mode.
- Also mute sound and play and pause the video.
- Make video in full screen mode,set play back speed of video

## Installation

First, add `pip_flutter` as a [dependency in your pubspec.yaml file](https://flutter.dev/using-packages/).

##  Android

Add below permission in your AndroidManifest.xml file ,also specified picture in picture mode in your activity tag and add foreground service for when 
app is not in background that time app not kill and running in foregorund and also add update code of MainActivity.kt and add PipFlutterPlayerService.

```
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    
    <activity
            android:name=".MainActivity"
            android:supportsPictureInPicture="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize"
            android:exported="true"/>
            
    <service
           android:name=".PipFlutterPlayerService"
           android:stopWithTask="false" />
```

## How to use

- PipFlutterPlayerConfiguration : Put this class for your video configuration.
```Dart
PipFlutterPlayerConfiguration pipFlutterPlayerConfiguration =
const PipFlutterPlayerConfiguration(
  aspectRatio: 16 / 9,
  fit: BoxFit.contain,
);
```

- PipFlutterPlayerDataSource : Put this class for declare your video type url
and url.
```Dart
PipFlutterPlayerDataSource dataSource = PipFlutterPlayerDataSource(
  PipFlutterPlayerDataSourceType.network,
  'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
);
```
- PipFlutterPlayer : 
```Dart
PipFlutterPlayer(
controller: pipFlutterPlayerController,
key: pipFlutterPlayerKey,
),
```

- Make your video in Pip mode put this code on your onTap.
```Dart
pipFlutterPlayerController.enablePictureInPicture(pipFlutterPlayerKey);
```

- And make your video in disable mode put this code on your onTap.
```Dart
pipFlutterPlayerController.disablePictureInPicture();
```

Run the example app in the exmaple folder to find out more about how to use it.





