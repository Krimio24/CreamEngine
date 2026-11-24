package funkin.ui.story;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
import funkin.play.PlayState;
import funkin.ui.mainmenu.MainMenuState;

typedef LevelData = {
    var name:String;
    var songs:Array<String>;
    @:optional var background:String;
    @:optional var chars:Array<String>;
}

class StoryMenuState extends FlxState {


    override public function create():Void {
        super.create();

    }

}
