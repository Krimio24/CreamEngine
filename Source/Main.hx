package;

import funkin.ui.mainmenu.MainMenuState;
import flixel.FlxG;
import flixel.FlxGame;
import openfl.display.Sprite;
import funkin.ui.FunkinSoundTray;
import funkin.ui.title.TitleState;

class Main extends Sprite {
	var game:FlxGame;

	public function new() {
		super();

		game = new FlxGame(1280, 720, TitleState, 90, 90, true, false);

		@:privateAccess
		game._customSoundTray = FunkinSoundTray;

		addChild(game);
	}

	static function main():Void {
		openfl.Lib.current.addChild(new Main());
	}
}
