package funkin.play.characters;

import funkin.modding.FunkinModding;
import haxe.Json;
import haxe.io.Path;
import openfl.Assets;
import sys.FileSystem;
import sys.io.File;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;

typedef CharacterAnimation = {
	var name:String;
	var prefix:String;
	@:optional var assetPath:String;
	@:optional var animType:String;
	@:optional var fps:Null<Int>;
	@:optional var looped:Null<Bool>;
	@:optional var frameIndices:Array<Int>;
	@:optional var offsets:Array<Float>;
}

typedef CharacterData = {
	var name:String;
	var assetPath:String;
	@:optional var renderType:String;
	@:optional var singTime:Null<Float>;
	@:optional var offsets:Array<Float>;
	@:optional var cameraOffsets:Array<Float>;
	@:optional var flipX:Null<Bool>;
	@:optional var scale:Null<Float>;
	@:optional var animations:Array<CharacterAnimation>;
}

class Character extends FlxSprite {
	public var curCharacter:String = "bf";
	public var isPlayer:Bool = false;
	public var holdTimer:Float = 0;
	public var singDuration:Float = 4.0;
	public var animOffsets:Map<String, Array<Float>> = new Map();
	public var cameraOffsets:Array<Float> = [0, 0];
	public var charData:CharacterData;

	public function new(x:Float = 0, y:Float = 0, character:String = "bf", isPlayer:Bool = false) {
		super(x, y);

		this.isPlayer = isPlayer;
		loadCharacter(character);
	}

	function normalizePath(path:String):String {
		if (path == null)
			return "";

		path = StringTools.replace(path, "\\", "/");

		while (StringTools.startsWith(path, "/"))
			path = path.substr(1);

		if (StringTools.startsWith(path, "assets/"))
			path = path.substr(7);

		return path;
	}

	function resolveAssetPath(relPath:String):String {
		var clean = normalizePath(relPath);
		if (clean == "")
			return null;

		#if sys
		var modsRoot = "C:/funkin-cream/mods";
		if (FileSystem.exists(modsRoot) && FileSystem.isDirectory(modsRoot)) {
			for (entry in FileSystem.readDirectory(modsRoot)) {
				var modCandidate = Path.join([modsRoot, entry, clean]);
				if (FileSystem.exists(modCandidate))
					return modCandidate;
			}
		}

		var diskAsset = Path.join(["assets", clean]);
		if (FileSystem.exists(diskAsset))
			return diskAsset;

		var progAsset = Path.join([Path.directory(Sys.programPath()), "assets", clean]);
		if (FileSystem.exists(progAsset))
			return progAsset;
		#end

		var openflId = 'assets/$clean';
		if (Assets.exists(openflId))
			return openflId;

		return null;
	}

	function readTextAsset(relPath:String):String {
		var resolved = resolveAssetPath(relPath);
		if (resolved == null)
			return null;

		#if sys
		if (FileSystem.exists(resolved))
			return File.getContent(resolved);
		#end

		if (Assets.exists(resolved))
			return Assets.getText(resolved);

		return null;
	}

	function loadAtlas(path:String):FlxAtlasFrames {
		var clean = normalizePath(path);
		if (clean == "")
			return null;

		var pngResolved = resolveAssetPath('$clean.png');
		var xmlResolved = resolveAssetPath('$clean.xml');

		if (pngResolved == null || xmlResolved == null)
			return null;

		#if sys
		if (FileSystem.exists(pngResolved) && FileSystem.exists(xmlResolved)) {
			var pngData = openfl.display.BitmapData.fromFile(pngResolved);
			var xmlData = File.getContent(xmlResolved);
			if (pngData != null && xmlData != null)
				return FlxAtlasFrames.fromSparrow(pngData, xmlData);
		}
		#end

		if (Assets.exists(pngResolved) && Assets.exists(xmlResolved))
			return FlxAtlasFrames.fromSparrow(Assets.getBitmapData(pngResolved), Assets.getText(xmlResolved));

		return null;
	}

	function resolvePrefix(anim:CharacterAnimation):String {
		var prefix = anim.prefix;

		var aliases:Map<String, String> = [
			"idle" => "BF idle dance",
			"singLEFT" => "BF NOTE LEFT",
			"singDOWN" => "BF NOTE DOWN",
			"singUP" => "BF NOTE UP",
			"singRIGHT" => "BF NOTE RIGHT",
			"singLEFTmiss" => "BF NOTE LEFT MISS",
			"singDOWNmiss" => "BF NOTE DOWN MISS",
			"singUPmiss" => "BF NOTE UP MISS",
			"singRIGHTmiss" => "BF NOTE RIGHT MISS",
			"hey" => "BF HEY!!",
			"firstDeath" => "BF Dead confirm",
			"deathLoop" => "BF Dead Loop",
			"deathConfirm" => "BF Dead confirm"
		];

		if (aliases.exists(anim.name)) {
			var alias = aliases.get(anim.name);

			if (hasPrefix(alias))
				return alias;
		}

		if (hasPrefix(prefix))
			return prefix;

		var boyfriendPrefix = 'BF $prefix';

		if (hasPrefix(boyfriendPrefix))
			return boyfriendPrefix;

		return prefix;
	}

