# CreamEngine

**CreamEngine** is a rhythm game engine project developed in **Haxe**, built on top of **HaxeFlixel**, **OpenFL**, and **Lime**. Its goal is to provide a custom foundation for creating and running a *Friday Night Funkin'*-style game, with gameplay systems, song loading, characters, stages, mod support, and haptic feedback.

> **Status:** In development. The project structure and several systems are already implemented, but gameplay and some tools are still being worked on. CreamEngine is not considered a stable release.

## Features

- **Rhythm gameplay:** A gameplay foundation with notes, strumlines, characters, scoring, misses, and health.
- **Song system:** Loads JSON charts and metadata, difficulties, and scroll speed.
- **Music conductor:** Tracks song position, beats, steps, measures, and BPM changes; supports immediate changes and tempo transitions.
- **Characters and stages:** Loads JSON data for animations, offsets, positions, and stage properties.
- **Initial mod support:** Detects mod folders containing `mod.json` and resolves overridden assets.
- **Haptics:** Vibration support for mobile devices and compatible controllers, including JSON-based haptic charts.
- **Haptic Chart Editor:** A local HTML tool for creating, editing, previewing, importing, and exporting vibration patterns.
- **Cross-platform targets:** Project configuration for desktop and Android; some features depend on the target platform and its extensions.

## Technologies

| Technology | Purpose |
| --- | --- |
| Haxe | Main programming language |
| HaxeFlixel | Game framework |
| OpenFL | Multimedia and application layer |
| Lime | Build system and platform targets |
| FlxAnimate | Animation support |
| extension-haptics | Android/iOS vibration |
| openfl-ffmpeg | Video decoding on Android |

## Requirements

To build the project, you need:

- [Haxe](https://haxe.org/)
- [HaxeFlixel](https://haxeflixel.com/)
- [Lime](https://lime.openfl.org/)
- Android Studio and the Android SDK/NDK if you plan to build for Android.

Install the Haxe libraries used by the project:

```bash
haxelib install lime
haxelib install openfl
haxelib install flixel
haxelib install flixel-addons
haxelib install flxanimate
haxelib install openfl-ffmpeg
haxelib install extension-haptics
```

The last two dependencies are used by the Android/mobile target, depending on the conditions in `project.xml`. Then, configure Lime:

```bash
haxelib run lime setup
```

## Getting the source

```bash
git clone https://github.com/Krimio24/CreamEngine.git
cd CreamEngine
```

## Building and running

The project configuration is located in `project.xml`. The initial window size is **1280 × 720**.

To run the project on Windows:

```bash
lime test windows
```

To build Android in debug mode:

```bash
lime build android -debug
```

To create an Android release build:

```bash
lime build android -release
```

The repository also includes `build-android-debug.bat` and `build-android.bat` scripts for Windows. These expect a local Android Studio, Java, and Android NDK installation; check the paths configured in the scripts and your environment before running them.

## Project structure

```text
CreamEngine/
├── Source/
│   ├── Main.hx
│   └── funkin/
│       ├── Conductor.hx
│       ├── modding/
│       ├── play/
│       │   ├── characters/
│       │   ├── notes/
│       │   ├── song/
│       │   └── stage/
│       ├── sprites/
│       ├── ui/
│       └── util/
├── assets/
│   ├── gameplay/
│   │   ├── characters/
│   │   ├── dialogue/
│   │   ├── songs/
│   │   └── stages/
│   └── ui/
├── tools/
│   ├── android/
│   └── HapticChartEditor.html
├── project.xml
├── build-android-debug.bat
└── build-android.bat
```

## Haptic charts

CreamEngine includes `tools/HapticChartEditor.html`. Open it directly in a modern browser; no installation or local server is required.

The editor allows you to:

- Set BPM, measures, subdivisions, and time signature.
- Load an audio or video file as a timing reference.
- Place, move, and edit pulses on a timeline.
- Configure duration and intensity for the left and right motors.
- Import and export JSON charts.
- Test vibration with a compatible gamepad and a browser that supports the vibration API.

Exported charts use events with the `atMs`, `durationMs`, `left`, and `right` fields. The runtime can play them using `HapticUtil.playChart()` or `HapticUtil.playChartFromJson()`.

## Mods

The initial mod system scans folders inside `mods/`. Each mod must include a `mod.json` file containing its metadata.

Example:

```json
{
  "id": "my-mod",
  "name": "My Mod",
  "author": "Author",
  "description": "A custom mod",
  "version": "1.0.0"
}
```

Mod assets can be placed inside the mod's `assets/` directory so the asset resolver can find overridden files.

> Mod support is still in its early stages and may vary depending on the target platform. Not every feature of a complete modding system has been implemented.

## Credits and assets

CreamEngine uses HaxeFlixel, OpenFL, Lime, and other open-source tools. The repository also contains project assets from **Friday Night Funkin'** and **The Funkin' Crew**.

Credits and usage terms for each asset belong to their respective authors. Before redistributing builds or assets, review the applicable licenses and terms. CreamEngine is not officially affiliated with The Funkin' Crew.

## License

No license for CreamEngine is specified in this README. Check the repository files and the notices accompanying individual assets before reusing or redistributing the code or assets.
