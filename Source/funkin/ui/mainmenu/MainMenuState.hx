package funkin.ui.mainmenu;

import funkin.ui.title.TitleState;
import funkin.ui.story.StoryMenuState;
import flixel.input.gamepad.FlxGamepad;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxCamera;
import flixel.text.FlxText;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.effects.FlxFlicker;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import funkin.util.HapticUtil;
import funkin.Conductor;

/**
 * Main Menu State recreated faithfully from Figma "TV - 1" design (Page 1).
 * Features a circular wheel menu layout on the left, custom backdrop, indicator arrow,
 * and animated menu options.
 */
class MainMenuState extends FlxState {
	static var rememberedSelectedIndex:Int = 0;

	var bg:FlxSprite;
	var magenta:FlxSprite;
	var arrow:FlxSprite;
	var versionText:FlxText;

	var items:FlxTypedGroup<FlxSprite>;
	var itemTweens:Array<FlxTween> = [];
	var arrowTween:FlxTween;

	var selectedIndex:Int = 0;
	var canInteract:Bool = true;

	var itemNames:Array<String> = ["story-mode", "freeplay", "options", "merch"];
	var itemCallbacks:Array<Void->Void> = [];

	override public function create():Void {
		super.create();

		FlxG.cameras.reset(new FlxCamera());

		if (FlxG.sound.music == null || !FlxG.sound.music.playing) {
			var music = Conductor.instance.play("assets/ui/main-menu/freaky-menu", "freaky-menu");
			if (music != null) music.fadeIn(2, 0, 1);
		}

		// Background from Figma TV-1
		bg = new FlxSprite(0, 0);
		bg.loadGraphic("assets/ui/main-menu/menu-bg.png");
		bg.setGraphicSize(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.antialiasing = true;
		add(bg);

		// Magenta flash effect
		magenta = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xFFFD719B);
		magenta.alpha = 0.35;
		magenta.visible = false;
		add(magenta);

		// Items Group
		items = new FlxTypedGroup<FlxSprite>();
		add(items);

		itemCallbacks = [
			() -> FlxG.switchState(() -> new StoryMenuState()),
			() -> FlxG.switchState(() -> new StoryMenuState()), // Will route to FreeplayState next
			() -> FlxG.switchState(() -> new StoryMenuState()), // Will route to OptionsState
			() -> FlxG.openURL("https://ninja-muffin24.itch.io/funkin")
		];

		for (i in 0...itemNames.length) {
			var name = itemNames[i];
			var item = new FlxSprite();
			item.frames = FlxAtlasFrames.fromSparrow('assets/ui/main-menu/items/$name.png', 'assets/ui/main-menu/items/$name.xml');
			item.animation.addByPrefix("idle", '$name idle', 24, true);
			item.animation.addByPrefix("selected", '$name selected', 24, true);
			item.animation.play("idle");
			item.antialiasing = true;
			item.ID = i;
			items.add(item);
			itemTweens.push(null);
		}

		// Selector Arrow from Figma
		arrow = new FlxSprite(84, 142);
		arrow.loadGraphic("assets/ui/main-menu/figma/arrow.png");
		arrow.setGraphicSize(Std.int(arrow.width * 0.7));
		arrow.updateHitbox();
		arrow.antialiasing = true;
		add(arrow);

		// Version text from Figma TV-1
		versionText = new FlxText(FlxG.width - 260, FlxG.height - 28, 250, "Better FNF 1.0", 16);
		versionText.alignment = "right";
		versionText.color = FlxColor.BLACK;
		versionText.font = "assets/ui/fonts/5by7.otf";
		add(versionText);

		selectItem(rememberedSelectedIndex, true);
	}

	function getItemTargetTransform(index:Int):{ x:Float, y:Float, angle:Float, scale:Float, alpha:Float } {
		var diff = index - selectedIndex;
		// Wrap around diff for cyclic wheel
		var count = itemNames.length;
		while (diff > count / 2) diff -= count;
		while (diff < -count / 2) diff += count;

		switch (diff) {
			case 0:
				// Selected item (horizontal, adjacent to arrow)
				return { x: 180, y: 150, angle: 0, scale: 0.72, alpha: 1.0 };
			case 1:
				// First item below
				return { x: 135, y: 350, angle: 8, scale: 0.62, alpha: 0.85 };
			case 2:
				// Second item below
				return { x: 45, y: 495, angle: 20, scale: 0.54, alpha: 0.65 };
			case -1:
				// Item above
				return { x: -35, y: -20, angle: -24, scale: 0.62, alpha: 0.7 };
			case -2:
				// Item further above
				return { x: -95, y: -160, angle: -48, scale: 0.5, alpha: 0.4 };
			default:
				if (diff > 0)
					return { x: -40, y: 620, angle: 36, scale: 0.45, alpha: 0.35 };
				else
					return { x: -140, y: -260, angle: -65, scale: 0.45, alpha: 0.35 };
		}
	}

