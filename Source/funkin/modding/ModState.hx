package funkin.modding;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSubState;
import haxe.ds.StringMap;

/**
 * ModState — a scriptable FlxState that mods can register and switch to by name.
 *
 * Usage from TypeScript/Lua mod:
 *   ModState.switchTo("myCustomState");
 *   ModState.push("myOverlay");        // opens as SubState
 *
 * Register from Haxe:
 *   ModState.register("myCustomState", () -> new MyCustomModState());
 */
class ModState extends FlxState
{
    // -------------------------------------------------------------------------
    //  Registry
    // -------------------------------------------------------------------------

    /** name → factory function that returns a new ModState (or subclass). */
    public static var registry:StringMap<Void->FlxState> = new StringMap();

    /** Name of the currently active mod state (or null). */
    public static var currentName:String = null;

    /**
     * Register a named factory for a ModState subclass or FlxState.
     */
    public static function register(name:String, factory:Void->FlxState):Void
    {
        registry.set(name, factory);
        trace('ModState: registered "$name"');
    }

    /**
     * Remove a registration.
     */
    public static function unregister(name:String):Void
    {
        registry.remove(name);
    }

    /**
     * Full FlxG.switchState() to a registered or dynamic mod state.
     */
    public static function switchTo(name:String):Bool
    {
        var factory = registry.get(name);
        var targetState:FlxState = null;
        if (factory != null)
        {
            targetState = factory();
        }
        else
        {
            targetState = new ModState(name);
        }

        currentName = name;
        trace('ModState: switching to state "$name"');
        FlxG.switchState(() -> targetState);
        return true;
    }

    /**
     * Open a registered or dynamic mod substate overlay on top of the current state.
     */
    public static function push(name:String):Bool
    {
        return ModSubState.open(name);
    }

    /**
     * Returns true if a state with the given name is registered.
     */
    public static function isRegistered(name:String):Bool
    {
        return registry.exists(name);
    }

    // -------------------------------------------------------------------------
    //  Instance
    // -------------------------------------------------------------------------

    public var data:Dynamic = {};
    public var stateName:String = null;

    public function new(?name:String)
    {
        super();
        if (name != null)
            stateName = name;
    }

    override function create():Void
    {
        super.create();
        trace('ModState: create() — stateName=$stateName');
    }

    override function destroy():Void
    {
        super.destroy();
        trace('ModState: destroy() — stateName=$stateName');
    }
}

/**
 * ModSubState — a scriptable FlxSubState overlay for mods.
 */
class ModSubState extends FlxSubState
{
    public static var subRegistry:StringMap<Void->FlxSubState> = new StringMap();

    public var subStateName:String = null;
    public var data:Dynamic = {};

    public function new(?name:String)
    {
        super();
        if (name != null)
            subStateName = name;
    }

    public static function register(name:String, factory:Void->FlxSubState):Void
    {
        subRegistry.set(name, factory);
    }

    public static function open(name:String):Bool
    {
        if (FlxG.game == null || FlxG.state == null)
        {
            trace('ModSubState: open("$name") failed — FlxG.game or FlxG.state is null');
            return false;
        }

        var factory = subRegistry.get(name);
        var targetSub:FlxSubState = null;
        if (factory != null)
            targetSub = factory();
        else
            targetSub = new ModSubState(name);

        trace('ModSubState: opening substate "$name"');
        FlxG.state.openSubState(targetSub);
        return true;
    }

    override function create():Void
    {
        super.create();
        trace('ModSubState: create() — subStateName=$subStateName');
    }

    override function destroy():Void
    {
        super.destroy();
        trace('ModSubState: destroy() — subStateName=$subStateName');
    }
}
