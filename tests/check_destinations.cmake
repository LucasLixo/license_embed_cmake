# Standalone cmake -P script that verifies license_embed_get_destinations().
# Required input variables (passed via -D on the command line):
#   DEMO_SRC        path to examples/demo source dir
#   EXPECTED_BASE   expected base directory for MODE install
#   EXPECTED_NAMES  semicolon-separated list of NAME values registered

cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED DEMO_SRC)
    message(FATAL_ERROR "check_destinations: DEMO_SRC is required.")
endif()
if(NOT DEFINED EXPECTED_BASE)
    message(FATAL_ERROR "check_destinations: EXPECTED_BASE is required.")
endif()
if(NOT DEFINED EXPECTED_NAMES)
    message(FATAL_ERROR "check_destinations: EXPECTED_NAMES is required.")
endif()

include("${DEMO_SRC}/../../cmake/LicenseEmbed.cmake")

# Register the same entries as the demo uses.
license_embed_add(NAME zlib       TYPE Zlib    PATH "${DEMO_SRC}/third_party/zlib/LICENSE")
license_embed_add(NAME fmt        TYPE MIT     PATH "${DEMO_SRC}/third_party/fmt/LICENSE")
license_embed_add(NAME boost-asio TYPE BSL-1.0 PATH "${DEMO_SRC}/third_party/asio/LICENSE_1_0.txt")

license_embed_get_destinations(_dests MODE install)

set(_expected_list "${EXPECTED_NAMES}")
list(LENGTH _expected_list _expected_count)
list(LENGTH _dests _actual_count)

if(NOT _actual_count EQUAL _expected_count)
    message(FATAL_ERROR
        "check_destinations: expected ${_expected_count} destinations, "
        "got ${_actual_count}: ${_dests}")
endif()

foreach(_name IN LISTS _expected_list)
    set(_expected_path "${EXPECTED_BASE}/${_name}/LICENSE.txt")
    list(FIND _dests "${_expected_path}" _idx)
    if(_idx EQUAL -1)
        message(FATAL_ERROR
            "check_destinations: '${_expected_path}' not found in returned list: ${_dests}")
    endif()
endforeach()

message(STATUS "check_destinations: all expected install destinations verified.")
