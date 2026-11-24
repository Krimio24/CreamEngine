package funkin.modding;

import funkin.modding.ModMain;
import funkin.modding.FunkinServer;
import funkin.modding.backend.QuickJSBackend;
import funkin.modding.backend.LuaBackend;
import funkin.modding.ModState;
import sys.io.File;
import haxe.Json;
import sys.FileSystem;
import haxe.io.Path;
import StringTools;

import funkin.Conductor;
import funkin.play.PlayState;
import funkin.play.characters.Character;
import funkin.play.notes.Note;
import funkin.play.notes.Strumline;
import funkin.play.song.Song;
import funkin.play.stage.Stage;
import funkin.sprites.MenuSprite;
import funkin.ui.FunkinSoundTray;
import funkin.ui.SparrowText;
import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.story.StoryMenuState;
import funkin.ui.title.AttractState;
import funkin.ui.title.TitleState;
import funkin.util.HapticUtil;
import funkin.util.VideoUtil;

class Mod
{
    public var name:String;
    public var author:String;
    public var desc:String;
    public var path:String;
    public var mainLocation:String;
    public var scriptType:String; // "ts", "js", "lua"

    public function new() {}
}

class FunkinModding
{
    public static final TARGET_MODS_ROOT:String = "C:/funkin-cream";
    public static final TARGET_MODS_DIR:String = "C:/funkin-cream/mods";

    public var modsLoaded:Array<Mod>;
    var serverStarted:Bool = false;
    static var exitHandlersRegistered:Bool = false;

    public function new()
    {
        modsLoaded = [];
    }

    public function init():Void
    {
        modsLoaded = [];

        #if sys
        registerExitHandlers();

        // 1. Wipe any leftover C:/funkin-cream directory so we always start completely clean
        cleanCreamDirectory();

        // 2. Re-create the target directory structure
        ensureDirectory(TARGET_MODS_DIR);

        // 3. Copy TypeScript definitions and proxy to C:/funkin-cream/mods
        var tsSourceDir:String = Path.join([
            Path.directory(Sys.programPath()),
            "assets",
            "funkin-ts"
        ]);

        if (!FileSystem.exists(tsSourceDir))
        {
            tsSourceDir = Path.join([
                Sys.getCwd(),
                "assets",
                "funkin-ts"
            ]);
        }

        if (FileSystem.exists(tsSourceDir) && FileSystem.isDirectory(tsSourceDir))
        {
            copyDirectoryRecursive(tsSourceDir, TARGET_MODS_DIR);
        }

        // 4. Discover and copy mods
        discoverAndCopyMods();

        // 5. Start TCP RPC server & register engine classes
        createServer();

        // 6. Hook frame updates to drain both QuickJS and Lua callbacks
        flixel.FlxG.signals.postUpdate.add(function() {
            #if sys
            QuickJSBackend.drainCallbacks();
            LuaBackend.drainCallbacks();
            FunkinServer.update();
            #end
        });

        // 7. Load all discovered mods
        loadAllMods();
        #end
    }

    function registerExitHandlers():Void
    {
        if (exitHandlersRegistered)
            return;

        exitHandlersRegistered = true;

        #if (lime && openfl)
        if (lime.app.Application.current != null)
        {
            lime.app.Application.current.onExit.add(function(exitCode:Int) {
                shutdown();
            });

            if (lime.app.Application.current.window != null)
            {
                lime.app.Application.current.window.onClose.add(function() {
                    shutdown();
                });
            }
        }
        if (openfl.Lib.application != null)
        {
            openfl.Lib.application.onExit.add(function(exitCode:Int) {
                shutdown();
            });

            if (openfl.Lib.application.window != null)
            {
                openfl.Lib.application.window.onClose.add(function() {
                    shutdown();
                });
            }
        }
        #end
    }

