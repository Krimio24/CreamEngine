package funkin.modding.backend;

import haxe.ds.StringMap;

#if cpp
@:buildXml('
<target id="haxe">
  <lib name="C:/Users/krist/OneDrive/Escritorio/Kristian/CreamEngine/lib/quickjs_static.lib" if="windows"/>
</target>
')
@:headerCode('
extern "C" {
    bool qjs_init();
    void qjs_close();
    bool qjs_run_script(const char* code, const char* filename);
    bool qjs_run_module(const char* code, const char* filename);
    bool qjs_run_file(const char* path);
    int qjs_get_callback_count();
    const char* qjs_get_callback(int index);
    void qjs_clear_callbacks();
}
')
#end
class QuickJSBackend
{
    public static var initialized(default, null):Bool = false;
    static var callbacks:StringMap<Void->Void> = new StringMap();

    public static function initialize(?path:String):Bool
    {
        if (initialized)
            return true;

        #if cpp
        try
        {
            initialized = untyped __cpp__('qjs_init()');
            if (initialized)
                trace("QuickJS embedded in Funkin.exe initialized successfully!");
            return initialized;
        }
        catch (e:Dynamic)
        {
            trace("QuickJS embedded init error: " + e);
            return false;
        }
        #elseif js
        initialized = true;
        return true;
        #else
        return false;
        #end
    }

    public static function shutdown():Void
    {
        if (!initialized)
            return;

        #if cpp
        untyped __cpp__('qjs_close()');
        #end

        callbacks.clear();
        initialized = false;
    }

    public static function execute(code:String, ?filename:String = "mod.js"):Bool
    {
        if (!initialized && !initialize())
            return false;

        #if cpp
        return untyped __cpp__('qjs_run_script(code.c_str(), filename.c_str())');
        #elseif js
        try
        {
            js.Syntax.code("(0, eval)({0})", code);
            return true;
        }
        catch (e:Dynamic)
        {
            trace("JavaScript error in " + filename + ": " + e);
            return false;
        }
        #else
        return false;
        #end
    }

    public static function loadFile(path:String):Bool
    {
        #if cpp
        if (!initialized && !initialize())
            return false;

        if (!sys.FileSystem.exists(path))
            return false;

        return untyped __cpp__('qjs_run_file(path.c_str())');
        #else
        return false;
        #end
    }

    public static function executeTypeScript(code:String, ?filename:String = "Main.ts"):Bool
    {
        #if cpp
        if (!initialized && !initialize())
            return false;

        return untyped __cpp__('qjs_run_module(code.c_str(), filename.c_str())');
        #else
        return false;
        #end
    }

    public static function registerCallback(name:String, callback:Void->Void):Void
    {
        callbacks.set(name, callback);
    }

    public static function unregisterCallback(name:String):Void
    {
        callbacks.remove(name);
    }

    public static function callCallback(raw:String):Void
    {
        if (raw == null || raw == "")
            return;

        var parts = raw.split("|");
        var name = parts[0];
        var args:Array<Dynamic> = [];
        for (i in 1...parts.length)
        {
            var val:Dynamic = parts[i];
            if (val == "true") val = true;
            else if (val == "false") val = false;
            else if (val == "null") val = null;
            else {
                var num = Std.parseFloat(val);
                if (!Math.isNaN(num) && Std.string(num) == val)
                    val = num;
            }
            args.push(val);
        }

        var callback = callbacks.get(name);

        if (callback != null)
        {
            callback();
            return;
        }

        var normalizedPath = name;
        while (StringTools.startsWith(normalizedPath, "funkin/funkin/"))
            normalizedPath = "funkin/" + normalizedPath.substr(14);

        try
        {
            var separator = normalizedPath.lastIndexOf("/");
            if (separator != -1)
            {
                var classPath = normalizedPath.substr(0, separator);
                var methodName = normalizedPath.substr(separator + 1);
                FunkinServer.callClass(classPath + "/" + methodName, methodName, args);
            }
        }
        catch (e:Dynamic)
        {
            trace('QuickJS callback dispatch error for $raw: $e');
        }
    }

    public static function drainCallbacks():Void
    {
        #if cpp
        if (!initialized)
            return;

        var count:Int = untyped __cpp__('qjs_get_callback_count()');
        if (count <= 0)
            return;

        var pending:Array<String> = [];
        for (i in 0...count)
        {
            var str:cpp.ConstCharStar = untyped __cpp__('qjs_get_callback(i)');
            if (str != null)
                pending.push(str.toString());
        }
        untyped __cpp__('qjs_clear_callbacks()');

        for (name in pending)
        {
            callCallback(name);
        }
        #end
    }

    public static function installBridge():Bool
    {
        if (!initialized && !initialize())
            return false;

        return true;
    }
}
