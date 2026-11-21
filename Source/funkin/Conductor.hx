package funkin;

import flixel.FlxG;
import flixel.sound.FlxSound;
import haxe.Json;
import openfl.utils.Assets;

/** Keeps musical timing in sync with the currently playing song. */
class Conductor {
	public static var instance(default, null):Conductor = new Conductor();

	public var songPosition(default, null):Float = 0;
	public var bpm:Float = 100;
	public var beatLength(default, null):Float = 60000 / 100;
	public var curBeat(default, null):Int = 0;
	public var curStep(default, null):Int = 0;
	public var curMeasure(default, null):Int = 0;
	public var music(default, null):FlxSound;
	public var metadata(default, null):Dynamic = {};

	/** Assign callbacks with forms such as `Conductor.instance.onBeatHit = function(beat:Int) {}`. */
	public var onBeatHit:Int->Void;
	public var onStepHit:Int->Void;
	public var onMeasureHit:Int->Void;
	public var onTimeChange:Int->Void;

	var timeChanges:Array<Dynamic> = [];
	var timeUnitScale:Float = 1;
	var lastBeat:Int = -1;
	var lastStep:Int = -1;
	var lastMeasure:Int = -1;
	var lastTimeChange:Int = -1;
	var listening:Bool = false;
	var looped:Bool = true;
	var runtimeChange:Dynamic;

	public function new() {}

	/** Loads `<folder>/<prefix>.ogg` and its sibling `<prefix>-metadata.json`. */
	public function play(folder:String, prefix:String):FlxSound {
		var base = cleanPath(folder);
		var name = stripExtension(prefix);
		var audioPath = joinPath(base, name + ".ogg");
		var metadataPath = joinPath(base, name + "-metadata.json");
		var metadata:Dynamic = {};

		if (Assets.exists(metadataPath)) {
			try {
				metadata = Json.parse(Assets.getText(metadataPath));
			} catch (error:Dynamic) {
				trace('Could not read song metadata "$metadataPath": $error');
			}
		}

		return playParams(audioPath, metadata);
	}

	/** Starts an audio asset using metadata already parsed from JSON. */
	public function playParams(path:String, params:Dynamic):FlxSound {
		if (music != null) music.stop();
		var data = params == null ? {} : params;
		metadata = data;
		var format = Std.string(read(data, "timeFormat", "ms")).toLowerCase();
		timeUnitScale = (format == "s" || format == "sec" || format == "seconds") ? 1000 : 1;
		looped = readBool(data, "looped", true);
		mapTimeChanges(readArray(data, "timeChanges"));

		music = FlxG.sound.playMusic(cleanPath(path), null, 1, looped);
		songPosition = 0;
		lastBeat = lastStep = lastMeasure = lastTimeChange = -1;
		runtimeChange = null;
		attachUpdate();
		return music;
	}

	/** Replaces the timing map. `t` and `duration` use the metadata timeFormat. */
	public function mapTimeChanges(changes:Array<Dynamic>):Void {
		timeChanges = changes == null ? [] : changes.copy();
		timeChanges.sort(function(a, b) {
			var timeA = number(read(a, "t", 0));
			var timeB = number(read(b, "t", 0));
			return timeA < timeB ? -1 : (timeA > timeB ? 1 : 0);
		});
		runtimeChange = null;
	}

	/** Changes tempo immediately at the current song position. */
	public function forceBPM(value:Float):Void {
		if (value <= 0) return;
		runtimeChange = {
			t: songPosition,
			b: beatAt(songPosition),
			from: bpmAt(songPosition),
			to: value,
			duration: 0
		};
	}

	/** Smoothly changes tempo over `durationMs` milliseconds of song time. */
	public function tweenBPM(value:Float, durationMs:Float):Void {
		if (value <= 0) return;
		runtimeChange = {
			t: songPosition,
			b: beatAt(songPosition),
			from: bpmAt(songPosition),
			to: value,
			duration: Math.max(0, durationMs)
		};
	}