	function selectItem(index:Int, immediate:Bool = false):Void {
		if (items.length == 0) return;

		selectedIndex = (index + items.length) % items.length;
		rememberedSelectedIndex = selectedIndex;

		if (!immediate) {
			FlxG.sound.play("assets/ui/main-menu/scroll-menu.ogg");
			HapticUtil.vibrateFor(0, 0.5, 0.5, 20);

			// Arrow bounce effect
			if (arrowTween != null) arrowTween.cancel();
			arrow.scale.set(0.85, 0.85);
			arrowTween = FlxTween.tween(arrow.scale, { x: 0.7, y: 0.7 }, 0.2, { ease: FlxEase.backOut });
		}

		for (i in 0...items.length) {
			var item = items.members[i];
			if (item == null) continue;

			var isSelected = (i == selectedIndex);
			item.animation.play(isSelected ? "selected" : "idle");

			var target = getItemTargetTransform(i);

			if (immediate) {
				item.setPosition(target.x, target.y);
				item.angle = target.angle;
				item.scale.set(target.scale, target.scale);
				item.alpha = target.alpha;
			} else {
				if (itemTweens[i] != null) itemTweens[i].cancel();
				itemTweens[i] = FlxTween.tween(item, {
					x: target.x,
					y: target.y,
					angle: target.angle,
					alpha: target.alpha,
					"scale.x": target.scale,
					"scale.y": target.scale
				}, 0.28, { ease: FlxEase.quadOut });
			}
		}
	}

	function acceptSelection():Void {
		if (!canInteract) return;
		canInteract = false;

		FlxG.sound.play("assets/ui/main-menu/confirm-menu.ogg");
		HapticUtil.vibrateFor(0, 1, 1, 40);

		magenta.visible = true;
		FlxFlicker.flicker(magenta, 1.1, 0.15, false, true);

		var selected = items.members[selectedIndex];
		if (selected != null) {
			FlxFlicker.flicker(selected, 0.8, 0.06, false, true, function(_) {
				startExitState(itemCallbacks[selectedIndex]);
			});
		} else {
			startExitState(itemCallbacks[selectedIndex]);
		}
	}

	function startExitState(callback:Void->Void):Void {
		for (i in 0...items.length) {
			var item = items.members[i];
			if (item == null) continue;

			if (i != selectedIndex) {
				FlxTween.tween(item, { alpha: 0, x: item.x - 100 }, 0.35, { ease: FlxEase.quadIn });
			}
		}
		if (arrow != null) {
			FlxTween.tween(arrow, { alpha: 0, x: arrow.x - 60 }, 0.35, { ease: FlxEase.quadIn });
		}

		new FlxTimer().start(0.4, function(_) {
			if (callback != null) callback();
		});
	}

	override public function update(elapsed:Float):Void {
		super.update(elapsed);

		if (!canInteract) return;

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

		var up:Bool = FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W;
		var down:Bool = FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S;
		var accept:Bool = (FlxG.keys.justPressed.ENTER && !FlxG.keys.pressed.ALT) || FlxG.keys.justPressed.SPACE;
		var back:Bool = FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE;

		if (gamepad != null) {
			up = up || gamepad.justPressed.DPAD_UP || gamepad.justPressed.LEFT_STICK_DIGITAL_UP;
			down = down || gamepad.justPressed.DPAD_DOWN || gamepad.justPressed.LEFT_STICK_DIGITAL_DOWN;
			accept = accept || gamepad.justPressed.A;
			back = back || gamepad.justPressed.B;
		}

		if (up) {
			selectItem(selectedIndex - 1);
		} else if (down) {
			selectItem(selectedIndex + 1);
		}

		if (accept) {
			acceptSelection();
		} else if (back) {
			FlxG.sound.play("assets/ui/main-menu/cancel-menu.ogg");
			FlxG.switchState(() -> new TitleState());
		}
	}
}
