# LicenseEmbed.cmake
#
# Public API for the license_embed_cmake utility.
#
# Macros / functions:
#   license_embed_add(NAME <id> TYPE <spdx-id> PATH <license-file>)
#   license_embed_target(TARGET <target-or-list>)
#   license_embed_enable_install()
#   license_embed_enable_build()
#   license_embed_enable_copy_now()
#   license_embed_enable_spdx([FORMAT <JSON|XML|BOTH>])
#   license_embed_enable_android()
#   license_embed_get_destinations(<out-var> MODE <install|build|configure|android>)
#
# Destination directories (all overridable via cache or -D):
#   LICENSE_EMBED_INSTALL_LICENSES_DIR  install root for license files
#   LICENSE_EMBED_INSTALL_SPDX_DIR      install root for SPDX documents
#   LICENSE_EMBED_BUILD_LICENSES_DIR    build-tree root for license files
#   LICENSE_EMBED_BUILD_SPDX_DIR        build-tree root for SPDX documents
#   LICENSE_EMBED_ANDROID_ASSETS_DIR    Android assets/license directory
#
# Options:
#   LICENSE_EMBED_ANDROID               enable/disable Android integration (ON)
#
# File layout per mode:
#   build / configure  ${LICENSE_EMBED_BUILD_LICENSES_DIR}/<NAME>/LICENSE
#   install            ${LICENSE_EMBED_INSTALL_LICENSES_DIR}/<NAME>/LICENSE
#   SPDX build         ${LICENSE_EMBED_BUILD_SPDX_DIR}/<project>.spdx.{json,xml}
#   android            ${LICENSE_EMBED_ANDROID_ASSETS_DIR}/<NAME>/LICENSE
#   SPDX install       ${LICENSE_EMBED_INSTALL_SPDX_DIR}/<project>.spdx.{json,xml}
#
# Cross-call state is held in GLOBAL properties so the API works from any
# subdirectory depth.

if(DEFINED _LICENSE_EMBED_INCLUDED)
    return()
endif()
set(_LICENSE_EMBED_INCLUDED 1)

include(GNUInstallDirs)
include("${CMAKE_CURRENT_LIST_DIR}/LicenseEmbedSPDX.cmake")

set(LICENSE_EMBED_VERSION "0.1.0")
set(LICENSE_EMBED_INSTALL_COMPONENT "LicenseEmbed" CACHE STRING
    "CPack/install component used for embedded license artifacts.")

set(LICENSE_EMBED_INSTALL_LICENSES_DIR
    "${CMAKE_INSTALL_DATAROOTDIR}/licenses"
    CACHE PATH "Install destination root for per-dependency license files.")
set(LICENSE_EMBED_INSTALL_SPDX_DIR
    "${CMAKE_INSTALL_DATAROOTDIR}/spdx"
    CACHE PATH "Install destination for SPDX SBOM documents.")
set(LICENSE_EMBED_BUILD_LICENSES_DIR
    "${CMAKE_BINARY_DIR}/licenses"
    CACHE PATH "Build-tree destination root for per-dependency license files.")
set(LICENSE_EMBED_BUILD_SPDX_DIR
    "${CMAKE_BINARY_DIR}/spdx"
    CACHE PATH "Build-tree destination for SPDX SBOM documents.")

option(LICENSE_EMBED_ANDROID
    "Copy licenses into the Android assets/license directory when targeting Android." ON)
set(LICENSE_EMBED_ANDROID_ASSETS_DIR
    "${CMAKE_BINARY_DIR}/assets/license"
    CACHE PATH "Android assets/license directory (e.g. <app>/src/main/assets/license).")

# True when cross-compiling for Android (NDK toolchain sets ANDROID / system name).
function(_license_embed_is_android OUT_VAR)
    if(ANDROID OR CMAKE_SYSTEM_NAME STREQUAL "Android")
        set(${OUT_VAR} TRUE PARENT_SCOPE)
    else()
        set(${OUT_VAR} FALSE PARENT_SCOPE)
    endif()
endfunction()

