cmake_minimum_required(VERSION 3.24)

project(airwindohhs_godot VERSION 0.1.0 LANGUAGES CXX)

include(CTest)
include(FetchContent)

option(AIRWINDOHHS_GODOT_BUILD_EXTENSION "Build the Godot GDExtension" ON)
option(AIRWINDOHHS_GODOT_BUILD_TESTS "Build tests" ON)
option(AIRWINDOHHS_GODOT_WARNINGS_AS_ERRORS "Treat warnings as errors" OFF)
set(AIRWINDOHHS_GODOT_GODOT_CPP_PATH "" CACHE PATH "Existing godot-cpp checkout")
set(AIRWINDOHHS_GODOT_AIRWINDOHHS_PATH "" CACHE PATH "Existing airwindohhs checkout")
set(AIRWINDOHHS_GODOT_GODOT_EXECUTABLE "" CACHE FILEPATH "Godot 4.6 executable for smoke tests")

if(NOT AIRWINDOHHS_GODOT_AIRWINDOHHS_PATH)
    get_filename_component(_sibling_airwindohhs "${CMAKE_CURRENT_SOURCE_DIR}/../airwindohhs" ABSOLUTE)
    if(EXISTS "${_sibling_airwindohhs}/CMakeLists.txt")
        set(AIRWINDOHHS_GODOT_AIRWINDOHHS_PATH "${_sibling_airwindohhs}")
    endif()
endif()

