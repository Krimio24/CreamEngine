package funkin.modding;

import sys.net.Socket;
import sys.net.Host;
import sys.thread.Thread;
import haxe.ds.StringMap;
import haxe.rtti.Meta;
import Type;
import Reflect;

class FunkinServer {
	static var socket:Socket;
	static var running:Bool = false;

	static var functions:StringMap<Void->Void> = new StringMap();

	static var registeredClasses:StringMap<Class<Dynamic>> = new StringMap();

	static var mainThread:Thread;
	static var pending:Array<{
		callback:Void->Void,
		client:Socket
	}> = [];

	public static function register(path:String, callback:Void->Void):Void {
		functions.set(normalize(path), callback);
	}

	public static function unregister(path:String):Void {
		functions.remove(normalize(path));
	}

	public static function start(port:Int = 2414):Void {
		if (running)
			return;

		mainThread = Thread.current();

		socket = new Socket();
		socket.bind(new Host("127.0.0.1"), port);
		socket.listen(10);

		running = true;

		Thread.create(function() {
			while (running) {
				try {
					var client = socket.accept();

					Thread.create(function() {
						handleClient(client);
					});
				} catch (e:Dynamic) {
					if (running)
						trace(e);
				}
			}
		});
	}

	static function handleClient(client:Socket):Void {
		try {
			while (running) {
				var request = client.input.readLine();
				var response = process(request);

				client.output.writeString(response + "\n");
				client.output.flush();
			}
		} catch (e:Dynamic) {}

		client.close();
	}

	static function process(request:String):String {
		var separator = request.indexOf(" ");

		if (separator == -1)
			return "ERROR Invalid command";

		var command = request.substr(0, separator);
		var path = normalize(request.substr(separator + 1));

		switch (command) {
			case "CALL":
				if (!StringTools.endsWith(path, "()"))
					return "ERROR CALL requires ()";

				path = path.substr(0, path.length - 2);

				if (!functions.exists(path))
					return "ERROR Function not registered";

				pending.push({
					callback: functions.get(path),
					client: null
				});

				return "QUEUED";

			default:
				return "ERROR Unknown command";
		}
	}

	public static function update():Void {
		if (Thread.current() != mainThread)
			return;

		while (pending.length > 0) {
			var task = pending.shift();

			try {
				task.callback();
			} catch (e:Dynamic) {
				trace("FunkinServer: " + e);
			}
		}
	}

	static function normalize(path:String):String {
		return StringTools.trim(path);
	}

	public static function stop():Void {
		running = false;

		if (socket != null) {
			socket.close();
			socket = null;
		}

		pending = [];
		functions = new StringMap();
	}

	public static function registerClass(path:String, cls:Class<Dynamic>):Void {
		registeredClasses.set(path, cls);
	}

	public static function callClass(path:String, method:String, args:Array<Dynamic> = null):Dynamic {
		var normalized = path;
		while (StringTools.startsWith(normalized, "funkin/funkin/")) {
			normalized = "funkin/" + normalized.substr(14);
		}
		while (StringTools.startsWith(normalized, "flixel/flixel/")) {
			normalized = "flixel/" + normalized.substr(14);
		}

		// Find the longest registered class prefix in normalized
		var matchedClassPath:String = null;
		var cls:Class<Dynamic> = null;
		var remaining:String = null;

		var parts = normalized.split("/");
		var i = parts.length;
		while (i > 0) {
			var subPath = parts.slice(0, i).join("/");
			cls = registeredClasses.get(subPath);
			if (cls == null) {
				cls = registeredClasses.get("funkin/" + subPath);
			}
			if (cls == null) {
				cls = registeredClasses.get("flixel/" + subPath);
			}
			if (cls != null) {
				matchedClassPath = subPath;
				remaining = parts.slice(i).join("/");
				break;
			}
			i--;
		}

		if (cls == null) {
			trace('FunkinServer: Class not registered for path: $path');
			return null;
		}

		var subParts:Array<String> = [];
		if (remaining != null && remaining != "") {
			subParts = remaining.split("/");
		} else if (method != null && method != "") {
			subParts = [method];
		}

		if (subParts.length == 0) {
			return cls;
		}

		var targetObj:Dynamic = cls;

		// If static class has an instance and the first field is not on cls, try instance or FlxG.state
		if (Reflect.hasField(cls, "instance") && !Reflect.hasField(cls, subParts[0])) {
			var inst = Reflect.field(cls, "instance");
			if (inst != null) targetObj = inst;
		} else if (flixel.FlxG.game != null && flixel.FlxG.state != null && Std.isOfType(flixel.FlxG.state, cls) && !Reflect.hasField(cls, subParts[0])) {
			targetObj = flixel.FlxG.state;
		}

		// Traverse subParts (e.g. ["mouse", "load"])
		for (k in 0...(subParts.length - 1)) {
			var fieldName = subParts[k];
			if (targetObj != null && Reflect.hasField(targetObj, fieldName)) {
				targetObj = Reflect.field(targetObj, fieldName);
				if (targetObj == null) {
					trace('FunkinServer: Field $fieldName on $matchedClassPath is null (not initialized yet)');
					return null;
				}
			} else {
				trace('FunkinServer: Field $fieldName not found on target for path $path');
				return null;
			}
		}

		if (targetObj == null) {
			trace('FunkinServer: Target is null for path $path');
			return null;
		}

		var finalMethod = subParts[subParts.length - 1];
		if (!Reflect.hasField(targetObj, finalMethod)) {
			trace('FunkinServer: Method or field $finalMethod not found on target for path $path');
			return null;
		}

		var callback = Reflect.field(targetObj, finalMethod);
		if (callback != null && Reflect.isFunction(callback)) {
			trace('FunkinServer: Calling $matchedClassPath.$remaining()');
			try {
				return Reflect.callMethod(targetObj, callback, args == null ? [] : args);
			} catch (e:Dynamic) {
				trace('FunkinServer: Error calling $finalMethod: $e');
				return null;
			}
		} else {
			return callback;
		}
	}
}