	public function stop():Void {
		if (music != null) music.stop();
		music = null;
		songPosition = 0;
		lastBeat = lastStep = lastMeasure = lastTimeChange = -1;
	}

	function attachUpdate():Void {
		if (!listening) {
			FlxG.signals.postUpdate.add(updateFromMusic);
			listening = true;
		}
	}

	function updateFromMusic():Void {
		if (music == null) return;
		songPosition = music.time;
		var position = songPosition;
		bpm = bpmAt(position);
		beatLength = 60000 / bpm;
		var beatValue = beatAt(position);
		var beat = Std.int(Math.floor(beatValue + 0.000001));
		var step = Std.int(Math.floor(beatValue * 4 + 0.000001));
		var measure = Std.int(Math.floor(beatValue / beatsPerMeasureAt(position)));
		curBeat = beat;
		curStep = step;
		curMeasure = measure;

		if (beat < lastBeat) {
			lastBeat = beat - 1;
			lastStep = step - 1;
			lastMeasure = measure - 1;
		}
		if (beat > lastBeat) {
			for (value in (lastBeat + 1)...(beat + 1)) if (onBeatHit != null) onBeatHit(value);
			lastBeat = beat;
		}
		if (step > lastStep) {
			for (value in (lastStep + 1)...(step + 1)) if (onStepHit != null) onStepHit(value);
			lastStep = step;
		}
		if (measure > lastMeasure) {
			for (value in (lastMeasure + 1)...(measure + 1)) if (onMeasureHit != null) onMeasureHit(value);
			lastMeasure = measure;
		}
		var changeIndex = activeChangeIndex(position);
		if (changeIndex != lastTimeChange) {
			lastTimeChange = changeIndex;
			if (changeIndex >= 0 && onTimeChange != null) onTimeChange(changeIndex);
		}
	}

	function bpmAt(position:Float):Float {
		if (runtimeChange != null && position >= runtimeChange.t) {
			var duration:Float = runtimeChange.duration;
			if (duration <= 0 || position >= runtimeChange.t + duration) return runtimeChange.to;
			var ratio = (position - runtimeChange.t) / duration;
			return runtimeChange.from + (runtimeChange.to - runtimeChange.from) * ratio;
		}
		var index = activeChangeIndex(position);
		if (index < 0) return 100;
		var point = timeChanges[index];
		var current = validBpm(read(point, "bpm", 100));
		var next = index + 1 < timeChanges.length ? timeChanges[index + 1] : null;
		if (next != null && isTween(point)) {
			var duration = changeDuration(index);
			if (duration > 0 && position < number(read(point, "t", 0)) * timeUnitScale + duration) {
				var elapsed = Math.max(0, position - number(read(point, "t", 0)) * timeUnitScale);
				var ratio = elapsed / duration;
				return current + (validBpm(read(next, "bpm", current)) - current) * ratio;
			}
			return validBpm(read(next, "bpm", current));
		}
		return current;
	}

	function beatAt(position:Float):Float {
		if (runtimeChange != null && position >= runtimeChange.t) {
			var start:Float = runtimeChange.t;
			var duration:Float = runtimeChange.duration;
			var startBeat:Float = runtimeChange.b;
			var from:Float = runtimeChange.from;
			var to:Float = runtimeChange.to;
			var elapsed = position - start;
			if (duration <= 0) return startBeat + Math.max(0, elapsed) * to / 60000;
			var rampTime = Math.min(Math.max(0, elapsed), duration);
			var rampBeats = (from * rampTime + (to - from) * rampTime * rampTime / (2 * duration)) / 60000;
			return startBeat + rampBeats + Math.max(0, elapsed - duration) * to / 60000;
		}

		var index = activeChangeIndex(position);
		if (index < 0) return Math.max(0, position) * 100 / 60000;
		var point = timeChanges[index];
		var startTime = number(read(point, "t", 0)) * timeUnitScale;
		return segmentBeatAt(index, position, beatAtMapStart(index));
	}

