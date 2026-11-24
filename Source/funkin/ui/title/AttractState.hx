package funkin.ui.title;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.Conductor;
import funkin.util.HapticUtil;
import funkin.util.VideoUtil;
import funkin.util.ScreenDimmer;
import openfl.utils.Assets;
import haxe.io.Path;
import lime.system.System;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/** Plays one of the title trailers after the title screen has been idle. */
class AttractState extends FlxState {
	static final VIDEOS:Array<String> = [
		"assets/ui/title/attract/rift-collab-trailer.mp4",
		"assets/ui/title/attract/mobile-release.mp4",
		"assets/ui/title/attract/boyfriend-everywhere.mp4"
	];
	static final HAPTIC_CHARTS:Array<String> = [
		"assets/ui/title/attract/riftcolab-haptics.json",
		"assets/ui/title/attract/mobile-build-haptics.json",
		"assets/ui/title/attract/bf-everywhere-haptics.json"
	];
	static var nextVideo:Int = 0;
	static inline var HOLD_TO_SKIP_SECONDS:Float = 1.5;

	#if ((cpp && windows) || android)
	var videoSprite:FlxSprite;
	#end
	var skipPrompt:FlxText;
	var holdTime:Float = 0;
	var finished:Bool = false;

	override public function create():Void {
		super.create();
		Conductor.instance.onBeatHit = null;
		Conductor.instance.stop();
		FlxG.camera.bgColor = FlxColor.BLACK;
		FlxG.mouse.visible = false;

		#if android
		playNextAndroidVideo();
		#elseif (cpp && windows)
		playNextVideo();
		#else
		new flixel.util.FlxTimer().start(0.1, function(_) returnToTitle());
		#end

		skipPrompt = new FlxText(0, FlxG.height - 54, FlxG.width, "Hold any key to skip", 20);
		skipPrompt.alignment = "center";
		skipPrompt.color = FlxColor.BLACK;
		skipPrompt.alpha = 0.7;
		skipPrompt.font = "funkin-options";
		add(skipPrompt);
	}

	#if (cpp && windows)
	function playNextVideo():Void {
		var index = nextVideo;
		var assetPath = VIDEOS[index];
		nextVideo = (nextVideo + 1) % VIDEOS.length;
		var path = Assets.getPath(assetPath);
		if (path == null) path = assetPath;
		startVideo(path, HAPTIC_CHARTS[index]);
	}
	#end

	#if android
	function playNextAndroidVideo():Void {
		var index = nextVideo;
		var assetPath = VIDEOS[index];
		nextVideo = (nextVideo + 1) % VIDEOS.length;
		var path = Path.join([System.applicationStorageDirectory, Path.withoutDirectory(assetPath)]);
		try {
			if (!FileSystem.exists(path)) File.saveBytes(path, Assets.getBytes(assetPath));
		} catch (error:Dynamic) {
			trace('Could not copy attract video to app storage: $error');
			returnToTitle();
			return;
		}
		startVideo(path, HAPTIC_CHARTS[index]);
	}
	#end

	#if ((cpp && windows) || android)
	function startVideo(path:String, hapticChartPath:String):Void {
		videoSprite = new VideoUtil().createVideo(path, () -> returnToTitle(false));
		if (videoSprite == null) {
			trace('Could not play attract video "$path"');
			returnToTitle(false);
			return;
		}
		videoSprite.setGraphicSize(FlxG.width, FlxG.height);
		videoSprite.updateHitbox();
		videoSprite.screenCenter();
		videoSprite.antialiasing = true;
		add(videoSprite);
		if (!HapticUtil.playChart(hapticChartPath))
			trace('Could not play attract haptic chart "$hapticChartPath"');
	}
	#end

	override public function update(elapsed:Float):Void {
		super.update(elapsed);
		if (FlxG.keys.justPressed.ESCAPE) {
			returnToTitle(true);
			return;
		}
		if (FlxG.keys.pressed.ANY) {
			holdTime += elapsed;
			skipPrompt.alpha = 1;
		} else {
			holdTime = Math.max(0, holdTime - elapsed * 2);
			skipPrompt.alpha = 0.5;
		}
		if (holdTime >= HOLD_TO_SKIP_SECONDS) returnToTitle(true);
	}

	function returnToTitle(skipped:Bool = false):Void {
		if (finished) return;
		finished = true;
		HapticUtil.stopChart();
		#if ((cpp && windows) || android)
		if (videoSprite != null) {
			remove(videoSprite, true);
			videoSprite.destroy();
			videoSprite = null;
		}
		#end
		#if (cpp && windows)
		var window = openfl.Lib.application.window;
		if (window != null) {
			window.fullscreen = false;
			FlxG.fullscreen = false;
			var display = window.display;
			var targetY:Int = (display != null) ? Std.int(display.bounds.y + display.bounds.height + 60) : 1200;
			var currentX:Int = (TitleState.savedWindowX >= 0) ? TitleState.savedWindowX : ((display != null) ? Std.int(display.bounds.x + (display.bounds.width - window.width) / 2) : 100);
			window.move(currentX, targetY);
			TitleState.startSlideUp = true;
		}
		#end
		FlxG.switchState(() -> new TitleState());
	}
}