    public static function cleanCreamDirectory():Void
    {
        #if sys
        if (!FileSystem.exists(TARGET_MODS_ROOT))
            return;

        trace("FunkinModding: Cleaning " + TARGET_MODS_ROOT);
        try
        {
            deleteDirectoryRecursive(TARGET_MODS_ROOT);
        }
        catch (e:Dynamic)
        {
            trace("FunkinModding: error deleting directory: " + e);
        }

        if (FileSystem.exists(TARGET_MODS_ROOT))
        {
            try
            {
                #if (windows && sys)
                Sys.command("cmd.exe", ["/c", "rd", "/s", "/q", "C:\\funkin-cream"]);
                #end
            }
            catch (e:Dynamic) {}
        }
        #end
    }

    function discoverAndCopyMods():Void
    {
        #if sys
        var copiedFolders:Array<String> = [];

        // A. Copy mods only from the engine's "mods" folder (if it exists)
        var searchRoots:Array<String> = [
            Path.join([Path.directory(Sys.programPath()), "mods"]),
            Path.join([Sys.getCwd(), "mods"])
        ];

        for (root in searchRoots)
        {
            if (FileSystem.exists(root) && FileSystem.isDirectory(root))
            {
                for (entry in FileSystem.readDirectory(root))
                {
                    var modPath = Path.join([root, entry]);
                    var modJson = Path.join([modPath, "mod.json"]);

                    // ONLY copy if it is a directory AND contains mod.json
                    if (FileSystem.isDirectory(modPath) && FileSystem.exists(modJson))
                    {
                        if (copiedFolders.indexOf(entry) == -1)
                        {
                            copiedFolders.push(entry);
                            copyDirectoryRecursive(modPath, Path.join([TARGET_MODS_DIR, entry]));
                        }
                    }
                }
            }
        }

        // B. Check user's mod folder: C:/Users/krist/OneDrive/Escritorio/Kristian/mod
        var userModDir:String = "C:/Users/krist/OneDrive/Escritorio/Kristian/mod";
        if (FileSystem.exists(userModDir) && FileSystem.isDirectory(userModDir) && FileSystem.exists(Path.join([userModDir, "mod.json"])))
        {
            var destName = "mimod";
            if (copiedFolders.indexOf(destName) == -1)
            {
                copiedFolders.push(destName);
                copyDirectoryRecursive(userModDir, Path.join([TARGET_MODS_DIR, destName]));
            }
        }
        #end
    }

    function loadAllMods():Void
    {
        #if sys
        if (!FileSystem.exists(TARGET_MODS_DIR) || !FileSystem.isDirectory(TARGET_MODS_DIR))
            return;

        for (name in FileSystem.readDirectory(TARGET_MODS_DIR))
        {
            // Skip engine internal runtime folders
            if (name == "src" || name == "runtime" || name == "node_modules")
                continue;

            var modFolder:String = Path.normalize(Path.join([TARGET_MODS_DIR, name]));
            var modJson:String = Path.join([modFolder, "mod.json"]);

            // MUST be a directory and MUST contain mod.json
            if (FileSystem.isDirectory(modFolder) && FileSystem.exists(modJson))
            {
                try
                {
                    loadMod(modFolder);
                }
                catch (e:Dynamic)
                {
                    trace('Error loading mod at $modFolder: $e');
                }
            }
        }
        #end
    }

    public static function ensureDirectory(dirPath:String):Void
    {
        #if sys
        if (dirPath == null || dirPath == "")
            return;

        var normalized:String = Path.normalize(dirPath);
        if (FileSystem.exists(normalized))
            return;

        var parent:String = Path.directory(normalized);
        if (parent != null && parent != "" && parent != normalized && !FileSystem.exists(parent))
        {
            ensureDirectory(parent);
        }

        if (!FileSystem.exists(normalized))
            FileSystem.createDirectory(normalized);
        #end
    }

    public static function copyDirectoryRecursive(srcDir:String, dstDir:String):Void
    {
        #if sys
        ensureDirectory(dstDir);

        for (entry in FileSystem.readDirectory(srcDir))
        {
            var srcPath:String = Path.join([srcDir, entry]);
            var dstPath:String = Path.join([dstDir, entry]);

            if (FileSystem.isDirectory(srcPath))
            {
                copyDirectoryRecursive(srcPath, dstPath);
            }
            else
            {
                File.copy(srcPath, dstPath);
            }
        }
        #end
    }

