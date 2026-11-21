package funkin.play.stage;

import flixel.group.FlxGroup;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.Json;
import funkin.modding.ModManager;

typedef StageProp = {
    var name:String;
    var assetPath:String;
    var position:Array<Float>;
    @:optional var scale:Array<Float>;
    @:optional var scroll:Array<Float>;
    @:optional var zIndex:Null<Int>;
}

typedef StageData = {
    var name:String;
    @:optional var cameraZoom:Null<Float>;
    @:optional var props:Array<StageProp>;
    @:optional var characters:Dynamic;
}

class Stage extends FlxGroup {
    public var stageData:StageData;
    public var defaultZoom:Float = 1.05;

    public var bfPos:Array<Float> = [770, 450];
    public var dadPos:Array<Float> = [100, 100];
    public var gfPos:Array<Float> = [400, 130];

    public function new(stageName:String = "mainStage") {
        super();
        loadStage(stageName);
    }

    public function loadStage(stageName:String):Void {
        var rawJson = ModManager.getContent('gameplay/stages/$stageName/$stageName.json');
        if (rawJson != null) {
            try {
                stageData = Json.parse(rawJson);
            } catch (e:Dynamic) {
                trace('Error parsing stage $stageName: $e');
            }
        }

        if (stageData != null) {
            if (stageData.cameraZoom != null)
                defaultZoom = stageData.cameraZoom;

            if (stageData.characters != null) {
                if (stageData.characters.bf != null && stageData.characters.bf.position != null)
                    bfPos = stageData.characters.bf.position;
                if (stageData.characters.dad != null && stageData.characters.dad.position != null)
                    dadPos = stageData.characters.dad.position;
                if (stageData.characters.gf != null && stageData.characters.gf.position != null)
                    gfPos = stageData.characters.gf.position;
            }

            if (stageData.props != null) {
                for (prop in stageData.props) {
                    var spr = new FlxSprite(prop.position[0], prop.position[1]);
                    var pngPath = ModManager.getAssetPath('assets/${prop.assetPath}.png');
                    if (ModManager.exists(pngPath)) {
                        spr.loadGraphic(pngPath);
                    }
                    if (prop.scroll != null) {
                        spr.scrollFactor.set(prop.scroll[0], prop.scroll[1]);
                    }
                    if (prop.scale != null) {
                        spr.scale.set(prop.scale[0], prop.scale[1]);
                        spr.updateHitbox();
                    }
                    add(spr);
                }
            }
        }
    }
}