	function hasPrefix(prefix:String):Bool {
		if (frames == null || prefix == null)
			return false;

		for (frame in frames.frames) {
			if (frame.name != null && StringTools.startsWith(frame.name, prefix))
				return true;
		}

		return false;
	}

	public function loadCharacter(char:String):Void {
		curCharacter = char;
		charData = null;
		frames = null;
		animOffsets = new Map();
		cameraOffsets = [0, 0];
		singDuration = 4.0;
		holdTimer = 0;

		var jsonPath = 'gameplay/characters/$char/$char.json';
		var rawJson = readTextAsset(jsonPath);

		if (rawJson == null) {
			trace('Character JSON not found: $jsonPath');
			return;
		}

		try {
			charData = cast Json.parse(rawJson);
		} catch (e:Dynamic) {
			trace('Error parsing character JSON for $char: $e');
			return;
		}

		if (charData == null)
			return;

		if (charData.singTime != null && charData.singTime > 0)
			singDuration = charData.singTime;

		if (charData.cameraOffsets != null && charData.cameraOffsets.length >= 2)
			cameraOffsets = charData.cameraOffsets;

		var basePath = charData.assetPath;

		frames = loadAtlas(basePath);

		if (frames == null)
			frames = loadAtlas('gameplay/characters/$char/$char');

		if (frames == null) {
			trace('Character atlas not found: $char');
			return;
		}

		if (charData.animations != null) {
			for (anim in charData.animations) {
				if (anim.name == null || anim.prefix == null)
					continue;

				if (anim.assetPath != null) {
					var extraAtlas = loadAtlas(anim.assetPath);

					if (extraAtlas != null) {
						var currentAtlas:FlxAtlasFrames = cast frames;
						currentAtlas.addAtlas(extraAtlas);
						frames = currentAtlas;
					} else
						trace('Animation atlas not found: ${anim.assetPath}');
				}

				var prefix = resolvePrefix(anim);

				if (!hasPrefix(prefix)) {
					trace('Animation "${anim.name}" not found. Prefix: "$prefix"');
					continue;
				}

				var animFps:Int = anim.fps != null && anim.fps > 0 ? anim.fps : 24;
				var animLoop:Bool = anim.looped != null ? anim.looped : false;

				if (anim.frameIndices != null && anim.frameIndices.length > 0) {
					animation.addByIndices(anim.name, prefix, anim.frameIndices, "", animFps, animLoop);
				} else {
					animation.addByPrefix(anim.name, prefix, animFps, animLoop);
				}

				if (anim.offsets != null && anim.offsets.length >= 2)
					addOffset(anim.name, anim.offsets[0], anim.offsets[1]);
				else
					addOffset(anim.name);
			}
		}

		if (charData.flipX != null)
			flipX = charData.flipX;

		if (isPlayer)
			flipX = !flipX;

		if (charData.scale != null && charData.scale > 0) {
			setGraphicSize(Std.int(width * charData.scale));
			updateHitbox();
		}

		if (animation.getByName("idle") != null)
			playAnim("idle");
		else
			dance();
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0):Void {
		animOffsets.set(name, [x, y]);
	}

	public function playAnim(animName:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void {
		if (animation.getByName(animName) == null)
			return;

		animation.play(animName, force, reversed, frame);

		var daOffset = animOffsets.get(animName);

		if (daOffset != null)
			offset.set(daOffset[0], daOffset[1]);
		else
			offset.set(0, 0);

		if (StringTools.startsWith(animName, "sing"))
			holdTimer = 0;
	}

	public function dance():Void {
		if (animation.curAnim != null && StringTools.startsWith(animation.curAnim.name, "sing"))
			return;

		if (animation.getByName("danceRight") != null && animation.getByName("danceLeft") != null) {
			var isRight = animation.curAnim != null && animation.curAnim.name == "danceRight";
			playAnim(isRight ? "danceLeft" : "danceRight");
		} else if (animation.getByName("idle") != null) {
			playAnim("idle");
		}
	}

	override public function update(elapsed:Float):Void {
		super.update(elapsed);

		if (animation.curAnim != null && StringTools.startsWith(animation.curAnim.name, "sing")) {
			holdTimer += elapsed;

			if (holdTimer >= singDuration * (1 / 24)) {
				dance();
				holdTimer = 0;
			}
		}
	}
}