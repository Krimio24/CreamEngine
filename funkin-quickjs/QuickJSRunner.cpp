
#include "quickjs.h"

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <filesystem>
#include <cstdlib>
#include <regex>

namespace fs = std::filesystem;

static JSRuntime* runtime = nullptr;
static JSContext* context = nullptr;
static std::vector<std::string> callbacks;

static bool readFile(const std::string& path, std::string& output)
{
    std::ifstream file(path, std::ios::binary);

    if (!file)
        return false;

    std::stringstream buffer;
    buffer << file.rdbuf();
    output = buffer.str();

    return true;
}

static void stripTypeScript(std::string& code)
{
    try
    {
        // Remove "type ... = ...;"
        code = std::regex_replace(code, std::regex(R"(type\s+[A-Za-z0-9_]+(?:\s*<[^>]*>)?\s*=\s*[^;]+;)"), "");
        // Remove interface declarations
        code = std::regex_replace(code, std::regex(R"(interface\s+[A-Za-z0-9_]+(?:\s*<[^>]*>)?\s*\{[^}]*\})"), "");
        // Remove function return type annotations: "): type {" or "): type =>"
        code = std::regex_replace(code, std::regex(R"(\):\s*(?:[A-Za-z0-9_<>, \[\]|?]+)\s*(=>|\{))"), R"() $1)");
        // Remove variable type annotations: "let x: type ="
        code = std::regex_replace(code, std::regex(R"((const|let|var)\s+([A-Za-z0-9_]+)\s*:\s*[A-Za-z0-9_<>, \[\]|?]+\s*(=))"), R"($1 $2 $3)");
        // Remove "as [Type]"
        code = std::regex_replace(code, std::regex(R"(\s+as\s+[A-Za-z0-9_<>, \[\]|?]+)"), "");
    }
    catch (...) {}
}

static fs::path resolveModulePath(
    const char* baseName,
    const char* moduleName
)
{
    fs::path requested = fs::u8path(moduleName);
    std::string modStr = moduleName ? moduleName : "";

    std::vector<fs::path> searchPaths;

    if (requested.is_absolute())
    {
        searchPaths.push_back(requested);
    }
    else
    {
        if (baseName && *baseName)
        {
            searchPaths.push_back(
                fs::u8path(baseName).parent_path() / requested
            );
        }

        // Direct search under C:/funkin-cream/mods/src
        searchPaths.push_back(
            fs::path("C:/funkin-cream/mods/src") / requested
        );

        // Strip leading ../, ./, . and / for robust resolving (e.g. .flixel/FlxG or ../../../../runtime/proxy)
        std::string stripped = modStr;
        while (!stripped.empty()) {
            if (stripped.rfind("../", 0) == 0) {
                stripped = stripped.substr(3);
            } else if (stripped.rfind("./", 0) == 0) {
                stripped = stripped.substr(2);
            } else if (stripped[0] == '.' && stripped.size() > 1 && stripped[1] != '.') {
                stripped = stripped.substr(1);
            } else if (stripped[0] == '/') {
                stripped = stripped.substr(1);
            } else {
                break;
            }
        }

        searchPaths.push_back(fs::path("C:/funkin-cream/mods/src") / stripped);
        searchPaths.push_back(fs::path("C:/funkin-cream/mods") / stripped);
        if (baseName && *baseName) {
            searchPaths.push_back(fs::u8path(baseName).parent_path() / stripped);
        }

        if (modStr.find("runtime/proxy") != std::string::npos)
        {
            searchPaths.push_back(fs::path("C:/funkin-cream/mods/src/runtime/proxy"));
            searchPaths.push_back(fs::path("C:/funkin-cream/mods/runtime/proxy"));
        }
    }

    const char* extensions[] = {
        "",
        ".ts",
        ".js",
        ".mjs"
    };

    const char* indexFiles[] = {
        "index.ts",
        "index.js",
        "index.mjs"
    };

    for (const fs::path& base : searchPaths)
    {
        for (const char* extension : extensions)
        {
            fs::path candidate = base;

            if (*extension)
                candidate += extension;

            std::error_code error;

            if (fs::is_regular_file(candidate, error))
                return fs::absolute(candidate).lexically_normal();
        }

        for (const char* filename : indexFiles)
        {
            fs::path candidate = base / filename;
            std::error_code error;

            if (fs::is_regular_file(candidate, error))
                return fs::absolute(candidate).lexically_normal();
        }
    }

    return fs::absolute(searchPaths.front()).lexically_normal();
}


static char* normalizeModule(
    JSContext* ctx,
    const char* baseName,
    const char* moduleName,
    void* opaque
)
{
    try
    {
        fs::path path = resolveModulePath(baseName, moduleName);
        std::string result = path.string();

        char* output = static_cast<char*>(
            js_malloc(ctx, result.size() + 1)
        );

        if (!output)
        {
            JS_ThrowOutOfMemory(ctx);
            return nullptr;
        }

        std::memcpy(
            output,
            result.c_str(),
            result.size() + 1
        );

        return output;
    }
    catch (...)
    {
        JS_ThrowReferenceError(
            ctx,
            "Could not resolve module"
        );

        return nullptr;
    }
}

