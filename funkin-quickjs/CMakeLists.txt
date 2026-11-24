cmake_minimum_required(VERSION 3.20)

project(QuickJSRunner LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Match hxcpp's /MT runtime library (Static Release)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

set(QUICKJS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/quickjs")

add_library(quickjs_static STATIC
    QuickJSRunner.cpp
    ${QUICKJS_DIR}/quickjs.c
    ${QUICKJS_DIR}/dtoa.c
    ${QUICKJS_DIR}/libregexp.c
    ${QUICKJS_DIR}/libunicode.c
)

target_include_directories(quickjs_static PUBLIC
    ${QUICKJS_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}
)

if(WIN32)
    target_compile_definitions(quickjs_static PRIVATE
        _CRT_SECURE_NO_WARNINGS
        WIN32_LEAN_AND_MEAN
    )
endif()
