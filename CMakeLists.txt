# peggle - ReXGlue Recompiled Project
#
# SDK boilerplate lives in generated/rexglue.cmake.

cmake_minimum_required(VERSION 3.25)
project(peggle LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(generated/rexglue.cmake)

# Sources
set(PEGGLE_SOURCES
    src/main.cpp
    src/stubs.cpp
)

if(WIN32)
    add_executable(peggle WIN32 ${PEGGLE_SOURCES})
else()
    add_executable(peggle ${PEGGLE_SOURCES})
endif()

rexglue_setup_target(peggle)