# Curated subset of common SPDX short identifiers. Unknown ids are accepted
# (with a WARNING) so that the module never blocks a valid expression that
# simply post-dates this list.
set(_LICENSE_EMBED_KNOWN_SPDX_IDS
    "MIT"
    "Apache-2.0"
    "BSD-2-Clause"
    "BSD-3-Clause"
    "GPL-2.0-only"
    "GPL-2.0-or-later"
    "GPL-3.0-only"
    "GPL-3.0-or-later"
    "LGPL-2.1-only"
    "LGPL-2.1-or-later"
    "LGPL-3.0-only"
    "LGPL-3.0-or-later"
    "AGPL-3.0-only"
    "AGPL-3.0-or-later"
    "MPL-2.0"
    "ISC"
    "Unlicense"
    "CC0-1.0"
    "CC-BY-4.0"
    "CC-BY-SA-4.0"
    "Zlib"
    "BSL-1.0"
    "EPL-2.0"
    "OpenSSL"
    "Python-2.0"
)

# Inspect a TYPE argument. Accepts compound SPDX expressions of the form
# "A OR B", "A AND B", "A WITH B". Emits a WARNING when the bare identifier
# is not in the curated set; emits FATAL_ERROR when the expression contains
# disallowed characters (e.g., pipes, which would corrupt our storage row).
function(_license_embed_validate_spdx_id TYPE_STR)
    if(TYPE_STR MATCHES "\\|")
        message(FATAL_ERROR
            "license_embed: TYPE '${TYPE_STR}' contains a forbidden '|' character.")
    endif()
    if(NOT TYPE_STR MATCHES "^[A-Za-z0-9.+-]+( (OR|AND|WITH) [A-Za-z0-9.+-]+)*$")
        message(FATAL_ERROR
            "license_embed: TYPE '${TYPE_STR}' is not a syntactically valid SPDX "
            "license expression.")
    endif()
    # Compound expression: skip membership check, defer to the consumer.
    if(TYPE_STR MATCHES " (OR|AND|WITH) ")
        return()
    endif()
    list(FIND _LICENSE_EMBED_KNOWN_SPDX_IDS "${TYPE_STR}" _idx)
    if(_idx EQUAL -1)
        message(WARNING
            "license_embed: TYPE '${TYPE_STR}' is not in the curated SPDX shortlist. "
            "Accepting as-is; verify against https://spdx.org/licenses/.")
    endif()
endfunction()

# license_embed_add(NAME <id> TYPE <spdx-id> PATH <license-file>)
macro(license_embed_add)
    set(_oneValueArgs NAME TYPE PATH)
    cmake_parse_arguments(LE_ADD "" "${_oneValueArgs}" "" ${ARGN})

    if(LE_ADD_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "license_embed_add: unexpected arguments: ${LE_ADD_UNPARSED_ARGUMENTS}")
    endif()
    foreach(_req IN ITEMS NAME TYPE PATH)
        if(NOT DEFINED LE_ADD_${_req} OR LE_ADD_${_req} STREQUAL "")
            message(FATAL_ERROR "license_embed_add: missing required argument ${_req}.")
        endif()
    endforeach()

    if(LE_ADD_NAME MATCHES "[|]")
        message(FATAL_ERROR
            "license_embed_add: NAME '${LE_ADD_NAME}' must not contain '|'.")
    endif()

    get_filename_component(_le_abs "${LE_ADD_PATH}" ABSOLUTE)
    if(NOT EXISTS "${_le_abs}")
        message(FATAL_ERROR
            "license_embed_add: PATH '${LE_ADD_PATH}' (resolved '${_le_abs}') does not exist.")
    endif()

    get_property(_le_existing GLOBAL PROPERTY LICENSE_EMBED_ENTRIES)
    foreach(_row IN LISTS _le_existing)
        string(REPLACE "|" ";" _parts "${_row}")
        list(GET _parts 0 _existing_name)
        if(_existing_name STREQUAL LE_ADD_NAME)
            message(FATAL_ERROR
                "license_embed_add: NAME '${LE_ADD_NAME}' already registered.")
        endif()
    endforeach()

    _license_embed_validate_spdx_id("${LE_ADD_TYPE}")

    set_property(GLOBAL APPEND PROPERTY LICENSE_EMBED_ENTRIES
        "${LE_ADD_NAME}|${LE_ADD_TYPE}|${_le_abs}")