static JSModuleDef* loadModule(
    JSContext* ctx,
    const char* moduleName,
    void* opaque
)
{
    std::string code;

    if (!readFile(moduleName, code))
    {
        JS_ThrowReferenceError(
            ctx,
            "Could not read module: %s",
            moduleName
        );

        return nullptr;
    }

    stripTypeScript(code);

    JSValue compiled = JS_Eval(
        ctx,
        code.c_str(),
        code.size(),
        moduleName,
        JS_EVAL_TYPE_MODULE | JS_EVAL_FLAG_COMPILE_ONLY
    );

    if (JS_IsException(compiled))
        return nullptr;

    return static_cast<JSModuleDef*>(JS_VALUE_GET_PTR(compiled));
}

static JSValue jsCall(
    JSContext* ctx,
    JSValueConst thisValue,
    int argc,
    JSValueConst* argv
)
{
    if (argc < 1)
        return JS_UNDEFINED;

    const char* name = JS_ToCString(ctx, argv[0]);

    if (!name)
        return JS_EXCEPTION;

    callbacks.emplace_back(name);

    JS_FreeCString(ctx, name);

    return JS_UNDEFINED;
}

static JSValue jsConsoleLog(
    JSContext* ctx,
    JSValueConst thisValue,
    int argc,
    JSValueConst* argv
)
{
    std::string out = "[QuickJS] ";
    for (int i = 0; i < argc; i++) {
        if (i > 0) out += " ";
        const char* str = JS_ToCString(ctx, argv[i]);
        if (str) {
            out += str;
            JS_FreeCString(ctx, str);
        }
    }
    std::cout << out << std::endl;
    return JS_UNDEFINED;
}

static bool initialize()
{
    runtime = JS_NewRuntime();

    if (!runtime)
        return false;

    context = JS_NewContext(runtime);

    if (!context)
        return false;

    JS_SetModuleLoaderFunc(
        runtime,
        normalizeModule,
        loadModule,
        nullptr
    );

    JSValue global = JS_GetGlobalObject(context);

    // console.log / warn / error / info
    JSValue console = JS_NewObject(context);
    JS_SetPropertyStr(context, console, "log", JS_NewCFunction(context, jsConsoleLog, "log", 1));
    JS_SetPropertyStr(context, console, "warn", JS_NewCFunction(context, jsConsoleLog, "warn", 1));
    JS_SetPropertyStr(context, console, "error", JS_NewCFunction(context, jsConsoleLog, "error", 1));
    JS_SetPropertyStr(context, console, "info", JS_NewCFunction(context, jsConsoleLog, "info", 1));
    JS_SetPropertyStr(context, global, "console", console);

    JSValue funkin = JS_NewObject(context);

    JS_SetPropertyStr(
        context,
        funkin,
        "call",
        JS_NewCFunction(context, jsCall, "call", 1)
    );

    JS_SetPropertyStr(
        context,
        global,
        "__funkin__",
        funkin
    );

    JS_FreeValue(context, global);

    return true;
}

static std::string valueToString(
    JSContext* ctx,
    JSValueConst value
)
{
    const char* string = JS_ToCString(ctx, value);

    if (!string)
        return "";

    std::string result(string);

    JS_FreeCString(ctx, string);

    return result;
}

static JSValue executeScript(
    std::string code,
    const std::string& filename
)
{
    stripTypeScript(code);

    return JS_Eval(
        context,
        code.c_str(),
        code.size(),
        filename.c_str(),
        JS_EVAL_TYPE_GLOBAL
    );
}

static JSValue executeModule(
    std::string code,
    const std::string& filename
)
{
    stripTypeScript(code);

    JSValue compiled = JS_Eval(
        context,
        code.c_str(),
        code.size(),
        filename.c_str(),
        JS_EVAL_TYPE_MODULE | JS_EVAL_FLAG_COMPILE_ONLY
    );

    if (JS_IsException(compiled))
        return JS_EXCEPTION;

    return JS_EvalFunction(context, compiled);
}