    public static function deleteDirectoryRecursive(dirPath:String):Void
    {
        #if sys
        if (!FileSystem.exists(dirPath))
            return;

        if (FileSystem.isDirectory(dirPath))
        {
            for (entry in FileSystem.readDirectory(dirPath))
            {
                deleteDirectoryRecursive(Path.join([dirPath, entry]));
            }
            FileSystem.deleteDirectory(dirPath);
        }
        else
        {
            FileSystem.deleteFile(dirPath);
        }
        #end
    }

    function resolveMainScriptPath(modFolder:String, mainField:String):String
    {
        #if sys
        if (mainField == null || StringTools.trim(mainField) == "")
            return null;

        var cleanedMain:String = StringTools.replace(StringTools.trim(mainField), "\\", "/");

        while (StringTools.startsWith(cleanedMain, "./"))
            cleanedMain = cleanedMain.substr(2);

        while (StringTools.startsWith(cleanedMain, "/"))
            cleanedMain = cleanedMain.substr(1);

        var normalizedModFolder:String = Path.normalize(modFolder);
        var fullScriptPath:String = Path.normalize(Path.join([normalizedModFolder, cleanedMain]));

        if (FileSystem.exists(fullScriptPath) && !FileSystem.isDirectory(fullScriptPath))
        {
            return fullScriptPath;
        }

        return null;
        #else
        return null;
        #end
    }

    function loadMod(modPath:String):Void
    {
        #if sys
        var normalizedModPath:String = Path.normalize(modPath);
        var modJsonPath:String = Path.join([normalizedModPath, "mod.json"]);

        trace("Loading Mod: " + normalizedModPath);

        var data:Dynamic = null;
        if (FileSystem.exists(modJsonPath))
        {
            try
            {
                data = Json.parse(File.getContent(modJsonPath));
            }
            catch (e:Dynamic)
            {
                trace("Invalid mod.json in " + normalizedModPath + ": " + e);
            }
        }

        var mainRel:String = null;
        if (data != null)
        {
            if (data.mainLocation != null) mainRel = data.mainLocation;
            else if (data.main != null) mainRel = data.main;
            else if (data.script != null) mainRel = data.script;
        }

        if (mainRel == null || StringTools.trim(mainRel) == "")
        {
            var candidates = [
                "src/Main.ts", "src/main.ts", "Main.ts", "main.ts",
                "src/main.lua", "src/script.lua", "main.lua", "script.lua", "init.lua",
                "src/index.js", "src/main.js", "index.js", "main.js"
            ];

            for (c in candidates)
            {
                if (FileSystem.exists(Path.join([normalizedModPath, c])))
                {
                    mainRel = c;
                    break;
                }
            }
        }

        var mainScriptPath:String = resolveMainScriptPath(normalizedModPath, mainRel);

        if (mainScriptPath == null)
        {
            trace("Main script not found for mod at: " + normalizedModPath + " (" + mainRel + ")");
            return;
        }

        var mod:Mod = new Mod();
        mod.name = (data != null && data.name != null) ? data.name : Path.withoutDirectory(normalizedModPath);
        mod.author = (data != null && data.author != null) ? data.author : "Unknown";
        mod.desc = (data != null && data.desc != null) ? data.desc : "";
        mod.path = normalizedModPath;
        mod.mainLocation = mainScriptPath;

        var ext:String = Path.extension(mainScriptPath).toLowerCase();
        mod.scriptType = ext;

        var ok:Bool = false;

        #if cpp
        switch (ext)
        {
            case "ts":
                if (!QuickJSBackend.initialize())
                {
                    trace("QuickJSBackend: failed to initialize.");
                    return;
                }
                var src:String = File.getContent(mainScriptPath);
                ok = QuickJSBackend.executeTypeScript(src, mainScriptPath);
                if (ok)
                    QuickJSBackend.drainCallbacks();

            case "js", "mjs":
                if (!QuickJSBackend.initialize())
                {
                    trace("QuickJSBackend: failed to initialize.");
                    return;
                }
                ok = QuickJSBackend.loadFile(mainScriptPath);
                if (ok)
                    QuickJSBackend.drainCallbacks();

            case "lua":
                if (!LuaBackend.initialize())
                {
                    trace("LuaBackend: failed to initialize.");
                    return;
                }
                ok = LuaBackend.loadFile(mainScriptPath);
                if (ok)
                    LuaBackend.drainCallbacks();

            default:
                trace("Unsupported mod script extension: " + ext);
                return;
        }

        if (!ok)
        {
            trace('Script execution failed for $mainScriptPath');
            return;
        }
        #elseif js
        if (ext == "js" || ext == "mjs")
        {
            var src:String = File.getContent(mainScriptPath);
            QuickJSBackend.execute(src, mainScriptPath);
        }
        #end

        modsLoaded.push(mod);
        trace("Mod loaded successfully: " + mod.name + " (" + ext + ")");
        #end
    }

