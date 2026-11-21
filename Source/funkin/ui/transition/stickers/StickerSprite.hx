package funkin.ui.transition.stickers;

import flixel.FlxSprite;

class StickerSprite extends FlxSprite {
	public var timing:Float = 0;

	public function new(x:Float, y:Float, filePath:String):Void {
		super(x, y);
		loadGraphic(filePath);
		updateHitbox();
		scrollFactor.set();
	}
}
