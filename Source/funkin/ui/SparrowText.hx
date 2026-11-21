package funkin.ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.utils.Assets;

/** Renders animated text using the bold Sparrow glyph atlas. */
class SparrowText extends FlxSpriteGroup {
	static var boldFrames:FlxAtlasFrames;
	static var boldFramesAttempted:Bool = false;
	static inline var LETTER_SPACING:Float = 2;
	static inline var SPACE_WIDTH:Float = 28;

	public var textWidth(default, null):Float = 0;

	public function new(text:String, y:Float, scale:Float = 0.48, color:FlxColor = FlxColor.WHITE) {
		super(0, y);
		var atlas = getBoldFrames();
		if (atlas == null) {
			addFallbackText(text, scale, color);
			return;
		}
		var normalized = text.toUpperCase();
		var measured = measure(normalized, atlas, scale);
		if (measured.height <= 0) {
			addFallbackText(text, scale, color);
			return;
		}
		textWidth = measured.width;
		x = (FlxG.width - textWidth) * 0.5;

		var cursor:Float = 0;
		for (index in 0...normalized.length) {
			var char = normalized.charAt(index);
			var prefix = prefixFor(char);
			if (prefix == null) {
				cursor += SPACE_WIDTH * scale;
				continue;
			}

			var firstFrame = safeGetFrame(atlas, prefix + "0000");
			if (firstFrame == null || firstFrame.frame == null) continue;

			var glyphHeight = firstFrame.sourceSize != null ? firstFrame.sourceSize.y : firstFrame.frame.height;
			var glyph = new FlxSprite(cursor, (measured.height - glyphHeight) * scale);
			glyph.frames = atlas;
			glyph.animation.addByPrefix("idle", prefix, 24, true);
			glyph.animation.play("idle", true, false, FlxG.random.int(0, 3));
			glyph.scale.set(scale, scale);
			glyph.color = color;
			glyph.updateHitbox();
			glyph.antialiasing = true;
			add(glyph);

			cursor += firstFrame.frame.width * scale + LETTER_SPACING * scale;
		}
	}

	static function getBoldFrames():FlxAtlasFrames {
		if (boldFrames == null && !boldFramesAttempted) {
			boldFramesAttempted = true;
			var imagePath = "assets/ui/fonts/bold.png";
			var xmlPath = "assets/ui/fonts/bold.xml";
			if (!Assets.exists(imagePath) || !Assets.exists(xmlPath)) return null;
			try {
				boldFrames = FlxAtlasFrames.fromSparrow(imagePath, xmlPath);
			} catch (error:Dynamic) {
				trace('Could not load the animated title font: $error');
				return null;
			}
		}
		return boldFrames;
	}

	function addFallbackText(text:String, scale:Float, color:FlxColor):Void {
		textWidth = FlxG.width;
		var fallback = new FlxText(0, 0, FlxG.width, text, Std.int(68 * scale));
		fallback.alignment = "center";
		fallback.color = color;
		fallback.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		add(fallback);
	}

	static function safeGetFrame(atlas:FlxAtlasFrames, name:String):FlxFrame {
		if (atlas == null) return null;
		try {
			return atlas.getByName(name);
		} catch (error:Dynamic) {
			return null;
		}
	}

	static function measure(text:String, atlas:FlxAtlasFrames, scale:Float):{width:Float, height:Float} {
		var width:Float = 0;
		var height:Float = 0;
		var visibleGlyphs = 0;
		if (atlas == null) return {width: FlxG.width, height: 0};
		for (index in 0...text.length) {
			var prefix = prefixFor(text.charAt(index));
			if (prefix == null) {
				width += SPACE_WIDTH * scale;
				continue;
			}
			var frame = safeGetFrame(atlas, prefix + "0000");
			if (frame == null || frame.frame == null) continue;
			width += frame.frame.width * scale;
			height = Math.max(height, frame.sourceSize != null ? frame.sourceSize.y : frame.frame.height);
			visibleGlyphs++;
		}
		if (visibleGlyphs > 1) width += (visibleGlyphs - 1) * LETTER_SPACING * scale;
		return {width: width, height: height};
	}

	static function prefixFor(char:String):Null<String> {
		if (char >= "A" && char <= "Z") return char;
		return switch (char) {
			case " ": null;
			case ".": "-period-";
			case ",": "-comma-";
			case "!": "-exclamation point-";
			case "?": "-question mark-";
			case "-": "-dash-";
			case "'", "’": "-apostraphie-";
			case "&": "-andpersand-";
			case "/": "-forward slash-";
			case "\\": "-back slash-";
			case "<": "-less than-";
			case ">": "-greater than-";
			case "\"": "-start quote-";
			case "@", "*", "#", "%", "^", "+", "=", "|", "~", "$", "(", ")", "[", "]", ":", ";", "_": char;
			case _: null;
		};
	}
}