    public function createServer():Void
    {
        if (serverStarted)
            return;

        #if sys
        FunkinServer.start(2414);
        #end

        serverStarted = true;

        FunkinServer.registerClass("funkin/Conductor", Conductor);
        FunkinServer.registerClass("funkin/funkin/Conductor", Conductor);
        FunkinServer.registerClass("funkin/modding/ModMain", ModMain);
        FunkinServer.registerClass("funkin/modding/ModUtils", ModUtils);
        FunkinServer.registerClass("funkin/modding/ModState", ModState);
        FunkinServer.registerClass("funkin/funkin/modding/ModState", ModState);
        FunkinServer.registerClass("funkin/modding/ModSubState", ModSubState);
        FunkinServer.registerClass("funkin/funkin/modding/ModSubState", ModSubState);

        FunkinServer.registerClass("flixel/FlxG", flixel.FlxG);
        FunkinServer.registerClass("flixel/flixel/FlxG", flixel.FlxG);
        FunkinServer.registerClass("flixel/FlxSprite", flixel.FlxSprite);
        FunkinServer.registerClass("flixel/FlxCamera", flixel.FlxCamera);

        FunkinServer.registerClass("funkin/play/PlayState", PlayState);
        FunkinServer.registerClass("funkin/funkin/play/PlayState", PlayState);
        FunkinServer.registerClass("funkin/play/characters/Character", Character);
        FunkinServer.registerClass("funkin/funkin/play/characters/Character", Character);
        FunkinServer.registerClass("funkin/play/notes/Note", Note);
        FunkinServer.registerClass("funkin/play/notes/Strumline", Strumline);
        FunkinServer.registerClass("funkin/play/song/Song", Song);
        FunkinServer.registerClass("funkin/play/stage/Stage", Stage);

        FunkinServer.registerClass("funkin/sprites/MenuSprite", MenuSprite);

        FunkinServer.registerClass("funkin/ui/FunkinSoundTray", FunkinSoundTray);
        FunkinServer.registerClass("funkin/ui/SparrowText", SparrowText);
        FunkinServer.registerClass("funkin/ui/mainmenu/MainMenuState", MainMenuState);
        FunkinServer.registerClass("funkin/funkin/ui/mainmenu/MainMenuState", MainMenuState);
        FunkinServer.registerClass("funkin/ui/story/StoryMenuState", StoryMenuState);
        FunkinServer.registerClass("funkin/funkin/ui/story/StoryMenuState", StoryMenuState);
        FunkinServer.registerClass("funkin/ui/title/AttractState", AttractState);
        FunkinServer.registerClass("funkin/funkin/ui/title/AttractState", AttractState);
        FunkinServer.registerClass("funkin/ui/title/TitleState", TitleState);
        FunkinServer.registerClass("funkin/funkin/ui/title/TitleState", TitleState);

        FunkinServer.registerClass("funkin/util/HapticUtil", HapticUtil);
        FunkinServer.registerClass("funkin/util/VideoUtil", VideoUtil);
    }

    public static function shutdown():Void
    {
        trace("FunkinModding: shutdown called");
        #if cpp
        QuickJSBackend.shutdown();
        LuaBackend.shutdown();
        #end

        #if sys
        FunkinServer.stop();
        cleanCreamDirectory();
        #end
    }
}
