package funkin.util;

import flash.events.SampleDataEvent;
import flash.media.Sound;
import flash.media.SoundChannel;
import flash.utils.ByteArray;
import haxe.Timer;
import haxe.io.Bytes;
import haxe.io.BytesData;
import openfl.display.BitmapData;

/** Adapter for the openfl-ffmpeg native library on Android. */
class AndroidFFmpegDecoder {
	public var width(default, null):Int;
	public var height(default, null):Int;
	public var bitmapData(default, null):BitmapData;

	var frameBuffer:Bytes;
	var sound:Sound;
	var soundChannel:SoundChannel;
	var samples:Array<Float> = [];
	var readPosition:Int = 0;
	var complete:Bool = false;
	var onComplete:Void->Void;
	var onFrame:Void->Void;
	var timer:Timer;

	public function new() {}

	public function openAndPlay(path:String, onComplete:Void->Void, onFrame:Void->Void):Void {
		hx_ffmpeg_open_file(path);
		width = hx_ffmpeg_get_width();
		height = hx_ffmpeg_get_height();
		if (width <= 0 || height <= 0) throw 'FFmpeg could not read video dimensions: $path';

		this.onComplete = onComplete;
		this.onFrame = onFrame;
		bitmapData = new BitmapData(width, height, true, 0x00000000);
		frameBuffer = Bytes.alloc(width * height * 4);
		sound = new Sound();
		sound.addEventListener(SampleDataEvent.SAMPLE_DATA, generateSound);
		soundChannel = sound.play();
		timer = new Timer(Std.int(1000 / 30));
		timer.run = function() {
			decodeFrame();
			if (this.onFrame != null) this.onFrame();
			if (complete) {
				timer.stop();
				dispose();
				if (this.onComplete != null) this.onComplete();
			}
		};
	}

	public function stop():Void {
		complete = true;
	}

	function decodeFrame():Void {
		complete = hx_ffmpeg_decode_frame(frameBuffer.getData(), emitSound) != 0;
		if (bitmapData != null) {
			bitmapData.lock();
			bitmapData.setPixels(bitmapData.rect, ByteArray.fromBytes(frameBuffer));
			bitmapData.unlock();
		}
	}

	function generateSound(event:SampleDataEvent):Void {
		var targetLength = 8192 * 2 * 4;
		if (samples.length == readPosition && complete) return;
		while (event.data.length < targetLength) {
			event.data.writeFloat(readPosition < samples.length ? samples[readPosition++] : 0.0);
		}
		if (readPosition > 16384) {
			samples = samples.slice(readPosition);
			readPosition = 0;
		}
	}

	function emitSound(data:BytesData):Void {
		var input = ByteArray.fromBytesData(data);
		while (input.bytesAvailable > 0) samples.push(input.readFloat());
	}

	function dispose():Void {
		hx_ffmpeg_close_file();
		if (soundChannel != null) {
			soundChannel.stop();
			soundChannel = null;
		}
		if (sound != null) {
			sound.removeEventListener(SampleDataEvent.SAMPLE_DATA, generateSound);
			sound = null;
		}
		bitmapData = null;
		frameBuffer = null;
	}

	static var hx_ffmpeg_open_file = cpp.Lib.load("openfl-ffmpeg", "hx_ffmpeg_open_file", 1);
	static var hx_ffmpeg_get_width = cpp.Lib.load("openfl-ffmpeg", "hx_ffmpeg_get_width", 0);
	static var hx_ffmpeg_get_height = cpp.Lib.load("openfl-ffmpeg", "hx_ffmpeg_get_height", 0);
	static var hx_ffmpeg_decode_frame = cpp.Lib.load("openfl-ffmpeg", "hx_ffmpeg_decode_frame", 2);
	static var hx_ffmpeg_close_file = cpp.Lib.load("openfl-ffmpeg", "hx_ffmpeg_close_file", 0);
}
