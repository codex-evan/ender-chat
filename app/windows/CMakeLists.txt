cmake_minimum_required(VERSION 3.14)
project(encchat LANGUAGES CXX)

set(BINARY_NAME "encchat")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_INSTALL_RPATH "/lib")

get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release" CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Profile" "Release")
  endif()
endif()

set(CMAKE_EXE_LINKER_FLAGS_PROFILE "")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "")
set(CMAKE_C_FLAGS_PROFILE "")
set(CMAKE_CXX_FLAGS_PROFILE "")

add_compile_definitions(WIN32_LEAN_AND_MEAN NOMINMAX UNICODE _UNICODE)

set(FLUTTER_MANAGED_DIR "/flutter")
add_subdirectory( /flutter)

add_executable(
  "win32_runner.cpp"
  "runner/flutter_window.cpp"
  "runner/utils.cpp"
  "runner/win32_window.cpp"
  "/generated_plugin_registrant.cc"
)

target_include_directories( PRIVATE "")
target_link_libraries( PRIVATE flutter flutter_wrapper_app)
target_link_libraries( PRIVATE "dwmapi.lib")
