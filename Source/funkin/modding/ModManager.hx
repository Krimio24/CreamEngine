package funkin.modding;

import haxe.Json;
import openfl.utils.Assets;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef ModMetadata = {
    var id:String;
    var name:String;
    @:optional var author:String;
    @:optional var description:String;
    @:optional var version:String;
    @:optional var path:String;
}

class ModManager {
    public static var activeMods:Array<ModMetadata> = [];
    public static var modsPath:String = "mods";

    public static function init():Void {
        activeMods = [];
        #if sys
        // Revisar carpetas de mods (en root del juego y escritorio si está configurado)
        var searchPaths:Array<String> = [modsPath, "mods/"];
        for (p in searchPaths) {
            if (FileSystem.exists(p) && FileSystem.isDirectory(p)) {
                for (dir in FileSystem.readDirectory(p)) {
                    var fullDir = '$p/$dir';
                    if (FileSystem.isDirectory(fullDir)) {
                        loadModFromDir(fullDir, dir);
                    }
                }
            }
        }
        #end
    }

    public static function loadModFromDir(dirPath:String, modId:String):Void {
        #if sys
        var jsonFile = '$dirPath/mod.json';
        if (FileSystem.exists(jsonFile)) {
            try {
                var content = File.getContent(jsonFile);
                var meta:ModMetadata = Json.parse(content);
                meta.id = modId;
                meta.path = dirPath;
                activeMods.push(meta);
                trace('Loaded Mod: ${meta.name} by ${meta.author} ($dirPath)');
            } catch (e:Dynamic) {
                trace('Error loading mod from $jsonFile: $e');
            }
        }
        #end
    }

    /**
     * Busca un asset considerando la sobreescritura de mods activos.
     */
    public static function getAssetPath(path:String):String {
        #if sys
        for (mod in activeMods) {
            if (mod.path != null) {
                var modAsset = '${mod.path}/assets/$path';
                if (FileSystem.exists(modAsset))
                    return modAsset;
                var directModAsset = '${mod.path}/$path';
                if (FileSystem.exists(directModAsset))
                    return directModAsset;
            }
        }
        #end
        return 'assets/$path';
    }

    public static function getContent(path:String):Null<String> {
        var assetPath = getAssetPath(path);
        #if sys
        if (FileSystem.exists(assetPath))
            return File.getContent(assetPath);
        #end
        if (Assets.exists(assetPath))
            return Assets.getText(assetPath);
        if (Assets.exists(path))
            return Assets.getText(path);
        return null;
    }

    public static function exists(path:String):Bool {
        var assetPath = getAssetPath(path);
        #if sys
        if (FileSystem.exists(assetPath)) return true;
        #end
        return Assets.exists(assetPath) || Assets.exists(path);
    }
}
