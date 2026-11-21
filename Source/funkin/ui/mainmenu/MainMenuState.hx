package funkin.ui.mainmenu;

import funkin.ui.title.TitleState;
import flixel.input.gamepad.FlxGamepad;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.FlxState;
import flixel.FlxCamera;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.effects.FlxFlicker;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import funkin.util.HapticUtil;
import funkin.ui.story.StoryMenuState;

class MainMenuState extends FlxState {
	static var rememberedSelectedIndex:Int = 0;

	var items:FlxTypedGroup<FlxSprite>;
	var selectedIndex:Int = 0;
	var canInteract:Bool = true;

	var bg:FlxSprite;
	var magenta:FlxSprite;
	var camFollow:FlxObject;

	var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

	var itemNames:Array<String> = ["story-mode", "freeplay", "options", "credits"];

	var itemCallbacks:Array<Void->Void> = [];

	override public function create():Void {
		super.create();

		FlxG.cameras.reset(new FlxCamera());

		bg = new FlxSprite();
		bg.loadGraphic("assets/ui/main-menu/menu-bg.png");
		bg.scrollFactor.set(0.17, 0.17);
		bg.setGraphicSize(Std.int(FlxG.width * 1.2));
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		magenta = new FlxSprite();
		magenta.loadGraphic("assets/ui/main-menu/menu-bg-magenta.png");
		magenta.scrollFactor.copyFrom(bg.scrollFactor);
		magenta.setGraphicSize(Std.int(bg.width));
		magenta.updateHitbox();
		magenta.setPosition(bg.x, bg.y);
		magenta.visible = false;
		add(magenta);

		camFollow = new FlxObject();
		add(camFollow);

		items = new FlxTypedGroup<FlxSprite>();
		add(items);

		itemCallbacks = [
			() -> FlxG.switchState(() -> new StoryMenuState()),
			() -> FlxG.switchState(() -> new StoryMenuState()),
			() -> FlxG.switchState(() -> new StoryMenuState()),
			() -> FlxG.switchState(() -> new StoryMenuState())
		];

		var spacing:Float = 160;
		var top:Float = (FlxG.height - spacing * (itemNames.length - 1)) / 2;

		for (i in 0...itemNames.length) {
			var name = itemNames[i];

			var item = new FlxSprite();

			item.frames = FlxAtlasFrames.fromSparrow('assets/ui/main-menu/items/$name.png', 'assets/ui/main-menu/items/$name.xml');

			item.animation.addByPrefix("idle", '$name idle', 24, true);
			item.animation.addByPrefix("selected", '$name selected', 24, true);

			item.animation.play("idle");
			item.centerOrigin();

			item.ID = i;
			item.scrollFactor.set(0, 0.4);
			item.x = FlxG.width / 2;
			item.y = top + spacing * i - 100;

			items.add(item);

			if (i == 1)
				camFollow.setPosition(item.x, item.y);
		}

		selectItem(rememberedSelectedIndex);
		resetCamera();
	}

	function selectItem(index:Int):Void {
		if (items.length == 0)
			return;

		selectedIndex = (index + items.length) % items.length;
		rememberedSelectedIndex = selectedIndex;

		for (i in 0...items.length) {
			var item = items.members[i];

			if (item == null)
				continue;

			item.animation.play(i == selectedIndex ? "selected" : "idle");
		}

		var selected = items.members[selectedIndex];

		camFollow.setPosition(selected.x, selected.y);
	}

	function resetCamera():Void {
		FlxG.camera.follow(camFollow, null, 0.06);
		FlxG.camera.snapToTarget();
	}

	function acceptSelection():Void {
		if (!canInteract)
			return;

		canInteract = false;

		FlxFlicker.flicker(magenta, 1.1, 0.15, false, true);

		HapticUtil.vibrateFor(0, 1, 1, 40);

		var selected = items.members[selectedIndex];

		FlxFlicker.flicker(selected, 0.8, 0.06, false, true, function(_) {
			startExitState(itemCallbacks[selectedIndex]);
		});
	}

	function startExitState(callback:Void->Void):Void {
		for (i in 0...items.length) {
			var item = items.members[i];

			if (item == null)
				continue;

			if (i != selectedIndex) {
				FlxTween.tween(item, {alpha: 0}, 0.4, {
					ease: FlxEase.quadOut
				});
			} else {
				item.visible = false;
			}
		}

		new FlxTimer().start(0.4, function(_) {
			callback();
		});
	}

	override public function update(elapsed:Float):Void {
		super.update(elapsed);

		if (!canInteract)
			return;

		var up:Bool = FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W;
		var down:Bool = FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S;
		var accept:Bool = FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE;
		var back:Bool = FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE;

		up = up || gamepad.justPressed.DPAD_UP || gamepad.justPressed.LEFT_STICK_DIGITAL_UP;
		down = down || gamepad.justPressed.DPAD_DOWN || gamepad.justPressed.LEFT_STICK_DIGITAL_DOWN;

		accept = accept || gamepad.justPressed.A;
		back = back || gamepad.justPressed.B;

		if (up) {
			selectItem(selectedIndex - 1);
			HapticUtil.vibrateFor(0, 1, 1, 20);
		} else if (down) {
			selectItem(selectedIndex + 1);
			HapticUtil.vibrateFor(0, 1, 1, 20);
		}

		if (accept)
			acceptSelection();

		if (back)
			FlxG.switchState(() -> new TitleState());
	}
}
