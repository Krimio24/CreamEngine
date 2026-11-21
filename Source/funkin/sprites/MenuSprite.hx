package funkin.sprites;

import flixel.addons.display.FlxBackdrop;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;

class MenuSprite extends FlxTypedSpriteGroup<FlxSprite> {

    var bg:FlxSprite;
    var pattern:FlxBackdrop;

    public function new() {
        super();
        bg = new FlxSprite();
        bg.loadGraphic("assets/ui/main-menu/menu-bg.png");
        bg.screenCenter();

        pattern = new FlxBackdrop();
    }
}