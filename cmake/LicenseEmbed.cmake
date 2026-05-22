# LicenseEmbed.cmake
#
# Public API for the license_embed_cmake utility.
#
# Macros:
#   license_embed_add(NAME <id> TYPE <spdx-id> PATH <license-file>)
#   license_embed_target(TARGET <target-or-list>)
#   license_embed_enable_install()
#   license_embed_enable_build()
#   license_embed_enable_spdx()
#
# Conventions:
#   - Build-tree mirror lives at  ${CMAKE_BINARY_DIR}/licenses/<NAME>/LICENSE
#   - Install layout is           ${CMAKE_INSTALL_DATAROOTDIR}/licenses/<NAME>/LICENSE
#     (Arch / Fedora style; works cross-platform).
#   - SPDX documents land at      ${CMAKE_BINARY_DIR}/spdx/<project>.spdx.{json,xml}
#     and install to              ${CMAKE_INSTALL_DATAROOTDIR}/spdx/.
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
            DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/licenses/${_name}"
            RENAME LICENSE
            COMPONENT ${LICENSE_EMBED_INSTALL_COMPONENT})
    endforeach()

    get_property(_le_spdx_on GLOBAL PROPERTY LICENSE_EMBED_SPDX_ENABLED)
    if(_le_spdx_on)
        install(FILES
                "${CMAKE_BINARY_DIR}/spdx/${PROJECT_NAME}.spdx.json"
                "${CMAKE_BINARY_DIR}/spdx/${PROJECT_NAME}.spdx.xml"
            DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/spdx"
            COMPONENT ${LICENSE_EMBED_INSTALL_COMPONENT})
    endif()

    set_property(GLOBAL PROPERTY LICENSE_EMBED_INSTALL_ENABLED TRUE)
endmacro()

# license_embed_enable_build()
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
        set(_out "${CMAKE_BINARY_DIR}/licenses/${_name}/LICENSE")
        add_custom_command(
            OUTPUT  "${_out}"
            COMMAND ${CMAKE_COMMAND} -E make_directory
                    "${CMAKE_BINARY_DIR}/licenses/${_name}"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${_path}" "${_out}"
            DEPENDS "${_path}"
            COMMENT "Embedding license for ${_name}"
            VERBATIM)
        list(APPEND _le_outputs "${_out}")
    endforeach()

    get_property(_le_spdx_on GLOBAL PROPERTY LICENSE_EMBED_SPDX_ENABLED)
    if(_le_spdx_on)
        foreach(_ext IN ITEMS json xml)
            set(_src "${CMAKE_BINARY_DIR}/spdx/${PROJECT_NAME}.spdx.${_ext}")
            set(_dst "${CMAKE_BINARY_DIR}/licenses/_spdx/${PROJECT_NAME}.spdx.${_ext}")
            add_custom_command(
                OUTPUT  "${_dst}"
                COMMAND ${CMAKE_COMMAND} -E make_directory
                        "${CMAKE_BINARY_DIR}/licenses/_spdx"
                COMMAND ${CMAKE_COMMAND} -E copy_if_different "${_src}" "${_dst}"
                DEPENDS "${_src}"
                COMMENT "Embedding SPDX ${_ext} for ${PROJECT_NAME}"
                VERBATIM)
            list(APPEND _le_outputs "${_dst}")
        endforeach()
    endif()

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

# license_embed_enable_spdx()
# Writes SPDX 2.3 JSON + XML documents at configure time.
macro(license_embed_enable_spdx)
    get_property(_le_entries GLOBAL PROPERTY LICENSE_EMBED_ENTRIES)
    if(NOT _le_entries)
        message(WARNING
            "license_embed_enable_spdx: no entries registered; SPDX document not written.")
    else()
        set(_le_seed "${PROJECT_NAME}-${PROJECT_VERSION}")
        _license_embed_uuid(_le_uuid "${_le_seed}")
        set(_le_ns "https://spdx.org/spdxdocs/${PROJECT_NAME}-${PROJECT_VERSION}-${_le_uuid}")
        set_property(GLOBAL PROPERTY LICENSE_EMBED_DOC_NAMESPACE "${_le_ns}")

        file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/spdx")
        _license_embed_write_spdx_json(
            "${CMAKE_BINARY_DIR}/spdx/${PROJECT_NAME}.spdx.json"
            "${PROJECT_NAME}" "${PROJECT_VERSION}" "${LICENSE_EMBED_VERSION}"
            "${_le_ns}" _le_entries)
        _license_embed_write_spdx_xml(
            "${CMAKE_BINARY_DIR}/spdx/${PROJECT_NAME}.spdx.xml"
            "${PROJECT_NAME}" "${PROJECT_VERSION}" "${LICENSE_EMBED_VERSION}"
            "${_le_ns}" _le_entries)
    endif()
    set_property(GLOBAL PROPERTY LICENSE_EMBED_SPDX_ENABLED TRUE)
endmacro()