static JSValue handleCommand(JSValueConst command)
{
    JSValue typeValue = JS_GetPropertyStr(
        context,
        command,
        "type"
    );

    std::string commandType = valueToString(
        context,
        typeValue
    );

    JS_FreeValue(context, typeValue);

    if (commandType == "execute" ||
        commandType == "executeModule" ||
        commandType == "typescript")
    {
        JSValue codeValue = JS_GetPropertyStr(
            context,
            command,
            "code"
        );

        JSValue filenameValue = JS_GetPropertyStr(
            context,
            command,
            "filename"
        );

        std::string code = valueToString(context, codeValue);
        std::string filename = valueToString(context, filenameValue);

        JS_FreeValue(context, codeValue);
        JS_FreeValue(context, filenameValue);

        if (filename.empty())
            filename = "mod.js";

        JSValue result;

        if (commandType == "execute")
            result = executeScript(code, filename);
        else
            result = executeModule(code, filename);

        if (JS_IsException(result))
            return JS_EXCEPTION;

        JS_FreeValue(context, result);

        return JS_NewBool(context, true);
    }

    if (commandType == "loadFile")
    {
        JSValue pathValue = JS_GetPropertyStr(
            context,
            command,
            "path"
        );

        std::string path = valueToString(context, pathValue);

        JS_FreeValue(context, pathValue);

        std::string code;

        if (!readFile(path, code))
        {
            JS_ThrowReferenceError(
                context,
                "Could not read script file"
            );

            return JS_EXCEPTION;
        }

        JSValue result = executeModule(code, path);

        if (JS_IsException(result))
            return JS_EXCEPTION;

        JS_FreeValue(context, result);

        return JS_NewBool(context, true);
    }

    if (commandType == "setGlobal")
    {
        JSValue nameValue = JS_GetPropertyStr(
            context,
            command,
            "name"
        );

        JSValue value = JS_GetPropertyStr(
            context,
            command,
            "value"
        );

        std::string name = valueToString(context, nameValue);

        JS_FreeValue(context, nameValue);

        JSValue global = JS_GetGlobalObject(context);

        JS_SetPropertyStr(
            context,
            global,
            name.c_str(),
            value
        );

        JS_FreeValue(context, global);

        return JS_NewBool(context, true);
    }

    if (commandType == "drainCallbacks")
    {
        JSValue array = JS_NewArray(context);

        for (uint32_t i = 0; i < callbacks.size(); i++)
        {
            JS_SetPropertyUint32(
                context,
                array,
                i,
                JS_NewString(context, callbacks[i].c_str())
            );
        }

        callbacks.clear();

        return array;
    }

    if (commandType == "shutdown")
        return JS_NewBool(context, true);

    JS_ThrowReferenceError(
        context,
        "Unknown command"
    );

    return JS_EXCEPTION;
}

static void sendResponse(bool success, JSValue result)
{
    JSValue response = JS_NewObject(context);

    JS_SetPropertyStr(
        context,
        response,
        "ok",
        JS_NewBool(context, success)
    );

    if (success)
    {
        JS_SetPropertyStr(
            context,
            response,
            "result",
            result
        );
    }
    else
    {
        JSValue error = JS_GetException(context);
        std::string message = valueToString(context, error);

        JS_SetPropertyStr(
            context,
            response,
            "error",
            JS_NewString(context, message.c_str())
        );

        JS_FreeValue(context, error);
    }

    JSValue json = JS_JSONStringify(
        context,
        response,
        JS_UNDEFINED,
        JS_UNDEFINED
    );

    std::string output = valueToString(context, json);

    std::cout << output << std::endl;

    JS_FreeValue(context, json);
    JS_FreeValue(context, response);
}

extern "C" {

bool qjs_init()
{
    return initialize();
}

void qjs_close()
{
    if (context) {
        JS_FreeContext(context);
        context = nullptr;
    }
    if (runtime) {
        JS_FreeRuntime(runtime);
        runtime = nullptr;
    }
    callbacks.clear();
}

bool qjs_run_script(const char* code, const char* filename)
{
    if (!context && !initialize())
        return false;
    JSValue res = executeScript(code ? code : "", filename ? filename : "script.js");
    bool ok = !JS_IsException(res);
    if (!ok) {
        JSValue exc = JS_GetException(context);
        const char* str = JS_ToCString(context, exc);
        if (str) {
            std::cerr << "[QuickJS Error in " << (filename ? filename : "script") << "] " << str << std::endl;
            JS_FreeCString(context, str);
        }
        JS_FreeValue(context, exc);
    }
    JS_FreeValue(context, res);
    return ok;
}

bool qjs_run_module(const char* code, const char* filename)
{
    if (!context && !initialize())
        return false;
    JSValue res = executeModule(code ? code : "", filename ? filename : "module.js");
    bool ok = !JS_IsException(res);
    if (!ok) {
        JSValue exc = JS_GetException(context);
        const char* str = JS_ToCString(context, exc);
        if (str) {
            std::cerr << "[QuickJS Error in " << (filename ? filename : "module") << "] " << str << std::endl;
            JS_FreeCString(context, str);
        }
        JS_FreeValue(context, exc);
    }
    JS_FreeValue(context, res);
    return ok;
}

bool qjs_run_file(const char* path)
{
    if (!context && !initialize())
        return false;
    std::string code;
    if (!readFile(path, code))
        return false;
    JSValue res = executeModule(code, path);
    bool ok = !JS_IsException(res);
    if (!ok) {
        JSValue exc = JS_GetException(context);
        const char* str = JS_ToCString(context, exc);
        if (str) {
            std::cerr << "[QuickJS Error in " << (path ? path : "file") << "] " << str << std::endl;
            JS_FreeCString(context, str);
        }
        JS_FreeValue(context, exc);
    }
    JS_FreeValue(context, res);
    return ok;
}

int qjs_get_callback_count()
{
    return (int)callbacks.size();
}

const char* qjs_get_callback(int index)
{
    if (index >= 0 && index < (int)callbacks.size())
        return callbacks[index].c_str();
    return "";
}

void qjs_clear_callbacks()
{
    callbacks.clear();
}

}
