package funkin.util;

import flixel.FlxSprite;
import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.media.SoundChannel;
import openfl.events.SampleDataEvent;
import haxe.io.Bytes;

@:buildXml("
<target id='haxe'>
	<lib name='mfplat.lib' if='windows'/>
	<lib name='mfreadwrite.lib' if='windows'/>
	<lib name='mfuuid.lib' if='windows'/>
	<lib name='ole32.lib' if='windows'/>
	<lib name='user32.lib' if='windows'/>
</target>
")
class VideoUtil {
	
	public function new() {}

	#if (cpp && windows)
	public function createVideo(path:String, ?onEnd:Void->Void):FlxSprite {
		var video = new NativeVideoSprite(0, 0);
		video.onEndReached = onEnd;
		if (!video.load(path)) {
			video.destroy();
			return null;
		}
		video.play();
		return video;
	}
	#elseif android
	public function createVideo(path:String, ?onEnd:Void->Void):FlxSprite {
		var video = new FFmpegVideoSprite();
		video.onEndReached = onEnd;
		if (!video.load(path)) {
			video.destroy();
			return null;
		}
		return video;
	}
	#else
	public function createVideo(path:String, ?onEnd:Void->Void):FlxSprite {
		return null;
	}
	#end
    
}

#if android
/** Video sprite backed by the project's openfl-ffmpeg decoder. */
class FFmpegVideoSprite extends FlxSprite {
	public var onEndReached:Void->Void;
	var decoder:AndroidFFmpegDecoder;
	var decoderActive:Bool = false;

	public function new() {
		super();
	}

	public function load(path:String):Bool {
		try {
			decoder = new AndroidFFmpegDecoder();
			decoder.openAndPlay(path, function() {
				if (!decoderActive) return;
				decoderActive = false;
				if (onEndReached != null) onEndReached();
			}, function() {
				if (!decoderActive || decoder.bitmapData == null) return;
				dirty = true;
			});
			pixels = decoder.bitmapData;
			decoderActive = true;
			return decoder.bitmapData != null;
		} catch (error:Dynamic) {
			trace('FFmpeg could not open video "$path": $error');
			return false;
		}
	}

	public function stop():Void {
		decoderActive = false;
		if (decoder != null) decoder.stop();
	}

	override public function destroy():Void {
		stop();
		super.destroy();
	}
}
#end

#if (cpp && windows)
@:cppFileCode('
#include <windows.h>
#include <shobjidl.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <mferror.h>
#include <vector>

struct VideoInstance {
    IMFSourceReader* pReader = NULL;
    UINT32 width = 0;
    UINT32 height = 0;
    double fps = 30.0;
    double durationSeconds = 0.0;
    double currentTime = 0.0;
    bool hasAudio = false;
    std::vector<short> audioBuffer;
    size_t audioReadPos = 0;
    bool eofAudio = false;
    bool eofVideo = false;
};

static bool mfInitialized = false;
static ITaskbarList3* g_pTaskbarList = NULL;

static HWND findAppWindow() {
    HWND hwnd = GetActiveWindow();
    if (!hwnd) hwnd = GetForegroundWindow();
    DWORD currentPid = GetCurrentProcessId();
    if (hwnd) {
        DWORD pid = 0;
        GetWindowThreadProcessId(hwnd, &pid);
        if (pid == currentPid) return hwnd;
    }
    // Fallback: enumerate windows for current process
    struct EnumData { DWORD pid; HWND hwnd; } data = { currentPid, NULL };
    EnumWindows([](HWND h, LPARAM lp) -> BOOL {
        EnumData* d = (EnumData*)lp;
        DWORD p = 0;
        GetWindowThreadProcessId(h, &p);
        if (p == d->pid && IsWindowVisible(h)) {
            d->hwnd = h;
            return FALSE;
        }
        return TRUE;
    }, (LPARAM)&data);
    return data.hwnd;
}

void setTaskbarProgress(double percent) {
    if (!g_pTaskbarList) {
        CoCreateInstance(CLSID_TaskbarList, NULL, CLSCTX_INPROC_SERVER, IID_ITaskbarList3, (void**)&g_pTaskbarList);
        if (g_pTaskbarList) {
            g_pTaskbarList->HrInit();
        }
    }
    if (!g_pTaskbarList) return;

    HWND hwnd = findAppWindow();
    if (!hwnd) return;

    if (percent < 0) {
        g_pTaskbarList->SetProgressState(hwnd, TBPF_NOPROGRESS);
    } else {
        g_pTaskbarList->SetProgressState(hwnd, TBPF_NORMAL);
        ULONGLONG ullCompleted = (ULONGLONG)(percent * 100.0);
        g_pTaskbarList->SetProgressValue(hwnd, ullCompleted, 10000);
    }
}

void clearTaskbarProgress() {
    if (!g_pTaskbarList) return;
    HWND hwnd = findAppWindow();
    if (hwnd) {
        g_pTaskbarList->SetProgressState(hwnd, TBPF_NOPROGRESS);
    }
}

void* createVideoInstance(const wchar_t* path) {
    if (!mfInitialized) {
        CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
        MFStartup(MF_VERSION);
        mfInitialized = true;
    }

    IMFAttributes* pAttributes = NULL;
    MFCreateAttributes(&pAttributes, 1);
    pAttributes->SetUINT32(MF_SOURCE_READER_ENABLE_VIDEO_PROCESSING, TRUE);

    IMFSourceReader* pReader = NULL;
    HRESULT hr = MFCreateSourceReaderFromURL(path, pAttributes, &pReader);
    if (pAttributes) pAttributes->Release();
    if (FAILED(hr) || !pReader) return NULL;

    // 1. Configurar salida de Video a RGB32
    IMFMediaType* pVideoType = NULL;
    MFCreateMediaType(&pVideoType);
    pVideoType->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
    pVideoType->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32);
    hr = pReader->SetCurrentMediaType((DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM, NULL, pVideoType);
    pVideoType->Release();
    if (FAILED(hr)) { pReader->Release(); return NULL; }

    IMFMediaType* pCurrentVideo = NULL;
    pReader->GetCurrentMediaType((DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM, &pCurrentVideo);
    UINT32 w = 0, h = 0, num = 30, den = 1;
    MFGetAttributeSize(pCurrentVideo, MF_MT_FRAME_SIZE, &w, &h);
    MFGetAttributeRatio(pCurrentVideo, MF_MT_FRAME_RATE, &num, &den);
    pCurrentVideo->Release();

    // 2. Configurar salida de Audio a PCM 44100Hz Estéreo 16-bit
    IMFMediaType* pAudioType = NULL;
    MFCreateMediaType(&pAudioType);
    pAudioType->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
    pAudioType->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_PCM);
    pAudioType->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, 2);
    pAudioType->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, 44100);
    pAudioType->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
    pAudioType->SetUINT32(MF_MT_AUDIO_BLOCK_ALIGNMENT, 4);
    pAudioType->SetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND, 44100 * 4);
    HRESULT hrAudio = pReader->SetCurrentMediaType((DWORD)MF_SOURCE_READER_FIRST_AUDIO_STREAM, NULL, pAudioType);
    pAudioType->Release();

    // 3. Obtener duracion total
    double durSec = 0.0;
    PROPVARIANT varProp;
    PropVariantInit(&varProp);
    if (SUCCEEDED(pReader->GetPresentationAttribute((DWORD)MF_SOURCE_READER_MEDIASOURCE, MF_PD_DURATION, &varProp))) {
        if (varProp.vt == VT_UI8) {
            durSec = (double)varProp.uhVal.QuadPart / 10000000.0;
        }
        PropVariantClear(&varProp);
    }

    VideoInstance* inst = new VideoInstance();
    inst->pReader = pReader;
    inst->width = w;
    inst->height = h;
    inst->fps = (den > 0) ? ((double)num / (double)den) : 30.0;
    inst->durationSeconds = durSec;
    inst->currentTime = 0.0;
    inst->hasAudio = SUCCEEDED(hrAudio);
    return (void*)inst;
}

