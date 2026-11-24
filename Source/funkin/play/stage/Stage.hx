package funkin.play.stage;

import flixel.group.FlxGroup;
import flixel.FlxSprite;
import haxe.Json;
import haxe.io.Path;
import openfl.Assets;
#if sys
import openfl.display.BitmapData;
import sys.FileSystem;
import sys.io.File;
#end

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

    function normalizePath(path:String):String {
        if (path == null) return "";
        path = StringTools.replace(path, "\\", "/");
        while (StringTools.startsWith(path, "/")) path = path.substr(1);
        if (StringTools.startsWith(path, "assets/")) path = path.substr(7);
        return path;
    }

    function resolveAssetPath(relPath:String):String {
        var clean = normalizePath(relPath);
        if (clean == "") return null;

        #if sys
        var modsRoot = "C:/funkin-cream/mods";
        if (FileSystem.exists(modsRoot) && FileSystem.isDirectory(modsRoot)) {
            for (entry in FileSystem.readDirectory(modsRoot)) {
                var modCandidate = Path.join([modsRoot, entry, clean]);
                if (FileSystem.exists(modCandidate)) return modCandidate;
            }
        }

        var diskAsset = Path.join(["assets", clean]);
        if (FileSystem.exists(diskAsset)) return diskAsset;

        var progAsset = Path.join([Path.directory(Sys.programPath()), "assets", clean]);
        if (FileSystem.exists(progAsset)) return progAsset;
        #end

        var openflId = 'assets/$clean';
        if (Assets.exists(openflId)) return openflId;

        return null;
    }

    function readTextAsset(relPath:String):String {
        var resolved = resolveAssetPath(relPath);
        if (resolved == null) return null;

        #if sys
        if (FileSystem.exists(resolved)) return File.getContent(resolved);
        #end

        if (Assets.exists(resolved)) return Assets.getText(resolved);

        return null;
    }

    function applyGraphic(spr:FlxSprite, pngRelPath:String):Void {
        var resolved = resolveAssetPath(pngRelPath);
        if (resolved == null) return;

        #if sys
        if (FileSystem.exists(resolved)) {
            var bmp = BitmapData.fromFile(resolved);
            if (bmp != null) {
                spr.loadGraphic(bmp);
                return;
            }
        }
        #end

        if (Assets.exists(resolved)) {
            spr.loadGraphic(Assets.getBitmapData(resolved));
        }
    }

    public function loadStage(stageName:String):Void {
        var rawJson = readTextAsset('gameplay/stages/$stageName/$stageName.json');
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
                    applyGraphic(spr, '${prop.assetPath}.png');
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