package funkin.play.notes;

import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.io.Path;
import openfl.Assets;
#if sys
import openfl.display.BitmapData;
import sys.FileSystem;
import sys.io.File;
#end

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

    function loadSparrowFrames(baseRelPath:String):FlxAtlasFrames {
        var clean = normalizePath(baseRelPath);
        if (clean == "") return null;

        var pngResolved = resolveAssetPath('$clean.png');
        var xmlResolved = resolveAssetPath('$clean.xml');

        if (pngResolved == null || xmlResolved == null) return null;

        #if sys
        if (FileSystem.exists(pngResolved) && FileSystem.exists(xmlResolved)) {
            var bmp = BitmapData.fromFile(pngResolved);
            var xml = File.getContent(xmlResolved);
            if (bmp != null && xml != null) return FlxAtlasFrames.fromSparrow(bmp, xml);
        }
        #end

        if (Assets.exists(pngResolved) && Assets.exists(xmlResolved)) {
            return FlxAtlasFrames.fromSparrow(Assets.getBitmapData(pngResolved), Assets.getText(xmlResolved));
        }

        return null;
    }

    function createReceptors():Void {
        var atlas = loadSparrowFrames('gameplay/notestyles/funkin/note-strumline');

        for (i in 0...4) {
            var receptor = new FlxSprite(xPos + (i * 112), yPos);
            if (atlas != null) {
                receptor.frames = atlas;
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