	function beatAtMapStart(index:Int):Float {
		var beat:Float = 0;
		for (i in 0...index) {
			var point = timeChanges[i];
			if (Reflect.hasField(point, "b") && Reflect.field(point, "b") != null) beat = number(Reflect.field(point, "b"));
			var nextTime = number(read(timeChanges[i + 1], "t", 0)) * timeUnitScale;
			beat = segmentBeatAt(i, nextTime, beat);
		}
		var current = timeChanges[index];
		if (Reflect.hasField(current, "b") && Reflect.field(current, "b") != null) beat = number(Reflect.field(current, "b"));
		return beat;
	}

	function segmentBeatAt(index:Int, position:Float, startBeat:Float):Float {
		var point = timeChanges[index];
		var startTime = number(read(point, "t", 0)) * timeUnitScale;
		var elapsed = Math.max(0, position - startTime);
		var currentBpm = validBpm(read(point, "bpm", 100));
		var next = index + 1 < timeChanges.length ? timeChanges[index + 1] : null;
		if (next != null && isTween(point)) {
			var duration = changeDuration(index);
			if (duration > 0) {
				var nextBpm = validBpm(read(next, "bpm", currentBpm));
				var rampTime = Math.min(elapsed, duration);
				var rampBeats = (currentBpm * rampTime + (nextBpm - currentBpm) * rampTime * rampTime / (2 * duration)) / 60000;
				return startBeat + rampBeats + Math.max(0, elapsed - duration) * nextBpm / 60000;
			}
		}
		return startBeat + elapsed * currentBpm / 60000;
	}

	function changeDuration(index:Int):Float {
		var point = timeChanges[index];
		var raw = number(read(point, "duration", 0));
		if (raw > 0) return raw * timeUnitScale;
		if (index + 1 >= timeChanges.length) return 0;
		return Math.max(0, number(read(timeChanges[index + 1], "t", 0)) * timeUnitScale - number(read(point, "t", 0)) * timeUnitScale);
	}

	function activeChangeIndex(position:Float):Int {
		var found = -1;
		for (i in 0...timeChanges.length) {
			if (number(read(timeChanges[i], "t", 0)) * timeUnitScale <= position) found = i;
			else break;
		}
		return found;
	}

	function beatsPerMeasureAt(position:Float):Float {
		var index = activeChangeIndex(position);
		if (index < 0) return 4;
		var point = timeChanges[index];
		var numerator = number(read(point, "n", 0));
		if (numerator <= 0) {
			var beats = readArray(point, "bt");
			numerator = beats.length > 0 ? beats.length : 4;
		}
		return numerator;
	}

	function isTween(point:Dynamic):Bool {
		var value = read(point, "tween", false);
		return value == true || (Std.isOfType(value, String) && Std.string(value).toLowerCase() == "true");
	}

	static function read(object:Dynamic, field:String, fallback:Dynamic):Dynamic {
		if (object == null || !Reflect.hasField(object, field)) return fallback;
		var value = Reflect.field(object, field);
		return value == null ? fallback : value;
	}

	static function readBool(object:Dynamic, field:String, fallback:Bool):Bool {
		var value = read(object, field, fallback);
		if (Std.isOfType(value, Bool)) return value;
		return Std.string(value).toLowerCase() == "true";
	}

	static function readArray(object:Dynamic, field:String):Array<Dynamic> {
		var value:Dynamic = read(object, field, []);
		return Std.isOfType(value, Array) ? cast value : [];
	}

	static function number(value:Dynamic):Float {
		var result = Std.parseFloat(Std.string(value));
		return Math.isNaN(result) ? 0 : result;
	}

	static function validBpm(value:Dynamic):Float {
		var result = number(value);
		return result > 0 ? result : 100;
	}

	static function cleanPath(path:String):String {
		return StringTools.replace(StringTools.replace(path, "\\", "/"), "//", "/");
	}

	static function stripExtension(path:String):String {
		return StringTools.endsWith(path.toLowerCase(), ".ogg") ? path.substr(0, path.length - 4) : path;
	}

	static function joinPath(folder:String, file:String):String {
		return folder == "" ? file : (StringTools.endsWith(folder, "/") ? folder + file : folder + "/" + file);
	}
}