add_library(airwindohhs_godot_parameter_state INTERFACE)
target_include_directories(airwindohhs_godot_parameter_state INTERFACE
    "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_compile_features(airwindohhs_godot_parameter_state INTERFACE cxx_std_17)

find_package(Python3 3.9 COMPONENTS Interpreter REQUIRED)
add_custom_target(regenerate_catalog
    COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tools/generate_catalog.py"
        --airwindohhs "${AIRWINDOHHS_GODOT_AIRWINDOHHS_PATH}"
        --output "${CMAKE_CURRENT_SOURCE_DIR}/generated"
        --exclusions "${CMAKE_CURRENT_SOURCE_DIR}/config/exclusions.json"
        --parameter-overrides "${CMAKE_CURRENT_SOURCE_DIR}/config/parameter_overrides.json"
        --shards 16
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    COMMENT "Regenerating the Godot effect catalog")

if(AIRWINDOHHS_GODOT_BUILD_TESTS)
    add_executable(parameter_state_tests tests/test_parameter_state.cpp)
    target_link_libraries(parameter_state_tests PRIVATE airwindohhs_godot_parameter_state)
    target_compile_features(parameter_state_tests PRIVATE cxx_std_17)
    add_test(NAME parameter_state_tests COMMAND parameter_state_tests)
    add_test(NAME catalog_generator_tests
        COMMAND "${Python3_EXECUTABLE}" -m unittest tests/test_generate_catalog.py)
    set_tests_properties(catalog_generator_tests PROPERTIES
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
    add_test(NAME demo_activation_tests
        COMMAND "${Python3_EXECUTABLE}" -m unittest tests/test_demo_activation.py)
    set_tests_properties(demo_activation_tests PROPERTIES
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
endif()

if(AIRWINDOHHS_GODOT_BUILD_EXTENSION)
    set(GODOTCPP_API_VERSION "4.6" CACHE STRING "Godot API target" FORCE)
    set(GODOTCPP_BUILD_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/config/godot_cpp_profile.json"
        CACHE PATH "Minimal godot-cpp build profile" FORCE)
    if(AIRWINDOHHS_GODOT_GODOT_CPP_PATH)
        add_subdirectory("${AIRWINDOHHS_GODOT_GODOT_CPP_PATH}"
            "${CMAKE_CURRENT_BINARY_DIR}/godot-cpp" EXCLUDE_FROM_ALL)
    else()
        FetchContent_Declare(godot-cpp
            GIT_REPOSITORY https://github.com/godotengine/godot-cpp.git
            GIT_TAG ba0edfed90512ec64aba51d4295a3e7e30112f86)
        FetchContent_MakeAvailable(godot-cpp)
    endif()

    if(AIRWINDOHHS_GODOT_AIRWINDOHHS_PATH)
        add_subdirectory("${AIRWINDOHHS_GODOT_AIRWINDOHHS_PATH}"
            "${CMAKE_CURRENT_BINARY_DIR}/airwindohhs" EXCLUDE_FROM_ALL)
    else()
        FetchContent_Declare(airwindohhs
            GIT_REPOSITORY https://github.com/jinpavg/airwindohhs.git
            GIT_TAG main)
        FetchContent_MakeAvailable(airwindohhs)
        set(AIRWINDOHHS_GODOT_AIRWINDOHHS_PATH "${airwindohhs_SOURCE_DIR}")
    endif()

    include(generated/sources.cmake)
    add_library(airwindohhs_godot SHARED
        src/audio_effect.cpp
        src/register_types.cpp
        ${AIRWINDOHHS_GODOT_GENERATED_SOURCES})
    target_link_libraries(airwindohhs_godot PRIVATE godot-cpp Airwindohhs::Airwindohhs)
    target_include_directories(airwindohhs_godot PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/include"
        "${CMAKE_CURRENT_SOURCE_DIR}/generated")
    target_include_directories(airwindohhs_godot SYSTEM PRIVATE
        "${AIRWINDOHHS_GODOT_AIRWINDOHHS_PATH}/include")
    target_compile_features(airwindohhs_godot PRIVATE cxx_std_17)

    if(MSVC)
        target_compile_options(airwindohhs_godot PRIVATE /W4)
        if(AIRWINDOHHS_GODOT_WARNINGS_AS_ERRORS)
            target_compile_options(airwindohhs_godot PRIVATE /WX)
        endif()
    else()
        target_compile_options(airwindohhs_godot PRIVATE
            -Wall -Wextra -Wpedantic
            -Wno-unused-parameter
            -Wno-gnu-anonymous-struct
            -Wno-nested-anon-types)
        if(AIRWINDOHHS_GODOT_WARNINGS_AS_ERRORS)
            target_compile_options(airwindohhs_godot PRIVATE -Werror)
        endif()
    endif()

    set(_addon_bin "${CMAKE_CURRENT_SOURCE_DIR}/demo/addons/airwindohhs_godot/bin")
    if(APPLE)
        set(_platform "macos")
    elseif(WIN32)
        set(_platform "windows")
    else()
        set(_platform "linux")
    endif()
    set_target_properties(airwindohhs_godot PROPERTIES
        LIBRARY_OUTPUT_DIRECTORY "${_addon_bin}"
        RUNTIME_OUTPUT_DIRECTORY "${_addon_bin}"
        OUTPUT_NAME "airwindohhs_godot.${_platform}.$<IF:$<CONFIG:Debug>,template_debug,template_release>")
    set(_extension_descriptor
        "${CMAKE_CURRENT_SOURCE_DIR}/demo/addons/airwindohhs_godot/airwindohhs_godot.gdextension")
    add_custom_command(TARGET airwindohhs_godot POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${CMAKE_CURRENT_SOURCE_DIR}/demo/addons/airwindohhs_godot/airwindohhs_godot.gdextension.in"
            "${_extension_descriptor}"
        COMMENT "Activating the demo GDExtension after its library was built")
    set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_CLEAN_FILES "${_extension_descriptor}")
    configure_file(generated/catalog.json
        "${CMAKE_CURRENT_SOURCE_DIR}/demo/addons/airwindohhs_godot/catalog.json" COPYONLY)

    if(AIRWINDOHHS_GODOT_BUILD_TESTS)
        include(generated/validation_sources.cmake)
        add_executable(catalog_validation
            tests/catalog_validation_main.cpp
            ${AIRWINDOHHS_GODOT_VALIDATION_SOURCES})
        target_link_libraries(catalog_validation PRIVATE Airwindohhs::Airwindohhs)
        target_include_directories(catalog_validation PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/tests")
        target_include_directories(catalog_validation SYSTEM PRIVATE
            "${AIRWINDOHHS_GODOT_AIRWINDOHHS_PATH}/include")
        if(NOT MSVC)
            target_compile_options(catalog_validation PRIVATE -Wno-unused-value)
        endif()
        target_compile_features(catalog_validation PRIVATE cxx_std_17)
        add_test(NAME catalog_validation COMMAND catalog_validation)
        if(AIRWINDOHHS_GODOT_GODOT_EXECUTABLE)
            add_test(NAME godot_smoke
                COMMAND "${AIRWINDOHHS_GODOT_GODOT_EXECUTABLE}" --headless
                    --log-file "${CMAKE_CURRENT_BINARY_DIR}/godot-smoke.log"
                    --path "${CMAKE_CURRENT_SOURCE_DIR}/demo"
                    --script res://tests/smoke_test.gd)
        endif()
    endif()
endif()
