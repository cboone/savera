cmake_minimum_required(VERSION 3.21)
project(savera VERSION 0.0.0 LANGUAGES C CXX OBJC OBJCXX)

set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0" CACHE STRING "Minimum macOS version")
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CLAP_WRAPPER_DOWNLOAD_DEPENDENCIES TRUE CACHE BOOL "")
set(PRODUCT_NAME "Savera")
set(REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/..")

include(FetchContent)
file(READ "${REPO_ROOT}/build.zig.zon" SAVERA_ZON)
string(REGEX MATCH "clap/archive/refs/tags/([0-9]+)[.]([0-9]+)[.]([0-9]+)" SAVERA_CLAP_TAG "${SAVERA_ZON}")
set(SAVERA_CLAP_VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}")
FetchContent_Declare(savera-clap URL "https://github.com/free-audio/clap/archive/refs/tags/${SAVERA_CLAP_VERSION}.tar.gz")
FetchContent_MakeAvailable(savera-clap)
set(CLAP_SDK_ROOT "${savera-clap_SOURCE_DIR}")
FetchContent_Declare(clap-wrapper GIT_REPOSITORY https://github.com/free-audio/clap-wrapper.git GIT_TAG 1cca996e96f29ab2be7ae9f8cfe532bbc92e1dd6)
FetchContent_MakeAvailable(clap-wrapper)

file(READ "${REPO_ROOT}/build.zig.zon" SAVERA_ZON)
string(REGEX MATCH "clap/archive/refs/tags/([0-9]+)\.([0-9]+)\.([0-9]+)" SAVERA_CLAP_TAG "${SAVERA_ZON}")
set(SAVERA_CLAP_VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}")
set(SAVERA_CLAP_INCLUDES "${CLAP_SDK_ROOT}/include")
set(SAVERA_WRAPPER_CLAP_VERSION "")
foreach(include_dir IN LISTS SAVERA_CLAP_INCLUDES)
    if(EXISTS "${include_dir}/clap/version.h")
        file(READ "${include_dir}/clap/version.h" CLAP_VERSION_HEADER)
        foreach(part MAJOR MINOR REVISION)
            string(REGEX MATCH "CLAP_VERSION_${part}[ \t]+([0-9]+)" version_match "${CLAP_VERSION_HEADER}")
            set(CLAP_${part} "${CMAKE_MATCH_1}")
        endforeach()
        set(SAVERA_WRAPPER_CLAP_VERSION "${CLAP_MAJOR}.${CLAP_MINOR}.${CLAP_REVISION}")
    endif()
endforeach()
if(SAVERA_CLAP_VERSION STREQUAL "" OR NOT SAVERA_WRAPPER_CLAP_VERSION STREQUAL SAVERA_CLAP_VERSION)
    message(FATAL_ERROR "CLAP header mismatch: Zig ${SAVERA_CLAP_VERSION}, wrapper ${SAVERA_WRAPPER_CLAP_VERSION}")
endif()
message(STATUS "CLAP header versions agree: ${SAVERA_CLAP_VERSION}")

find_program(ZIG_EXECUTABLE zig REQUIRED)
set(ZIG_PREFIX "${CMAKE_BINARY_DIR}/zig")
set(ZIG_IMPL_OBJECT "${ZIG_PREFIX}/lib/savera_impl.o")
add_custom_target(savera-zig ALL COMMAND "${ZIG_EXECUTABLE}" build --release=fast --prefix "${ZIG_PREFIX}" impl WORKING_DIRECTORY "${REPO_ROOT}" BYPRODUCTS "${ZIG_IMPL_OBJECT}" VERBATIM)
add_library(savera-impl INTERFACE)
add_dependencies(savera-impl savera-zig)
target_link_libraries(savera-impl INTERFACE "${ZIG_IMPL_OBJECT}" clap)

make_clapfirst_plugins(
    TARGET_NAME savera
    IMPL_TARGET savera-impl
    OUTPUT_NAME "${PRODUCT_NAME}"
    ENTRY_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/entry.cpp"
    BUNDLE_IDENTIFIER "com.cboone.savera"
    BUNDLE_VERSION "${PROJECT_VERSION}"
    COPY_AFTER_BUILD FALSE
    PLUGIN_FORMATS CLAP AUV2
    ASSET_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/assets"
    AUV2_MANUFACTURER_NAME "Catamount"
    AUV2_MANUFACTURER_CODE "Ctmn"
    AUV2_SUBTYPE_CODE "Svra"
    AUV2_INSTRUMENT_TYPE "aumu"
)

if(APPLE AND TARGET savera_auv2)
    add_custom_command(TARGET savera_auv2 POST_BUILD COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/narrow-au-resource-usage" "$<TARGET_FILE_DIR:savera_auv2>/../Info.plist" VERBATIM)
    add_custom_command(TARGET savera_auv2 POST_BUILD COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/set-au-display-name" "$<TARGET_FILE_DIR:savera_auv2>/../Info.plist" VERBATIM)
endif()

# Signing follows the wrapper's plist generation and both Savera rewrites.
set(SAVERA_CODESIGN_IDENTITY "$ENV{SAVERA_SIGNING_IDENTITY}")
if(SAVERA_CODESIGN_IDENTITY STREQUAL "")
    set(SAVERA_CODESIGN_IDENTITY "-")
endif()
set(SAVERA_CODESIGN_OPTIONS "")
if(NOT SAVERA_CODESIGN_IDENTITY STREQUAL "-")
    set(SAVERA_CODESIGN_OPTIONS --timestamp --options runtime)
endif()
foreach(bundle_target savera_clap savera_auv2)
    if(APPLE AND TARGET ${bundle_target})
        add_custom_command(TARGET ${bundle_target} POST_BUILD
            COMMAND /usr/bin/codesign --remove-signature "$<TARGET_BUNDLE_DIR:${bundle_target}>"
            COMMAND /usr/bin/codesign --sign "${SAVERA_CODESIGN_IDENTITY}" ${SAVERA_CODESIGN_OPTIONS} "$<TARGET_BUNDLE_DIR:${bundle_target}>"
            VERBATIM)
    endif()
endforeach()
