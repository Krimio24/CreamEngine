package funkin.play.characters;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.Json;
import openfl.utils.Assets;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
import funkin.modding.ModManager;

typedef CharacterAnimation = {
    var name:String;
    var prefix:String;
    @:optional var fps:Null<Int>;
    @:optional var looped:Null<Bool>;
    @:optional var frameIndices:Array<Int>;
    @:optional var offsets:Array<Float>;
}

typedef CharacterData = {
    var name:String;
    var assetPath:String;
    @:optional var renderType:String;
    @:optional var singTime:Null<Float>;
    @:optional var offsets:Array<Float>;
    @:optional var cameraOffsets:Array<Float>;
    @:optional var flipX:Null<Bool>;
    @:optional var scale:Null<Float>;
    @:optional var animations:Array<CharacterAnimation>;
}

class Character extends FlxSprite {
    public var curCharacter:String = "bf";
    public var isPlayer:Bool = false;
    public var holdTimer:Float = 0;
    public var singDuration:Float = 4.0;
    public var animOffsets:Map<String, Array<Float>> = new Map();
    public var cameraOffsets:Array<Float> = [0, 0];
    public var charData:CharacterData;

    public function new(x:Float = 0, y:Float = 0, character:String = "bf", isPlayer:Bool = false) {
        super(x, y);
        this.isPlayer = isPlayer;
        this.curCharacter = character;
        loadCharacter(character);
    }

    public function loadCharacter(char:String):Void {
        this.curCharacter = char;
        animOffsets = new Map();

        var jsonPath = 'gameplay/characters/$char/$char.json';
        var rawJson:Null<String> = ModManager.getContent(jsonPath);
        if (rawJson == null) {
            rawJson = ModManager.getContent('assets/$jsonPath');
        }

        if (rawJson != null) {
            try {
                charData = Json.parse(rawJson);
            } catch (e:Dynamic) {
                trace('Error parsing character json for $char: $e');
            }
        }

        if (charData != null) {
            if (charData.singTime != null)
                singDuration = charData.singTime;

            if (charData.cameraOffsets != null)
                cameraOffsets = charData.cameraOffsets;

            // Spritesheet Sparrow vs MultiAtlas
            var sparrowPng = ModManager.getAssetPath('assets/${charData.assetPath}.png');
            var sparrowXml = ModManager.getAssetPath('assets/${charData.assetPath}.xml');

            // Si no existe con assetPath directo, probar en su carpeta
            if (!ModManager.exists('assets/${charData.assetPath}.png')) {
                sparrowPng = ModManager.getAssetPath('assets/gameplay/characters/$char/$char.png');
                sparrowXml = ModManager.getAssetPath('assets/gameplay/characters/$char/$char.xml');
            }

            if (ModManager.exists(sparrowPng) && ModManager.exists(sparrowXml)) {
                frames = FlxAtlasFrames.fromSparrow(sparrowPng, sparrowXml);
            }

            if (charData.animations != null) {
                for (anim in charData.animations) {
                    var animFps:Int = (anim.fps != null) ? anim.fps : 24;
                    var animLoop:Bool = (anim.looped != null) ? anim.looped : false;

                    if (anim.frameIndices != null && anim.frameIndices.length > 0) {
                        animation.addByIndices(anim.name, anim.prefix, anim.frameIndices, "", animFps, animLoop);
                    } else {
                        animation.addByPrefix(anim.name, anim.prefix, animFps, animLoop);
                    }

                    if (anim.offsets != null) {
                        addOffset(anim.name, anim.offsets[0], anim.offsets[1]);
                    } else {
                        addOffset(anim.name, 0, 0);
                    }
                }
            }

            if (charData.flipX != null) {
                flipX = charData.flipX;
            }

            if (isPlayer) {
                flipX = !flipX;
            }

            if (charData.scale != null) {
                setGraphicSize(Std.int(width * charData.scale));
                updateHitbox();
            }
        }

        playAnim("idle");
    }

    public function addOffset(name:String, x:Float = 0, y:Float = 0):Void {
        animOffsets.set(name, [x, y]);
    }

    public function playAnim(animName:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void {
        animation.play(animName, force, reversed, frame);

        if (animOffsets.exists(animName)) {
            var daOffset = animOffsets.get(animName);
            offset.set(daOffset[0], daOffset[1]);
        } else {
            offset.set(0, 0);
        }
    }

    public function dance():Void {
        if (animation.curAnim == null || !StringTools.startsWith(animation.curAnim.name, "sing")) {
            if (animation.getByName("danceRight") != null && animation.getByName("danceLeft") != null) {
                var isRight = (animation.curAnim != null && animation.curAnim.name == "danceRight");
                playAnim(isRight ? "danceLeft" : "danceRight");
            } else if (animation.getByName("idle") != null) {
                playAnim("idle");
            }
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (animation.curAnim != null && StringTools.startsWith(animation.curAnim.name, "sing")) {
            holdTimer += elapsed;
            if (holdTimer >= (singDuration * (1 / 24))) {
                dance();
                holdTimer = 0;
            }
        }
    }
}
