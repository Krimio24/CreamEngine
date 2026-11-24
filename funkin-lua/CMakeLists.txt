cmake_minimum_required(VERSION 3.20)
project(lua_static C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# Match hxcpp /MT static runtime
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

set(LUA_DIR "${CMAKE_CURRENT_SOURCE_DIR}/lua")

set(LUA_CORE_SOURCES
    "${LUA_DIR}/lapi.c"
    "${LUA_DIR}/lauxlib.c"
    "${LUA_DIR}/lbaselib.c"
    "${LUA_DIR}/lcode.c"
    "${LUA_DIR}/lcorolib.c"
    "${LUA_DIR}/lctype.c"
    "${LUA_DIR}/ldblib.c"
    "${LUA_DIR}/ldebug.c"
    "${LUA_DIR}/ldo.c"
    "${LUA_DIR}/ldump.c"
    "${LUA_DIR}/lfunc.c"
    "${LUA_DIR}/lgc.c"
    "${LUA_DIR}/linit.c"
    "${LUA_DIR}/liolib.c"
    "${LUA_DIR}/llex.c"
    "${LUA_DIR}/lmathlib.c"
    "${LUA_DIR}/lmem.c"
    "${LUA_DIR}/loadlib.c"
    "${LUA_DIR}/lobject.c"
    "${LUA_DIR}/lopcodes.c"
    "${LUA_DIR}/loslib.c"
    "${LUA_DIR}/lparser.c"
    "${LUA_DIR}/lstate.c"
    "${LUA_DIR}/lstring.c"
    "${LUA_DIR}/lstrlib.c"
    "${LUA_DIR}/ltable.c"
    "${LUA_DIR}/ltablib.c"
    "${LUA_DIR}/ltm.c"
    "${LUA_DIR}/lundump.c"
    "${LUA_DIR}/lutf8lib.c"
    "${LUA_DIR}/lvm.c"
    "${LUA_DIR}/lzio.c"
)

add_library(lua_static STATIC
    ${LUA_CORE_SOURCES}
    "${CMAKE_CURRENT_SOURCE_DIR}/LuaRunner.cpp"
)

target_include_directories(lua_static PUBLIC
    "${LUA_DIR}"
    "${CMAKE_CURRENT_SOURCE_DIR}"
)

if(MSVC)
    target_compile_definitions(lua_static PRIVATE
        _CRT_SECURE_NO_WARNINGS
        _CRT_NONSTDC_NO_DEPRECATE
    )
    target_compile_options(lua_static PRIVATE /MT)
endif()
