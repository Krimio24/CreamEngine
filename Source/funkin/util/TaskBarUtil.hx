package funkin.util;

enum abstract TaskbarState(Int) from Int to Int {
    var NoProgress = 0;
    var Indeterminate = 1;
    var Normal = 2;
    var Error = 4;
    var Paused = 8;
}

@:buildXml("
<target id='haxe'>
    <lib name='ole32.lib' if='windows'/>
    <lib name='uuid.lib' if='windows'/>
</target>
")

@:cppFileCode('
#include <windows.h>
#include <shobjidl.h>
#include <cstdint>

static ITaskbarList3* g_taskbar = nullptr;
static bool g_comOwned = false;

static HWND getTaskbarWindow() {
    DWORD pid = GetCurrentProcessId();

    struct WindowData {
        DWORD pid;
        HWND hwnd;
    } data = { pid, nullptr };

    EnumWindows([](HWND hwnd, LPARAM param) -> BOOL {
        WindowData* data = (WindowData*)param;
        DWORD windowPid = 0;

        GetWindowThreadProcessId(hwnd, &windowPid);

        if (windowPid == data->pid && IsWindowVisible(hwnd)) {
            data->hwnd = hwnd;
            return FALSE;
        }

        return TRUE;
    }, (LPARAM)&data);

    return data.hwnd;
}

static bool initializeTaskbar() {
    if (g_taskbar != nullptr)
        return true;

    HRESULT comResult = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);

    if (comResult == S_OK || comResult == S_FALSE)
        g_comOwned = true;

    HRESULT hr = CoCreateInstance(
        CLSID_TaskbarList,
        NULL,
        CLSCTX_INPROC_SERVER,
        IID_ITaskbarList3,
        (void**)&g_taskbar
    );

    if (FAILED(hr) || !g_taskbar) {
        g_taskbar = nullptr;

        if (g_comOwned) {
            CoUninitialize();
            g_comOwned = false;
        }

        return false;
    }

    if (FAILED(g_taskbar->HrInit())) {
        g_taskbar->Release();
        g_taskbar = nullptr;

        if (g_comOwned) {
            CoUninitialize();
            g_comOwned = false;
        }

        return false;
    }

    return true;
}

static void taskbarSetState(int state) {
    if (!initializeTaskbar())
        return;

    HWND hwnd = getTaskbarWindow();
    if (!hwnd)
        return;

    g_taskbar->SetProgressState(hwnd, (TBPFLAG)state);
}

static void taskbarSetProgress(double percent) {
    if (!initializeTaskbar())
        return;

    HWND hwnd = getTaskbarWindow();
    if (!hwnd)
        return;

    if (percent < 0.0) percent = 0.0;
    if (percent > 100.0) percent = 100.0;

    g_taskbar->SetProgressState(hwnd, TBPF_NORMAL);

    ULONGLONG completed = (ULONGLONG)(percent * 100.0);

    g_taskbar->SetProgressValue(
        hwnd,
        completed,
        10000
    );
}

static void taskbarClear() {
    if (!g_taskbar)
        return;

    HWND hwnd = getTaskbarWindow();

    if (hwnd)
        g_taskbar->SetProgressState(hwnd, TBPF_NOPROGRESS);
}

static void taskbarShutdown() {
    if (g_taskbar) {
        g_taskbar->Release();
        g_taskbar = nullptr;
    }

    if (g_comOwned) {
        CoUninitialize();
        g_comOwned = false;
    }
}
')

class TaskBarUtil {
    public static function setProgress(percent:Float):Void {
        #if (cpp && windows)
        if (Math.isNaN(percent))
            return;

        untyped __cpp__('taskbarSetProgress({0})', percent);
        #end
    }

    public static function setState(state:TaskbarState):Void {
        #if (cpp && windows)
        untyped __cpp__('taskbarSetState({0})', state);
        #end
    }

    public static function clear():Void {
        #if (cpp && windows)
        untyped __cpp__('taskbarClear()');
        #end
    }

    public static function shutdown():Void {
        #if (cpp && windows)
        untyped __cpp__('taskbarShutdown()');
        #end
    }
}
