package funkin.ui.title;

import funkin.ui.mainmenu.MainMenuState;
import flixel.tweens.FlxTween;
import funkin.util.HapticUtil;
import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.system.scaleModes.FillScaleMode;
import funkin.Conductor;
import funkin.ui.title.AttractState;
import openfl.utils.Assets;

/** Title screen adapted to the assets and APIs available in CreamEngine. */
class TitleState extends FlxState {
	public static var initialized:Bool = false;
	public static var onStart:Void->Void;

	var logo:FlxSprite;
	var girlfriend:FlxSprite;
	var prompt:FlxSprite;
	var newgroundsLogo:FlxSprite;
	var introCover:FlxSprite;
	var creditTexts:Array<FlxText> = [];
	var introLines:Array<String> = [];
	var wackyText:Array<String> = ["Friday", "Night Funkin"];
	var lastIntroBeat:Int = 0;
	var danceLeft:Bool = false;
	var skippedIntro:Bool = false;
	var introStarted:Bool = false;
	var transitioning:Bool = false;
	var promptTime:Float = 0;
	var attractTimer:FlxTimer;

	override public function create():Void {
		super.create();
		FlxG.scaleMode = new FillScaleMode();

		var background = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		background.scrollFactor.set();
		add(background);

		Conductor.instance.onBeatHit = onBeatHit;
		introLines = loadIntroLines();
		if (introLines.length > 0) {
			var randomLine = FlxG.random.getObject(introLines);
			wackyText = randomLine.split("--");
			if (wackyText.length < 2) wackyText = [randomLine, "Friday Night Funkin"];
		}

		if (initialized) {
			startIntro();
		} else {
			new FlxTimer().start(1, function(_:FlxTimer) startIntro());
		}
	}

