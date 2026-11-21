package funkin.ui;

import flixel.system.FlxAssets.FlxSoundAsset;
import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.system.ui.FlxSoundTray;
import openfl.display.Bitmap;
import openfl.Assets;

class FunkinSoundTray extends FlxSoundTray {
	var graphicScale:Float = 0.30;
	var lerpYPos:Float = 0;
	var alphaTarget:Float = 0;
	var volumeMaxSound:FlxSoundAsset;

	var hideDelay:Float = 1.0;
	var animationSpeed:Float = 60.0;

	public function new() {
		super();
		removeChildren();

		var bg:Bitmap = new Bitmap(Assets.getBitmapData("assets/ui/soundtray/volume-box.png"));
		bg.scaleX = graphicScale;
		bg.scaleY = graphicScale;
		bg.smoothing = true;
		addChild(bg);

		_bars = [];

		var backingBar:Bitmap = new Bitmap(Assets.getBitmapData("assets/ui/soundtray/bars-10.png"));
		backingBar.x = 9;
		backingBar.y = 5;
		backingBar.scaleX = graphicScale;
		backingBar.scaleY = graphicScale;
		backingBar.smoothing = true;
		backingBar.alpha = 0.4;
		addChild(backingBar);

		for (i in 1...11) {
            var bar:Bitmap;
            if (i != 10)
			bar = new Bitmap(Assets.getBitmapData("assets/ui/soundtray/bars-" + 0 + i + ".png"));
            else bar = new Bitmap(Assets.getBitmapData("assets/ui/soundtray/bars-" + i + ".png"));

			bar.x = 9;
			bar.y = 5;
			bar.scaleX = graphicScale;
			bar.scaleY = graphicScale;
			bar.smoothing = true;

			addChild(bar);
			_bars.push(bar);
		}

		volumeUpSound = "assets/ui/soundtray/volume-up.ogg";
		volumeDownSound = "assets/ui/soundtray/volume-down.ogg";
		volumeMaxSound = "assets/ui/soundtray/volume-max.ogg";

		screenCenter();

		y = -height - 10;
		lerpYPos = y;
		alpha = 0;
		alphaTarget = 0;

		visible = false;
		active = false;
	}

	override public function update(ms:Float):Void {
		var elapsed:Float = ms / 1000;

		if (_timer > 0) {
			_timer -= elapsed;

			if (_timer <= 0) {
				_timer = 0;
				lerpYPos = -height - 10;
				alphaTarget = 0;
			}
		}

		var ratioY:Float = 1 - Math.pow(1 - 0.768, elapsed * 60);
		var ratioAlpha:Float = 1 - Math.pow(1 - 0.307, elapsed * 60);

		y = FlxMath.lerp(y, lerpYPos, ratioY);
		alpha = FlxMath.lerp(alpha, alphaTarget, ratioAlpha);

		if (_timer <= 0 && alpha <= 0.01 && y <= -height) {
			y = -height - 10;
			alpha = 0;
			visible = false;
			active = false;
		}
	}

	override function showIncrement():Void {
		moveTrayMakeVisible(true);
		saveVolumePreferences();
	}

	override function showDecrement():Void {
		moveTrayMakeVisible(false);
		saveVolumePreferences();
	}

	function moveTrayMakeVisible(up:Bool = false):Void {
		showTray();

		if (!silent) {
			if (FlxG.sound.volume >= 1)
				FlxG.sound.play(volumeMaxSound);
			else if (up)
				FlxG.sound.play(volumeUpSound);
			else
				FlxG.sound.play(volumeDownSound);
		}
	}

	function showTray():Void {
		_timer = hideDelay;
		lerpYPos = 10;

		visible = true;
		active = true;
		alphaTarget = 1;

		updateBars();
	}

	function updateBars():Void {
		var globalVolume:Int = FlxG.sound.muted ? 0 : Math.round(FlxG.sound.volume * 10);

		globalVolume = Std.int(Math.max(0, Math.min(10, globalVolume)));

		for (i in 0..._bars.length)
			_bars[i].visible = i < globalVolume;
	}

	function saveVolumePreferences():Void {
		#if FLX_SAVE
		if (FlxG.save.isBound) {
			FlxG.save.data.mute = FlxG.sound.muted;
			FlxG.save.data.volume = FlxG.sound.volume;
			FlxG.save.flush();
		}
		#end
	}
}
