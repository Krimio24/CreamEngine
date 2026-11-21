package funkin.ui.transition.stickers;

import funkin.util.HapticUtil;
import flixel.FlxG;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.util.FlxTimer;
import flixel.util.FlxSort;

class StickerSpriteGroup extends FlxTypedGroup<StickerSprite>
{
    public var stickerPaths:Array<String>;
    public var duration:Float = 0.9;

    public function new(stickerPaths:Array<String>)
    {
        super();

        this.stickerPaths = stickerPaths;
    }

    public function show(?onComplete:Void->Void):Void
    {
        clear();

        var xPos:Float = -100;
        var yPos:Float = -100;

        while (xPos <= FlxG.width)
        {
            var path = FlxG.random.getObject(stickerPaths);
            var sticker = new StickerSprite(0, 0, path);

            sticker.visible = false;
            sticker.x = xPos;
            sticker.y = yPos;
            sticker.angle = FlxG.random.int(-60, 70);
            
            add(sticker);

            xPos += sticker.frameWidth * 0.5;

            if (xPos >= FlxG.width)
            {
                xPos = -100;
                yPos += FlxG.random.float(70, 120);
            }
        }

        FlxG.random.shuffle(members);

        var centerPath = FlxG.random.getObject(stickerPaths);
        var centerSticker = new StickerSprite(0, 0, centerPath);

        centerSticker.visible = false;
        centerSticker.angle = 0;
        centerSticker.screenCenter();

        add(centerSticker);

        var total = members.length;
        var remaining = total;

        for (i in 0...total)
        {
            var sticker = members[i];

            if (sticker == null) continue;

            sticker.timing = FlxMath.remapToRange(i, 0, total, 0, duration);

            new FlxTimer().start(sticker.timing, function(_)
            {
                if (sticker == null) return;

                sticker.visible = true;

                var frameTimer = FlxG.random.int(0, 2);

                if (i == total - 1)
                    frameTimer = 2;

                new FlxTimer().start((1 / 24) * frameTimer, function(_)
                {
                    sticker.scale.set(
                        FlxG.random.float(0.97, 1.02),
                        FlxG.random.float(0.97, 1.02)
                    );

                    HapticUtil.vibrateFor(0, 0.1, 0.1, 100);
                    
                    remaining--;

                    if (remaining <= 0 && onComplete != null)
                        onComplete();
                });
            });
        }

        sort(function(order, a, b)
        {
            return FlxSort.byValues(order, a.timing, b.timing);
        });
    }

    public function hide(?onComplete:Void->Void):Void
    {
        var total = members.length;
        var remaining = total;

        if (total == 0)
        {
            if (onComplete != null) onComplete();
            return;
        }

        for (i in 0...total)
        {
            var sticker = members[i];

            if (sticker == null) continue;

            new FlxTimer().start(sticker.timing, function(_)
            {
                sticker.visible = false;

                remaining--;

                if (remaining <= 0 && onComplete != null)
                    onComplete();
            });
        }
    }
}
