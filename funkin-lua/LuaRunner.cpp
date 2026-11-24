extern "C" {
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}

#include <iostream>
#include <string>
#include <vector>
#include <sstream>

static lua_State* L = nullptr;
static std::vector<std::string> lua_callbacks;
static std::string lua_last_error = "";

static int lua_funkin_call(lua_State* state) {
    int top = lua_gettop(state);
    if (top < 1) return 0;

    const char* path = luaL_checkstring(state, 1);
    if (!path) return 0;

    std::string item = path;
    // Append any extra string / number arguments separated by '|'
    for (int i = 2; i <= top; i++) {
        item += "|";
        if (lua_isstring(state, i)) {
            item += lua_tostring(state, i);
        } else if (lua_isboolean(state, i)) {
            item += lua_toboolean(state, i) ? "true" : "false";
        } else if (lua_isnumber(state, i)) {
            std::ostringstream ss;
            ss << lua_tonumber(state, i);
            item += ss.str();
        } else if (lua_isnil(state, i)) {
            item += "null";
        }
    }

    lua_callbacks.push_back(item);
    return 0;
}

static int lua_print_wrapper(lua_State* state) {
    int n = lua_gettop(state);
    std::string out = "[Lua] ";
    for (int i = 1; i <= n; i++) {
        if (i > 1) out += "\t";
        if (lua_isstring(state, i)) {
            out += lua_tostring(state, i);
        } else if (lua_isboolean(state, i)) {
            out += lua_toboolean(state, i) ? "true" : "false";
        } else if (lua_isnil(state, i)) {
            out += "nil";
        } else {
            out += luaL_typename(state, i);
        }
    }
    std::cout << out << std::endl;
    return 0;
}

static void setup_lua_globals(lua_State* state) {
    // Override print
    lua_register(state, "print", lua_print_wrapper);

    // Create __funkin__ table
    lua_newtable(state);
    lua_pushcfunction(state, lua_funkin_call);
    lua_setfield(state, -2, "call");
    lua_setglobal(state, "__funkin__");

    // Also global funkinCall
    lua_pushcfunction(state, lua_funkin_call);
    lua_setglobal(state, "funkinCall");

    // Setup helper tables like ModState, TitleState, PlayState for lua mods
    const char* helper_lua = R"(
        ModState = {
            switchTo = function(name)
                __funkin__.call("funkin/modding/ModState/switchTo", name)
            end,
            push = function(name)
                __funkin__.call("funkin/modding/ModState/push", name)
            end,
            isRegistered = function(name)
                __funkin__.call("funkin/modding/ModState/isRegistered", name)
            end
        }

        TitleState = {
            moveToAttract = function()
                __funkin__.call("funkin/ui/title/TitleState/moveToAttract")
            end
        }

        PlayState = {
            loadSong = function(name, diff)
                __funkin__.call("funkin/play/PlayState/loadSong", name, diff or "normal")
            end
        }
    )";

    luaL_dostring(state, helper_lua);
}

extern "C" {

bool lua_init() {
    if (L != nullptr) return true;

    L = luaL_newstate();
    if (!L) {
        lua_last_error = "Failed to create Lua state";
        return false;
    }

    luaL_openlibs(L);
    setup_lua_globals(L);
    return true;
}

void lua_close_engine() {
    if (L) {
        lua_close(L);
        L = nullptr;
    }
    lua_callbacks.clear();
    lua_last_error.clear();
}

bool lua_run_file(const char* path) {
    if (!L && !lua_init()) return false;

    int err = luaL_dofile(L, path);
    if (err != LUA_OK) {
        const char* msg = lua_tostring(L, -1);
        lua_last_error = msg ? msg : "Unknown Lua error";
        std::cerr << "[Lua Error in " << path << "] " << lua_last_error << std::endl;
        lua_pop(L, 1);
        return false;
    }
    return true;
}

bool lua_run_string(const char* code, const char* chunkname) {
    if (!L && !lua_init()) return false;

    int err = luaL_loadbuffer(L, code, strlen(code), chunkname ? chunkname : "chunk");
    if (err == LUA_OK) {
        err = lua_pcall(L, 0, LUA_MULTRET, 0);
    }

    if (err != LUA_OK) {
        const char* msg = lua_tostring(L, -1);
        lua_last_error = msg ? msg : "Unknown Lua error";
        std::cerr << "[Lua Error in " << (chunkname ? chunkname : "chunk") << "] " << lua_last_error << std::endl;
        lua_pop(L, 1);
        return false;
    }
    return true;
}

int lua_callback_count() {
    return (int)lua_callbacks.size();
}

const char* lua_get_callback(int index) {
    if (index >= 0 && index < (int)lua_callbacks.size()) {
        return lua_callbacks[index].c_str();
    }
    return "";
}

void lua_clear_callbacks() {
    lua_callbacks.clear();
}

const char* lua_get_last_error() {
    return lua_last_error.c_str();
}

}
