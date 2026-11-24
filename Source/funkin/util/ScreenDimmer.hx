package funkin.util;

#if (cpp && windows)
@:cppFileCode('
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <vector>

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")

struct DimmerEntry {
    HWND hwnd;
    HMONITOR hMonitor;
    RECT rect;
};

static std::vector<DimmerEntry> s_dimmerEntries;

static BOOL CALLBACK MonitorDimmerEnumProc(HMONITOR hMonitor, HDC hdcMonitor, LPRECT lprcMonitor, LPARAM dwData) {
    MONITORINFO mi;
    mi.cbSize = sizeof(mi);
    if (GetMonitorInfo(hMonitor, &mi)) {
        RECT rc = mi.rcMonitor;
        int x = rc.left;
        int y = rc.top;
        int w = rc.right - rc.left;
        int h = rc.bottom - rc.top;

        static bool classRegistered = false;
        if (!classRegistered) {
            WNDCLASSW wc;
            memset(&wc, 0, sizeof(wc));
            wc.lpfnWndProc = DefWindowProcW;
            wc.hInstance = GetModuleHandle(NULL);
            wc.lpszClassName = L"CreamScreenDimmer";
            wc.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);
            RegisterClassW(&wc);
            classRegistered = true;
        }

        HWND hwnd = CreateWindowExW(
            WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
            L"CreamScreenDimmer",
            L"",
            WS_POPUP | WS_VISIBLE,
            x, y, w, h,
            NULL, NULL, GetModuleHandle(NULL), NULL
        );

        if (hwnd) {
            SetLayeredWindowAttributes(hwnd, 0, 0, LWA_ALPHA);
            SetWindowPos(hwnd, HWND_BOTTOM, x, y, w, h, SWP_NOACTIVATE | SWP_SHOWWINDOW);
            DimmerEntry entry;
            entry.hwnd = hwnd;
            entry.hMonitor = hMonitor;
            entry.rect = rc;
            s_dimmerEntries.push_back(entry);
        }
    }
    return TRUE;
}

static void win32_dimmer_init() {
    for (size_t i = 0; i < s_dimmerEntries.size(); i++) {
        HWND h = s_dimmerEntries[i].hwnd;
        if (IsWindow(h)) DestroyWindow(h);
    }
    s_dimmerEntries.clear();
    EnumDisplayMonitors(NULL, NULL, MonitorDimmerEnumProc, 0);

    HWND gameHwnd = GetActiveWindow();
    if (!gameHwnd) gameHwnd = GetForegroundWindow();
    if (gameHwnd) {
        SetWindowPos(gameHwnd, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    }
}

static void win32_dimmer_set_alpha(float alpha) {
    if (alpha < 0.0f) alpha = 0.0f;
    if (alpha > 1.0f) alpha = 1.0f;
    BYTE bAlpha = (BYTE)(alpha * 255.0f);
    for (size_t i = 0; i < s_dimmerEntries.size(); i++) {
        HWND h = s_dimmerEntries[i].hwnd;
        if (IsWindow(h)) {
            SetLayeredWindowAttributes(h, 0, bAlpha, LWA_ALPHA);
        }
    }
}

static void win32_dimmer_keep_secondary_only(int gx, int gy, int gw, int gh) {
    for (size_t i = 0; i < s_dimmerEntries.size(); i++) {
        HWND h = s_dimmerEntries[i].hwnd;
        if (IsWindow(h)) DestroyWindow(h);
    }
    s_dimmerEntries.clear();

    struct EnumData { int gx, gy, gw, gh; } data = { gx, gy, gw, gh };
    EnumDisplayMonitors(NULL, NULL, [](HMONITOR hMon, HDC, LPRECT, LPARAM lp) -> BOOL {
        EnumData* d = (EnumData*)lp;
        MONITORINFO mi;
        mi.cbSize = sizeof(mi);
        if (GetMonitorInfo(hMon, &mi)) {
            RECT rc = mi.rcMonitor;
            int x = rc.left, y = rc.top, w = rc.right - rc.left, h = rc.bottom - rc.top;

            bool isGameMonitor = (x == d->gx && y == d->gy);
            if (!isGameMonitor) {
                static bool classRegistered = false;
                if (!classRegistered) {
                    WNDCLASSW wc;
                    memset(&wc, 0, sizeof(wc));
                    wc.lpfnWndProc = DefWindowProcW;
                    wc.hInstance = GetModuleHandle(NULL);
                    wc.lpszClassName = L"CreamScreenDimmer";
                    wc.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);
                    RegisterClassW(&wc);
                    classRegistered = true;
                }

                HWND hwnd = CreateWindowExW(
                    WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
                    L"CreamScreenDimmer", L"",
                    WS_POPUP | WS_VISIBLE,
                    x, y, w, h,
                    NULL, NULL, GetModuleHandle(NULL), NULL
                );
                if (hwnd) {
                    SetLayeredWindowAttributes(hwnd, 0, 255, LWA_ALPHA);
                    SetWindowPos(hwnd, HWND_TOPMOST, x, y, w, h, SWP_NOACTIVATE | SWP_SHOWWINDOW);
                    DimmerEntry e;
                    e.hwnd = hwnd;
                    e.hMonitor = hMon;
                    e.rect = rc;
                    s_dimmerEntries.push_back(e);
                }
            }
        }
        return TRUE;
    }, (LPARAM)&data);
}

static void win32_dimmer_destroy() {
    for (size_t i = 0; i < s_dimmerEntries.size(); i++) {
        HWND h = s_dimmerEntries[i].hwnd;
        if (IsWindow(h)) DestroyWindow(h);
    }
    s_dimmerEntries.clear();
}
')
#end
class ScreenDimmer {
    public static var active:Bool = false;

    public static function start():Void {
        #if (cpp && windows)
        untyped __cpp__('win32_dimmer_init()');
        active = true;
        #end
    }

    public static function setAlpha(alpha:Float):Void {
        #if (cpp && windows)
        untyped __cpp__('win32_dimmer_set_alpha((float){0})', alpha);
        #end
    }

    public static function keepSecondaryOnly(gameX:Int = -99999, gameY:Int = -99999, gameW:Int = 0, gameH:Int = 0):Void {
        #if (cpp && windows)
        untyped __cpp__('win32_dimmer_keep_secondary_only({0}, {1}, {2}, {3})', gameX, gameY, gameW, gameH);
        active = true;
        #end
    }

    public static function finish():Void {
        #if (cpp && windows)
        untyped __cpp__('win32_dimmer_destroy()');
        active = false;
        #end
    }
}