endmacro()

# license_embed_target(TARGET <target-or-list>)
macro(license_embed_target)
    cmake_parse_arguments(LE_T "" "" "TARGET" ${ARGN})
    if(LE_T_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "license_embed_target: unexpected arguments: ${LE_T_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT LE_T_TARGET)
        message(FATAL_ERROR "license_embed_target: TARGET is required.")
    endif()
    foreach(_t IN LISTS LE_T_TARGET)
        if(NOT TARGET ${_t})
            message(FATAL_ERROR
                "license_embed_target: '${_t}' is not an existing target.")
        endif()
        set_property(GLOBAL APPEND PROPERTY LICENSE_EMBED_TARGETS "${_t}")
    endforeach()
endmacro()

# license_embed_enable_install()
macro(license_embed_enable_install)
    get_property(_le_entries GLOBAL PROPERTY LICENSE_EMBED_ENTRIES)
    if(NOT _le_entries)
        message(WARNING
            "license_embed_enable_install: no entries registered; nothing to install.")
    endif()
    foreach(_row IN LISTS _le_entries)
        string(REPLACE "|" ";" _parts "${_row}")
        list(GET _parts 0 _name)
        list(GET _parts 2 _path)
        install(FILES "${_path}"
            DESTINATION "${LICENSE_EMBED_INSTALL_LICENSES_DIR}/${_name}"
            RENAME LICENSE
            COMPONENT ${LICENSE_EMBED_INSTALL_COMPONENT})
    endforeach()

    get_property(_le_spdx_on GLOBAL PROPERTY LICENSE_EMBED_SPDX_ENABLED)
    if(_le_spdx_on)
        get_property(_le_fmt GLOBAL PROPERTY LICENSE_EMBED_SPDX_FORMAT)
        if(_le_fmt STREQUAL "JSON" OR _le_fmt STREQUAL "BOTH")
            install(FILES
                    "${LICENSE_EMBED_BUILD_SPDX_DIR}/${PROJECT_NAME}.spdx.json"
                DESTINATION "${LICENSE_EMBED_INSTALL_SPDX_DIR}"
                COMPONENT ${LICENSE_EMBED_INSTALL_COMPONENT})
        endif()
        if(_le_fmt STREQUAL "XML" OR _le_fmt STREQUAL "BOTH")
            install(FILES
                    "${LICENSE_EMBED_BUILD_SPDX_DIR}/${PROJECT_NAME}.spdx.xml"
                DESTINATION "${LICENSE_EMBED_INSTALL_SPDX_DIR}"
                COMPONENT ${LICENSE_EMBED_INSTALL_COMPONENT})
        endif()
    endif()

    set_property(GLOBAL PROPERTY LICENSE_EMBED_INSTALL_ENABLED TRUE)
endmacro()

# license_embed_enable_build()
# Copies license files into the build tree at build time via custom commands.
macro(license_embed_enable_build)
    get_property(_le_entries GLOBAL PROPERTY LICENSE_EMBED_ENTRIES)
    if(NOT _le_entries)
        message(WARNING
            "license_embed_enable_build: no entries registered; nothing to copy.")
    endif()

    set(_le_outputs "")
    foreach(_row IN LISTS _le_entries)
        string(REPLACE "|" ";" _parts "${_row}")
        list(GET _parts 0 _name)
        list(GET _parts 2 _path)
        set(_out "${LICENSE_EMBED_BUILD_LICENSES_DIR}/${_name}/LICENSE")
        add_custom_command(
            OUTPUT  "${_out}"
            COMMAND ${CMAKE_COMMAND} -E make_directory
                    "${LICENSE_EMBED_BUILD_LICENSES_DIR}/${_name}"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${_path}" "${_out}"
            DEPENDS "${_path}"
            COMMENT "Embedding license for ${_name}"
            VERBATIM)
        list(APPEND _le_outputs "${_out}")
    endforeach()

    set(_le_drv "license_embed_${PROJECT_NAME}")
    if(NOT TARGET ${_le_drv})
        add_custom_target(${_le_drv} ALL DEPENDS ${_le_outputs})
    else()
        # Reconfigure path: append new outputs as additional dependencies.
        add_custom_target(${_le_drv}_refresh DEPENDS ${_le_outputs})
        add_dependencies(${_le_drv} ${_le_drv}_refresh)
    endif()

    get_property(_le_targets GLOBAL PROPERTY LICENSE_EMBED_TARGETS)
    foreach(_t IN LISTS _le_targets)
        add_dependencies(${_t} ${_le_drv})
    endforeach()

    set_property(GLOBAL PROPERTY LICENSE_EMBED_BUILD_ENABLED TRUE)
endmacro()

# license_embed_enable_copy_now()
# Copies license files immediately at CMake configure time using configure_file
# (COPYONLY). Because configure_file tracks source dependencies, CMake will
# automatically reconfigure when any registered license file changes.
# Call license_embed_enable_spdx() before this macro if you want SPDX documents
# to be present at the same location right after configure.
macro(license_embed_enable_copy_now)
    get_property(_le_entries GLOBAL PROPERTY LICENSE_EMBED_ENTRIES)
    if(NOT _le_entries)
        message(WARNING
            "license_embed_enable_copy_now: no entries registered; nothing to copy.")
    endif()
    foreach(_row IN LISTS _le_entries)
        string(REPLACE "|" ";" _parts "${_row}")
        list(GET _parts 0 _name)
        list(GET _parts 2 _path)
        set(_dest_dir "${LICENSE_EMBED_BUILD_LICENSES_DIR}/${_name}")
        file(MAKE_DIRECTORY "${_dest_dir}")
        configure_file("${_path}" "${_dest_dir}/LICENSE" COPYONLY)
    endforeach()

    get_property(_le_spdx_on GLOBAL PROPERTY LICENSE_EMBED_SPDX_ENABLED)
    if(_le_spdx_on)
        message(STATUS
            "license_embed_enable_copy_now: SPDX documents already present "
            "at '${LICENSE_EMBED_BUILD_SPDX_DIR}'.")
    endif()

    set_property(GLOBAL PROPERTY LICENSE_EMBED_COPY_NOW_ENABLED TRUE)
endmacro()

# license_embed_enable_spdx([FORMAT <JSON|XML|BOTH>])
# Writes SPDX 2.3 SBOM document(s) at configure time.
# FORMAT defaults to BOTH when omitted (backward-compatible).
macro(license_embed_enable_spdx)
    cmake_parse_arguments(LE_SPDX "" "FORMAT" "" ${ARGN})
    if(NOT DEFINED LE_SPDX_FORMAT OR LE_SPDX_FORMAT STREQUAL "")
        set(LE_SPDX_FORMAT "BOTH")
    endif()
    if(NOT LE_SPDX_FORMAT MATCHES "^(JSON|XML|BOTH)$")
        message(FATAL_ERROR
            "license_embed_enable_spdx: FORMAT must be JSON, XML, or BOTH "
            "(got '${LE_SPDX_FORMAT}').")
    endif()
    set_property(GLOBAL PROPERTY LICENSE_EMBED_SPDX_FORMAT "${LE_SPDX_FORMAT}")

    get_property(_le_entries GLOBAL PROPERTY LICENSE_EMBED_ENTRIES)
    if(NOT _le_entries)
        message(WARNING
            "license_embed_enable_spdx: no entries registered; SPDX document not written.")
    else()
        set(_le_seed "${PROJECT_NAME}-${PROJECT_VERSION}")
        _license_embed_uuid(_le_uuid "${_le_seed}")
        set(_le_ns
            "https://spdx.org/spdxdocs/${PROJECT_NAME}-${PROJECT_VERSION}-${_le_uuid}")
        set_property(GLOBAL PROPERTY LICENSE_EMBED_DOC_NAMESPACE "${_le_ns}")

        file(MAKE_DIRECTORY "${LICENSE_EMBED_BUILD_SPDX_DIR}")
        if(LE_SPDX_FORMAT STREQUAL "JSON" OR LE_SPDX_FORMAT STREQUAL "BOTH")
            _license_embed_write_spdx_json(
                "${LICENSE_EMBED_BUILD_SPDX_DIR}/${PROJECT_NAME}.spdx.json"
                "${PROJECT_NAME}" "${PROJECT_VERSION}" "${LICENSE_EMBED_VERSION}"
                "${_le_ns}" _le_entries)
        endif()
        if(LE_SPDX_FORMAT STREQUAL "XML" OR LE_SPDX_FORMAT STREQUAL "BOTH")
            _license_embed_write_spdx_xml(
                "${LICENSE_EMBED_BUILD_SPDX_DIR}/${PROJECT_NAME}.spdx.xml"
                "${PROJECT_NAME}" "${PROJECT_VERSION}" "${LICENSE_EMBED_VERSION}"
                "${_le_ns}" _le_entries)
        endif()
    endif()
    set_property(GLOBAL PROPERTY LICENSE_EMBED_SPDX_ENABLED TRUE)
endmacro()

# license_embed_enable_android()
# When targeting Android (detected via ANDROID / CMAKE_SYSTEM_NAME) and
# LICENSE_EMBED_ANDROID is ON, copies every registered license at configure
# time to ${LICENSE_EMBED_ANDROID_ASSETS_DIR}/<NAME>/LICENSE. No-op otherwise.
macro(license_embed_enable_android)
    _license_embed_is_android(_le_is_android)
    if(NOT LICENSE_EMBED_ANDROID)
        message(STATUS "license_embed_enable_android: disabled (LICENSE_EMBED_ANDROID=OFF).")
    elseif(NOT _le_is_android)
        message(STATUS "license_embed_enable_android: not targeting Android; skipping.")
    else()
        get_property(_le_entries GLOBAL PROPERTY LICENSE_EMBED_ENTRIES)
        if(NOT _le_entries)
            message(WARNING
                "license_embed_enable_android: no entries registered; nothing to copy.")
        endif()
        foreach(_row IN LISTS _le_entries)
            string(REPLACE "|" ";" _parts "${_row}")
            list(GET _parts 0 _name)
            list(GET _parts 2 _path)
            set(_dest_dir "${LICENSE_EMBED_ANDROID_ASSETS_DIR}/${_name}")
            file(MAKE_DIRECTORY "${_dest_dir}")
            configure_file("${_path}" "${_dest_dir}/LICENSE" COPYONLY)
        endforeach()
        set_property(GLOBAL PROPERTY LICENSE_EMBED_ANDROID_ENABLED TRUE)
    endif()
endmacro()

# license_embed_get_destinations(<out-var> MODE <install|build|configure|android>)
# Returns the list of absolute paths where registered licenses would land for
# the given mode. "configure" maps to the same directory as "build" (both use
# LICENSE_EMBED_BUILD_LICENSES_DIR).
function(license_embed_get_destinations OUT_VAR)
    cmake_parse_arguments(LE_GD "" "MODE" "" ${ARGN})
    if(NOT DEFINED LE_GD_MODE OR LE_GD_MODE STREQUAL "")
        message(FATAL_ERROR "license_embed_get_destinations: MODE is required.")
    endif()
    if(NOT LE_GD_MODE MATCHES "^(install|build|configure|android)$")
        message(FATAL_ERROR
            "license_embed_get_destinations: unknown MODE '${LE_GD_MODE}'. "
            "Use install, build, configure, or android.")
    endif()

    if(LE_GD_MODE STREQUAL "install")
        set(_base "${LICENSE_EMBED_INSTALL_LICENSES_DIR}")
    elseif(LE_GD_MODE STREQUAL "android")
        set(_base "${LICENSE_EMBED_ANDROID_ASSETS_DIR}")
    else()
        set(_base "${LICENSE_EMBED_BUILD_LICENSES_DIR}")
    endif()

    get_property(_le_entries GLOBAL PROPERTY LICENSE_EMBED_ENTRIES)
    set(_result "")
    foreach(_row IN LISTS _le_entries)
        string(REPLACE "|" ";" _parts "${_row}")
        list(GET _parts 0 _name)
        list(APPEND _result "${_base}/${_name}/LICENSE")
    endforeach()
    set(${OUT_VAR} "${_result}" PARENT_SCOPE)
endfunction()
