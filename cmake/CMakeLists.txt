cmake_minimum_required(VERSION 3.21)
project(savera VERSION 0.0.0 LANGUAGES C CXX OBJC OBJCXX)

set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0" CACHE STRING "Minimum macOS version")
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CLAP_WRAPPER_DOWNLOAD_DEPENDENCIES TRUE CACHE BOOL "")
set(PRODUCT_NAME "Savera")
set(REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/..")

include(FetchContent)
FetchContent_Declare(clap-wrapper GIT_REPOSITORY https://github.com/free-audio/clap-wrapper.git GIT_TAG 1cca996e96f29ab2be7ae9f8cfe532bbc92e1dd6)
FetchContent_MakeAvailable(clap-wrapper)

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