	function startIntro():Void {
		if (introStarted) return;
		introStarted = true;

		if (Conductor.instance.music == null) {
			var music = Conductor.instance.play("assets/ui/main-menu/freaky-menu", "freaky-menu");
			if (music != null) music.fadeIn(4, 0, 1);
		}

		persistentUpdate = true;

		logo = new FlxSprite(-150, -100);
		logo.frames = FlxAtlasFrames.fromSparrow(
			"assets/ui/title/logo-bumpin.png",
			"assets/ui/title/logo-bumpin.xml"
		);
		logo.animation.addByPrefix("bump", "logo bumpin", 24, false);
		logo.animation.play("bump");
		logo.updateHitbox();
		add(logo);

		girlfriend = new FlxSprite(FlxG.width * 0.4, FlxG.height * 0.07);
		girlfriend.frames = FlxAtlasFrames.fromSparrow(
			"assets/ui/title/gf-dance-title.png",
			"assets/ui/title/gf-dance-title.xml"
		);
		girlfriend.animation.addByIndices("danceLeft", "gfDance", [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
		girlfriend.animation.addByIndices("danceRight", "gfDance", [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
		girlfriend.animation.play("danceLeft");
		add(girlfriend);

		var promptScale = 0.48;
		prompt = new FlxSprite((FlxG.width - 1480 * promptScale) * 0.5, FlxG.height * 0.82);
		prompt.frames = loadPromptFrames();
		prompt.animation.add("idle", [0, 1, 2, 3], 8, true);
		prompt.animation.play("idle");
		prompt.scale.set(promptScale, promptScale);
		add(prompt);

		introCover = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		introCover.scrollFactor.set();
		add(introCover);

		newgroundsLogo = new FlxSprite(0, FlxG.height * 0.52);
		newgroundsLogo.loadGraphic("assets/ui/title/newgrounds-logo.png");
		newgroundsLogo.setGraphicSize(Std.int(newgroundsLogo.width * 0.8));
		newgroundsLogo.updateHitbox();
		newgroundsLogo.screenCenter(X);
		newgroundsLogo.visible = false;
		add(newgroundsLogo);

		lastIntroBeat = Conductor.instance.curBeat;
		if (initialized) skipIntro();
		else initialized = true;

		#if (cpp && windows)
		attractTimer = new FlxTimer().start(37.5, function(_:FlxTimer) moveToAttract());
		#end
	}

	override public function update(elapsed:Float):Void {
		super.update(elapsed);
		promptTime += elapsed;
		if (prompt != null && skippedIntro) {
			prompt.alpha = 0.55 + 0.45 * Math.sin(promptTime * 3.2);
		}

		if (FlxG.keys.justPressed.ESCAPE) {
			openfl.Lib.application.window.close();
			return;
		}

		if (FlxG.keys.justPressed.ENTER && introStarted) {
			if (!skippedIntro) {
				skipIntro();
			} else if (!transitioning && onStart != null) {
				transitioning = true;
				FlxG.switchState(() -> new MainMenuState());
				#if (cpp && windows)
				if (attractTimer != null) attractTimer.cancel();
				#end
				if (prompt != null) prompt.animation.play("idle", true);
				FlxG.camera.flash(FlxColor.WHITE, 0.5);
				new FlxTimer().start(0.5, function(_:FlxTimer) onStart());
			}
		}
	}

	function moveToAttract():Void {
		if (transitioning || !introStarted) return;
		transitioning = true;
		if (FlxG.sound.music != null) FlxG.sound.music.fadeOut(2, 0);
		FlxTween.tween(FlxG.camera, { y: FlxG.camera.y - 500 }, 2);
		FlxG.camera.fade(FlxColor.BLACK, 2, false, function() {
			FlxG.switchState(() -> new AttractState());
		});
	}

	function onBeatHit(beat:Int):Void {
		if (!introStarted) return;

		if (!skippedIntro) {
			for (currentBeat in (lastIntroBeat + 1)...(beat + 1)) {
				switch (currentBeat) {
					case 1: showCredits(["The", "Funkin Crew Inc"]);
					case 3: addCredit("presents");
					case 4: clearCredits();
					case 5: showCredits(["In association", "with"]);
					case 7:
						addCredit("newgrounds");
						if (newgroundsLogo != null) newgroundsLogo.visible = true;
					case 8:
						clearCredits();
						if (newgroundsLogo != null) newgroundsLogo.visible = false;
					case 9: showCredits([wackyText[0]]);
					case 11: addCredit(wackyText[1]);
					case 12: clearCredits();
					case 13: addCredit("Friday");
					case 14: addCredit("Night");
					case 15: addCredit("Funkin");
					case 16: skipIntro();
				}
			}
			lastIntroBeat = beat;
		}

		if (skippedIntro) {
			if (logo != null) logo.animation.play("bump", true);
			danceLeft = !danceLeft;
			if (girlfriend != null) girlfriend.animation.play(danceLeft ? "danceRight" : "danceLeft");
		}
	}

	function showCredits(lines:Array<String>):Void {
		clearCredits();
		for (line in lines) addCredit(line);
		HapticUtil.vibrateFor(0, 0.2, 0.2, 100);
	}

	function addCredit(value:String):Void {
		var text = new FlxText(0, 190 + creditTexts.length * 60, FlxG.width, value, 48);
		text.alignment = "center";
		text.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		creditTexts.push(text);
		add(text);
		HapticUtil.vibrateFor(0, 0.1, 0.1, 100);
	}

	function loadPromptFrames():FlxAtlasFrames {
		var atlasPath = "assets/ui/title/title-screen-text";
		var atlas:Dynamic = haxe.Json.parse(Assets.getText(atlasPath + "/spritemap1.json"));
		var frames = new FlxAtlasFrames(FlxG.bitmap.add(atlasPath + "/spritemap1.png"));
		var sprites:Array<Dynamic> = cast atlas.ATLAS.SPRITES;
		for (entry in sprites) {
			var sprite = entry.SPRITE;
			frames.addAtlasFrame(
				FlxRect.get(sprite.x, sprite.y, sprite.w, sprite.h),
				FlxPoint.get(sprite.w, sprite.h),
				FlxPoint.get(),
				Std.string(sprite.name)
			);
		}
		return frames;
	}

	function clearCredits():Void {
		for (text in creditTexts) {
			remove(text, true);
			text.destroy();
		}
		creditTexts = [];
	}

	function skipIntro():Void {
		if (skippedIntro) return;
		skippedIntro = true;
		clearCredits();
		if (newgroundsLogo != null) {
			remove(newgroundsLogo, true);
			newgroundsLogo.destroy();
			newgroundsLogo = null;
		}
		if (introCover != null) {
			remove(introCover, true);
			introCover.destroy();
			introCover = null;
		}
		FlxG.camera.flash(FlxColor.WHITE, 1);
	}

	function loadIntroLines():Array<String> {
		var path = "assets/ui/title/intro-text.txt";
		if (!Assets.exists(path)) return [];
		return Assets.getText(path).split("\n").map(function(line) return StringTools.trim(line)).filter(function(line) return line != "");
	}

	override public function destroy():Void {
		if (attractTimer != null) attractTimer.cancel();
		Conductor.instance.onBeatHit = null;
		super.destroy();
	}
}
