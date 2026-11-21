package funkin.util;

import lime.ui.Gamepad;
import haxe.Json;
#if (android || ios)
import extension.haptics.Haptic;
#end
import haxe.Timer;
import openfl.utils.Assets;

#if (cpp && windows)
@:cppFileCode('
#include <windows.h>
#include <xinput.h>
#pragma comment(lib, "xinput.lib")
')
#end

class HapticUtil {
	private static var _initialized:Bool = false;
	private static var activeTimers:Map<Int, Timer> = new Map<Int, Timer>();
	private static var chartTimers:Map<Int, Array<Timer>> = new Map<Int, Array<Timer>>();

	#if (js && html5)
	private var __jsGamepad:js.html.Gamepad;
	#end

	public static function init():Void {
		if (_initialized)
			return;
		_initialized = true;

		#if (android || ios)
		try {
			Haptic.initialize();
		} catch (e:Dynamic) {}
		#end
	}

	private static inline function floatToWord(val:Float):Int {
		if (val <= 0.0)
			return 0;
		if (val >= 1.0)
			return 65535;
		return Std.int(val * 65535.0);
	}

	public static function vibrate(userIndex:Int = 0, leftMotor:Float = 0.0, rightMotor:Float = 0.0):Void {
		init();
		stopTimedVibration(userIndex);

		#if html5
		var gamepad:Gamepad = new Gamepad(userIndex);
		gamepad.rumble(leftMotor, rightMotor, 100);
		#end

		#if (android || ios)
		var intensity:Float = (leftMotor + rightMotor) / 2.0;
		Haptic.vibrateOneShot(0.01, intensity, 0.5);
		#elseif (cpp && windows)
		setRawVibration(userIndex, floatToWord(leftMotor), floatToWord(rightMotor));
		#end
	}

	public static function vibrateFor(userIndex:Int = 0, leftMotor:Float = 0.0, rightMotor:Float = 0.0, durationMs:Int = 200):Void {
		init();
		stopTimedVibration(userIndex);

		#if html5
		var gamepad:Gamepad = new Gamepad(userIndex);
		gamepad.rumble(leftMotor, rightMotor, durationMs);
		#end

		#if (android || ios)
		var durationSec:Float = durationMs / 1000.0;
		var intensity:Float = (leftMotor + rightMotor) / 2.0;
		Haptic.vibrateOneShot(durationSec, intensity, 0.5);
		#elseif (cpp && windows)
		setRawVibration(userIndex, floatToWord(leftMotor), floatToWord(rightMotor));

		var timer = new Timer(durationMs);
		timer.run = function() {
			setRawVibration(userIndex, 0, 0);
			timer.stop();
			activeTimers.remove(userIndex);
		};
		activeTimers.set(userIndex, timer);
		#end
	}

	public static function vibratePattern(durations:Array<Float>, amplitudes:Array<Float>):Void {
		init();

		#if (android || ios)
		var sharpnesses = amplitudes.map(function(_) return 0.5);
		Haptic.vibratePattern(durations, amplitudes, sharpnesses);
		#elseif (cpp && windows)
		var totalDelay:Float = 0;
		for (i in 0...durations.length) {
			var durMs = Std.int(durations[i] * 1000.0);
			var amp = (i < amplitudes.length) ? amplitudes[i] : 1.0;

			Timer.delay(function() {
				vibrateFor(0, amp, amp, durMs);
			}, Std.int(totalDelay));

			totalDelay += durMs;
		}
		#end
	}

	public static function stopVibration(userIndex:Int = 0):Void {
		stopChart(userIndex);
		stopTimedVibration(userIndex);

		#if (android || ios)
		Haptic.dispose();
		_initialized = false;
		#elseif (cpp && windows)
		setRawVibration(userIndex, 0, 0);
		#end
	}

	/** Loads and plays an asset JSON chart. Event fields: atMs, durationMs, left, right. */
	public static function playChart(jsonPath:String, userIndex:Int = 0):Bool {
		var jsonText:Null<String> = null;
		try {
			if (Assets.exists(jsonPath)) jsonText = Assets.getText(jsonPath);
			#if sys
			else if (sys.FileSystem.exists(jsonPath)) jsonText = sys.io.File.getContent(jsonPath);
			#end
		} catch (error:Dynamic) {
			trace('Could not read haptic chart "$jsonPath": $error');
			return false;
		}
		if (jsonText == null) {
			trace('Haptic chart not found: "$jsonPath"');
			return false;
		}
		return playChartFromJson(jsonText, userIndex);
	}

	/** Parses and plays chart JSON already loaded by the caller. */
	public static function playChartFromJson(jsonText:String, userIndex:Int = 0):Bool {
		var chart:Dynamic;
		try {
			chart = Json.parse(jsonText);
		} catch (error:Dynamic) {
			trace('Invalid haptic chart JSON: $error');
			return false;
		}
		if (chart == null || !Reflect.hasField(chart, "events") || !Std.isOfType(Reflect.field(chart, "events"), Array)) {
			trace('Invalid haptic chart: expected an "events" array.');
			return false;
		}

		var events:Array<Dynamic> = cast Reflect.field(chart, "events");
		var parsed:Array<{at:Float, duration:Int, left:Float, right:Float}> = [];
		var totalTime:Float = 0;
		for (event in events) {
			if (event == null) continue;
			var at = chartNumber(event, "atMs", 0);
			var duration = chartNumber(event, "durationMs", 100);
			if (Math.isNaN(at) || Math.isNaN(duration) || at < 0 || duration <= 0) continue;
			var left = clampHaptic(chartNumber(event, "left", 1));
			var right = clampHaptic(chartNumber(event, "right", left));
			var entry = {at: at, duration: Std.int(duration), left: left, right: right};
			parsed.push(entry);
			totalTime = Math.max(totalTime, at + duration);
		}
		if (parsed.length == 0) return false;
		parsed.sort(function(a, b) return a.at < b.at ? -1 : (a.at > b.at ? 1 : 0));

		stopVibration(userIndex);
		init();
		var timers:Array<Timer> = [];
		chartTimers.set(userIndex, timers);
		for (event in parsed) {
			var chartEvent = event;
			var timer = Timer.delay(function() {
				if (chartTimers.exists(userIndex))
					vibrateFor(userIndex, chartEvent.left, chartEvent.right, chartEvent.duration);
			}, Std.int(chartEvent.at));
			timers.push(timer);
		}
		timers.push(Timer.delay(function() {
			chartTimers.remove(userIndex);
		}, Std.int(totalTime + 50)));
		return true;
	}

	/** Cancels a playing chart and silences its controller. */
	public static function stopChart(userIndex:Int = 0):Void {
		var timers = chartTimers.get(userIndex);
		if (timers != null) {
			for (timer in timers) if (timer != null) timer.stop();
			chartTimers.remove(userIndex);
		}
		stopTimedVibration(userIndex);
		#if (android || ios)
		if (_initialized) Haptic.vibrateOneShot(0.01, 0, 0.5);
		#elseif (cpp && windows)
		setRawVibration(userIndex, 0, 0);
		#elseif html5
		var gamepad:Gamepad = new Gamepad(userIndex);
		gamepad.rumble(0, 0, 10);
		#end
	}

	private static function chartNumber(object:Dynamic, field:String, fallback:Float):Float {
		if (object == null || !Reflect.hasField(object, field)) return fallback;
		var value = Std.parseFloat(Std.string(Reflect.field(object, field)));
		return Math.isNaN(value) ? fallback : value;
	}

	private static inline function clampHaptic(value:Float):Float {
		return Math.max(0, Math.min(1, value));
	}

	public static function stopAll():Void {
		for (i in 0...4) stopChart(i);
		#if (android || ios)
		Haptic.dispose();
		_initialized = false;
		#elseif (cpp && windows)
		for (i in 0...4) {
			stopVibration(i);
		}
		#end
	}

	private static function stopTimedVibration(userIndex:Int):Void {
		if (activeTimers.exists(userIndex)) {
			var timer = activeTimers.get(userIndex);
			if (timer != null)
				timer.stop();
			activeTimers.remove(userIndex);
		}
	}

	private static function setRawVibration(userIndex:Int, leftRaw:Int, rightRaw:Int):Void {
		#if (cpp && windows)
		untyped __cpp__('
            XINPUT_VIBRATION vibration;
            ZeroMemory(&vibration, sizeof(XINPUT_VIBRATION));
            vibration.wLeftMotorSpeed = (WORD){0};
            vibration.wRightMotorSpeed = (WORD){1};
            XInputSetState((DWORD){2}, &vibration);
        ', leftRaw, rightRaw, userIndex);
		#end
	}
}
