package funkin.modding.backend;

import haxe.ds.StringMap;
import funkin.modding.FunkinServer;

#if cpp
@:buildXml('
<target id="haxe">
  <compilerflag value="-IC:/Users/krist/OneDrive/Escritorio/Kristian/CreamEngine/funkin-lua/lua"/>
  <lib name="C:/Users/krist/OneDrive/Escritorio/Kristian/CreamEngine/lib/lua_static.lib" if="windows"/>
</target>
')
@:headerCode('
extern "C" {
    bool lua_init();
    void lua_close_engine();
    bool lua_run_file(const char* path);
    bool lua_run_string(const char* code, const char* chunkname);
    int lua_callback_count();
    const char* lua_get_callback(int index);
    void lua_clear_callbacks();
    const char* lua_get_last_error();
}
')
#end
class LuaBackend
{
    public static var initialized(default, null):Bool = false;
    static var callbacks:StringMap<Dynamic->Void> = new StringMap();

    public static function initialize():Bool
    {
        if (initialized)
            return true;

        #if cpp
        try
        {
            initialized = untyped __cpp__('lua_init()');
            if (initialized)
                trace("LuaBackend: embedded Lua 5.4 initialized successfully!");
            return initialized;
        }
        catch (e:Dynamic)
        {
            trace("LuaBackend: init error: " + e);
            return false;
        }
        #else
        return false;
        #end
    }

    public static function shutdown():Void
    {
        if (!initialized)
            return;

        #if cpp
        untyped __cpp__('lua_close_engine()');
        #end

        callbacks.clear();
        initialized = false;
    }

    public static function loadFile(path:String):Bool
    {
        #if cpp
        if (!initialized && !initialize())
            return false;

        #if sys
        if (!sys.FileSystem.exists(path))
        {
            trace("LuaBackend: file does not exist: " + path);
            return false;
        }
        #end

        return untyped __cpp__('lua_run_file(path.c_str())');
        #else
        return false;
        #end
    }

    public static function execute(code:String, ?chunkname:String = "mod.lua"):Bool
    {
        #if cpp
        if (!initialized && !initialize())
            return false;

        return untyped __cpp__('lua_run_string(code.c_str(), chunkname.c_str())');
        #else
        return false;
        #end
    }

    public static function registerCallback(name:String, callback:Dynamic->Void):Void
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
        var path = parts[0];
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

        var callback = callbacks.get(path);
        if (callback != null)
        {
            callback(args);
            return;
        }

        var normalizedPath = path;
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
            trace('LuaBackend callback dispatch error for $raw: $e');
        }
    }

    public static function drainCallbacks():Void
    {
        #if cpp
        if (!initialized)
            return;

        var count:Int = untyped __cpp__('lua_callback_count()');
        if (count <= 0)
            return;

        var pending:Array<String> = [];
        for (i in 0...count)
        {
            var str:cpp.ConstCharStar = untyped __cpp__('lua_get_callback(i)');
            if (str != null)
                pending.push(str.toString());
        }
        untyped __cpp__('lua_clear_callbacks()');

        for (item in pending)
        {
            callCallback(item);
        }
        #end
    }
}
