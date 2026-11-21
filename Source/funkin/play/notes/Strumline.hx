package funkin.play.notes;

import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import funkin.modding.ModManager;

class Strumline extends FlxTypedGroup<FlxSprite> {
    public var receptors:Array<FlxSprite> = [];
    public var xPos:Float = 0;
    public var yPos:Float = 50;

    public function new(x:Float, y:Float = 50) {
        super();
        this.xPos = x;
        this.yPos = y;
        createReceptors();
    }

    function createReceptors():Void {
        var strumPng = ModManager.getAssetPath('assets/gameplay/notestyles/funkin/note-strumline.png');
        var strumXml = ModManager.getAssetPath('assets/gameplay/notestyles/funkin/note-strumline.xml');

        for (i in 0...4) {
            var receptor = new FlxSprite(xPos + (i * 112), yPos);
            if (ModManager.exists(strumPng) && ModManager.exists(strumXml)) {
                receptor.frames = FlxAtlasFrames.fromSparrow(strumPng, strumXml);
            }

            var dir:String = switch (i) {
                case 0: "left";
                case 1: "down";
                case 2: "up";
                case 3: "right";
                default: "left";
            };

            receptor.animation.addByPrefix("static", 'arrow' + dir.toUpperCase());
            receptor.animation.addByPrefix("pressed", dir + ' press', 24, false);
            receptor.animation.addByPrefix("confirm", dir + ' confirm', 24, false);

            receptor.animation.play("static");
            receptor.setGraphicSize(Std.int(receptor.width * 0.7));
            receptor.updateHitbox();
            receptor.scrollFactor.set();

            receptors.push(receptor);
            add(receptor);
        }
    }

    public function playPress(direction:Int):Void {
        if (direction >= 0 && direction < receptors.length) {
            receptors[direction].animation.play("pressed", true);
            receptors[direction].centerOffsets();
        }
    }

    public function playConfirm(direction:Int):Void {
        if (direction >= 0 && direction < receptors.length) {
            receptors[direction].animation.play("confirm", true);
            receptors[direction].centerOffsets();
        }
    }

    public function playStatic(direction:Int):Void {
        if (direction >= 0 && direction < receptors.length) {
            receptors[direction].animation.play("static", true);
            receptors[direction].centerOffsets();
        }
    }
}
