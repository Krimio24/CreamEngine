package funkin.modding;

import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.FlxG;

class ModUtils {
    public static function timer(time:Float, onComplete:Void->Void):FlxTimer {
        return new FlxTimer().start(time, function(_) {
            if (onComplete != null) onComplete();
        });
    }

    /**
     * Lanza un tween en un objeto.
     * options puede contener: { type, ease, startDelay, loopDelay, onComplete, onUpdate }
     */
    public static function tween(object:Dynamic, values:Dynamic, duration:Float, ?options:Dynamic):FlxTween {
        return FlxTween.tween(object, values, duration, options);
    }
}