int getVideoWidth(void* ptr) { return ptr ? ((VideoInstance*)ptr)->width : 0; }
int getVideoHeight(void* ptr) { return ptr ? ((VideoInstance*)ptr)->height : 0; }
double getVideoFPS(void* ptr) { return ptr ? ((VideoInstance*)ptr)->fps : 30.0; }
double getVideoDuration(void* ptr) { return ptr ? ((VideoInstance*)ptr)->durationSeconds : 0.0; }
double getVideoCurrentTime(void* ptr) { return ptr ? ((VideoInstance*)ptr)->currentTime : 0.0; }
bool videoHasAudio(void* ptr) { return ptr ? ((VideoInstance*)ptr)->hasAudio : false; }

bool readVideoFrame(void* ptr, unsigned char* outBuffer, int bufferSize) {
    if (!ptr) return false;
    VideoInstance* inst = (VideoInstance*)ptr;
    if (inst->eofVideo) return false;

    DWORD streamIndex, flags;
    LONGLONG llTimeStamp = 0;
    IMFSample* pSample = NULL;

    HRESULT hr = inst->pReader->ReadSample((DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM, 0, &streamIndex, &flags, &llTimeStamp, &pSample);
    if (FAILED(hr) || (flags & MF_SOURCE_READERF_ENDOFSTREAM)) {
        inst->eofVideo = true;
        if (pSample) pSample->Release();
        return false;
    }

    if (pSample) {
        inst->currentTime = (double)llTimeStamp / 10000000.0;
        IMFMediaBuffer* pBuffer = NULL;
        pSample->ConvertToContiguousBuffer(&pBuffer);
        BYTE* pData = NULL;
        DWORD maxLen, curLen;
        pBuffer->Lock(&pData, &maxLen, &curLen);

        int copySize = (curLen < (DWORD)bufferSize) ? curLen : bufferSize;
        memcpy(outBuffer, pData, copySize);

        // MFVideoFormat_RGB32 leaves the high byte unused. BitmapData treats
        // that byte as alpha, so mark every pixel fully opaque before upload.
        for (int i = 3; i < copySize; i += 4) {
            outBuffer[i] = 0xFF;
        }

        pBuffer->Unlock();
        pBuffer->Release();
        pSample->Release();
        return true;
    }
    return false;
}

// Lee muestras PCM (floats entre -1.0 y 1.0) para OpenFL SampleDataEvent
int readAudioSamples(void* ptr, double* outFloats, int numFrames) {
    if (!ptr) return 0;
    VideoInstance* inst = (VideoInstance*)ptr;
    if (!inst->hasAudio) return 0;

    size_t neededShorts = (size_t)numFrames * 2; // Estéreo

    while ((inst->audioBuffer.size() - inst->audioReadPos) < neededShorts && !inst->eofAudio) {
        DWORD streamIndex, flags;
        LONGLONG llTimeStamp;
        IMFSample* pSample = NULL;
        HRESULT hr = inst->pReader->ReadSample((DWORD)MF_SOURCE_READER_FIRST_AUDIO_STREAM, 0, &streamIndex, &flags, &llTimeStamp, &pSample);

        if (FAILED(hr) || (flags & MF_SOURCE_READERF_ENDOFSTREAM)) {
            inst->eofAudio = true;
            if (pSample) pSample->Release();
            break;
        }

        if (pSample) {
            IMFMediaBuffer* pBuffer = NULL;
            pSample->ConvertToContiguousBuffer(&pBuffer);
            BYTE* pData = NULL;
            DWORD maxLen, curLen;
            pBuffer->Lock(&pData, &maxLen, &curLen);

            short* samples = (short*)pData;
            size_t count = curLen / sizeof(short);
            inst->audioBuffer.insert(inst->audioBuffer.end(), samples, samples + count);

            pBuffer->Unlock();
            pBuffer->Release();
            pSample->Release();
        }
    }

    size_t available = inst->audioBuffer.size() - inst->audioReadPos;
    size_t toCopy = (available < neededShorts) ? available : neededShorts;

    for (size_t i = 0; i < toCopy; i++) {
        outFloats[i] = (double)inst->audioBuffer[inst->audioReadPos + i] / 32768.0;
    }
    inst->audioReadPos += toCopy;

    // Limpiar memoria ya reproducida
    if (inst->audioReadPos > 44100 * 4) {
        inst->audioBuffer.erase(inst->audioBuffer.begin(), inst->audioBuffer.begin() + inst->audioReadPos);
        inst->audioReadPos = 0;
    }

    return (int)(toCopy / 2);
}

void destroyVideoInstance(void* ptr) {
    if (!ptr) return;
    VideoInstance* inst = (VideoInstance*)ptr;
    if (inst->pReader) inst->pReader->Release();
    delete inst;
}
')
#end

#if (cpp && windows)
class NativeVideoSprite extends FlxSprite {
	public var onEndReached:Void->Void;
	public var isPlaying:Bool = false;
	public var duration:Float = 0;
	public var time:Float = 0;

#if (cpp && windows)
	private var handle:cpp.Star<cpp.Void> = null;
	#end
	private var videoBitmap:BitmapData;
	private var frameBytes:Bytes;
	private var frameDuration:Float = 1 / 30;
	private var timer:Float = 0;

	// Audio
	private var sound:Sound;
	private var channel:SoundChannel;
	private var hasAudio:Bool = false;
	private var audioFloatBuffer:Array<Float>;

	public function new(x:Float = 0, y:Float = 0) {
		super(x, y);
		audioFloatBuffer = new Array<Float>();
		audioFloatBuffer.resize(4096 * 2);
	}

	/**
	 * Devuelve el progreso del video en un porcentaje de 0 a 100 (o de 1 a 100).
	 */
	public function getProgress(minOne:Bool = false):Float {
		if (duration <= 0)
			return minOne ? 1.0 : 0.0;
		var pct = (time / duration) * 100.0;
		if (pct > 100.0) pct = 100.0;
		if (minOne && pct < 1.0) pct = 1.0;
		else if (pct < 0.0) pct = 0.0;
		return pct;
	}

	public function load(path:String):Bool {
		stop();
		#if windows
		var fullPath = sys.FileSystem.fullPath(path);
		handle = untyped __cpp__('createVideoInstance({0}.wchar_str())', fullPath);
		if (handle == null)
			return false;

		var w:Int = untyped __cpp__('getVideoWidth({0})', handle);
		var h:Int = untyped __cpp__('getVideoHeight({0})', handle);
		var fps:Float = untyped __cpp__('getVideoFPS({0})', handle);
		duration = untyped __cpp__('getVideoDuration({0})', handle);
		time = 0;
		hasAudio = untyped __cpp__('videoHasAudio({0})', handle);

		frameDuration = 1.0 / fps;
		videoBitmap = new BitmapData(w, h, true, 0xFF000000);
		frameBytes = Bytes.alloc(w * h * 4);
		this.pixels = videoBitmap;

		advanceFrame();
		return true;
		#else
		return false;
		#end
	}

	public function play():Void {
		if (isPlaying)
			return;
		isPlaying = true;

		#if windows
		updateTaskbar(getProgress());
		if (hasAudio && sound == null) {
			sound = new Sound();
			sound.addEventListener(SampleDataEvent.SAMPLE_DATA, onSampleData);
			channel = sound.play();
		}
		#end
	}

	#if windows
	private function updateTaskbar(percent:Float):Void {
		untyped __cpp__('setTaskbarProgress({0})', percent);
	}

	private function onSampleData(event:SampleDataEvent):Void {
		if (handle == null || !isPlaying)
			return;
		var framesToRead = 4096;
		var read:Int = untyped __cpp__('readAudioSamples({0}, (double*)&{1}[0], {2})', handle, audioFloatBuffer, framesToRead);

		for (i in 0...(read * 2)) {
			event.data.writeFloat(audioFloatBuffer[i]);
		}
		// Rellenar con silencio si llegó al final del audio para evitar chasquidos
		if (read < framesToRead) {
			for (i in (read * 2)...(framesToRead * 2)) {
				event.data.writeFloat(0.0);
			}
		}
	}
	#end

	override public function update(elapsed:Float):Void {
		super.update(elapsed);
		if (!isPlaying)
			return;

		timer += elapsed;
		while (timer >= frameDuration) {
			timer -= frameDuration;
			if (!advanceFrame()) {
				stop();
				if (onEndReached != null)
					onEndReached();
				break;
			}
		}
	}

	private function advanceFrame():Bool {
		#if windows
		if (handle == null)
			return false;
		var rawData = frameBytes.getData();
		var ok:Bool = untyped __cpp__('readVideoFrame({0}, (unsigned char*)&{1}[0], {2})', handle, rawData, frameBytes.length);
		if (ok) {
			videoBitmap.setPixels(videoBitmap.rect, frameBytes);
			this.dirty = true;
			time = untyped __cpp__('getVideoCurrentTime({0})', handle);
			updateTaskbar(getProgress());
			return true;
		}
		#end
		return false;
	}

	public function stop():Void {
		isPlaying = false;
		#if windows
		untyped __cpp__('clearTaskbarProgress()');
		#end
		if (channel != null) {
			channel.stop();
			channel = null;
		}
		if (sound != null) {
			sound.removeEventListener(SampleDataEvent.SAMPLE_DATA, onSampleData);
			sound = null;
		}
		#if windows
		if (handle != null) {
			untyped __cpp__('destroyVideoInstance({0})', handle);
			handle = null;
		}
		#end
	}

	override public function destroy():Void {
		stop();
		super.destroy();
	}
}
#end
