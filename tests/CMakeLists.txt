# CTest harness for license_embed_cmake.
#
# Each scenario drives an isolated sub-build of the example demo project and
# inspects the resulting tree. Python is used for SPDX document validation.

find_package(Python3 COMPONENTS Interpreter)

set(_LE_DEMO_SRC "${CMAKE_SOURCE_DIR}/examples/demo")

# ---------------------------------------------------------------------------
# Helper macro: define a configure+build+install sequence for a named scenario.
#   scenario_name   : short identifier used to name the build/stage dirs
#   extra_cmake_args: list of -D options forwarded to the sub-configure
# ---------------------------------------------------------------------------
macro(_le_scenario scenario_name)
    set(_build "${CMAKE_BINARY_DIR}/tests/${scenario_name}-build")
    set(_stage "${CMAKE_BINARY_DIR}/tests/${scenario_name}-stage")

    add_test(NAME "license_embed.${scenario_name}.configure"
        COMMAND ${CMAKE_COMMAND}
            -S "${_LE_DEMO_SRC}"
            -B "${_build}"
            -DCMAKE_INSTALL_PREFIX=${_stage}
            ${ARGN})

    add_test(NAME "license_embed.${scenario_name}.build"
        COMMAND ${CMAKE_COMMAND} --build "${_build}")
    set_tests_properties("license_embed.${scenario_name}.build" PROPERTIES
        DEPENDS "license_embed.${scenario_name}.configure")

    add_test(NAME "license_embed.${scenario_name}.install"
        COMMAND ${CMAKE_COMMAND} --install "${_build}" --prefix "${_stage}")
    set_tests_properties("license_embed.${scenario_name}.install" PROPERTIES
        DEPENDS "license_embed.${scenario_name}.build")
endmacro()

# ---------------------------------------------------------------------------
# Scenario: default (SPDX BOTH, build-time copy, install)
# ---------------------------------------------------------------------------
set(_LE_DEMO_BUILD "${CMAKE_BINARY_DIR}/tests/demo-build")
set(_LE_DEMO_STAGE "${CMAKE_BINARY_DIR}/tests/demo-stage")
_le_scenario(demo)

# Check build-tree mirror artifacts.
add_test(NAME license_embed.check_build_tree
    COMMAND ${CMAKE_COMMAND}
        -DEXPECTED=${_LE_DEMO_BUILD}/licenses/zlib/LICENSE
        -DEXPECTED2=${_LE_DEMO_BUILD}/licenses/fmt/LICENSE
        -DEXPECTED3=${_LE_DEMO_BUILD}/licenses/boost-asio/LICENSE
        -DEXPECTED4=${_LE_DEMO_BUILD}/spdx/myapp.spdx.json
        -DEXPECTED5=${_LE_DEMO_BUILD}/spdx/myapp.spdx.xml
        -P "${CMAKE_CURRENT_SOURCE_DIR}/assert_exists.cmake")
set_tests_properties(license_embed.check_build_tree PROPERTIES
    DEPENDS license_embed.demo.build)

# Check install tree.
add_test(NAME license_embed.check_install_tree
    COMMAND ${CMAKE_COMMAND}
        -DEXPECTED=${_LE_DEMO_STAGE}/share/licenses/zlib/LICENSE
        -DEXPECTED2=${_LE_DEMO_STAGE}/share/licenses/fmt/LICENSE
        -DEXPECTED3=${_LE_DEMO_STAGE}/share/licenses/boost-asio/LICENSE
        -DEXPECTED4=${_LE_DEMO_STAGE}/share/spdx/myapp.spdx.json
        -DEXPECTED5=${_LE_DEMO_STAGE}/share/spdx/myapp.spdx.xml
        -P "${CMAKE_CURRENT_SOURCE_DIR}/assert_exists.cmake")
set_tests_properties(license_embed.check_install_tree PROPERTIES
    DEPENDS license_embed.demo.install)

if(Python3_Interpreter_FOUND)
    add_test(NAME license_embed.validate_spdx_json
        COMMAND ${Python3_EXECUTABLE} -m json.tool
                "${_LE_DEMO_STAGE}/share/spdx/myapp.spdx.json")
    set_tests_properties(license_embed.validate_spdx_json PROPERTIES
        DEPENDS license_embed.demo.install)

    add_test(NAME license_embed.validate_spdx_xml
        COMMAND ${Python3_EXECUTABLE} -c
                "import xml.etree.ElementTree as ET, sys; ET.parse(sys.argv[1])"
                "${_LE_DEMO_STAGE}/share/spdx/myapp.spdx.xml")
    set_tests_properties(license_embed.validate_spdx_xml PROPERTIES
        DEPENDS license_embed.demo.install)
endif()

# ---------------------------------------------------------------------------
# Scenario: SPDX JSON only — .spdx.json must exist, .spdx.xml must be absent.
# ---------------------------------------------------------------------------
set(_LE_SPDX_JSON_BUILD "${CMAKE_BINARY_DIR}/tests/spdx-json-build")
set(_LE_SPDX_JSON_STAGE "${CMAKE_BINARY_DIR}/tests/spdx-json-stage")
_le_scenario(spdx-json -DDEMO_SPDX_FORMAT=JSON)

add_test(NAME license_embed.spdx_json_only.check_present
    COMMAND ${CMAKE_COMMAND}
        -DEXPECTED=${_LE_SPDX_JSON_STAGE}/share/spdx/myapp.spdx.json
        -P "${CMAKE_CURRENT_SOURCE_DIR}/assert_exists.cmake")
set_tests_properties(license_embed.spdx_json_only.check_present PROPERTIES
    DEPENDS license_embed.spdx-json.install)

add_test(NAME license_embed.spdx_json_only.check_absent
    COMMAND ${CMAKE_COMMAND}
        -DEXPECTED=${_LE_SPDX_JSON_STAGE}/share/spdx/myapp.spdx.xml
        -P "${CMAKE_CURRENT_SOURCE_DIR}/assert_not_exists.cmake")
set_tests_properties(license_embed.spdx_json_only.check_absent PROPERTIES
    DEPENDS license_embed.spdx-json.install)

# ---------------------------------------------------------------------------
# Scenario: SPDX XML only — .spdx.xml must exist, .spdx.json must be absent.
# ---------------------------------------------------------------------------
set(_LE_SPDX_XML_BUILD "${CMAKE_BINARY_DIR}/tests/spdx-xml-build")
set(_LE_SPDX_XML_STAGE "${CMAKE_BINARY_DIR}/tests/spdx-xml-stage")
_le_scenario(spdx-xml -DDEMO_SPDX_FORMAT=XML)

add_test(NAME license_embed.spdx_xml_only.check_present
    COMMAND ${CMAKE_COMMAND}
        -DEXPECTED=${_LE_SPDX_XML_STAGE}/share/spdx/myapp.spdx.xml
        -P "${CMAKE_CURRENT_SOURCE_DIR}/assert_exists.cmake")
set_tests_properties(license_embed.spdx_xml_only.check_present PROPERTIES
    DEPENDS license_embed.spdx-xml.install)

add_test(NAME license_embed.spdx_xml_only.check_absent
    COMMAND ${CMAKE_COMMAND}
        -DEXPECTED=${_LE_SPDX_XML_STAGE}/share/spdx/myapp.spdx.json
        -P "${CMAKE_CURRENT_SOURCE_DIR}/assert_not_exists.cmake")
set_tests_properties(license_embed.spdx_xml_only.check_absent PROPERTIES
    DEPENDS license_embed.spdx-xml.install)

# ---------------------------------------------------------------------------
# Scenario: copy_now — license files exist right after configure, no build.
# ---------------------------------------------------------------------------
set(_LE_COPY_NOW_BUILD "${CMAKE_BINARY_DIR}/tests/copy-now-build")

add_test(NAME license_embed.copy_now.configure
    COMMAND ${CMAKE_COMMAND}
        -S "${_LE_DEMO_SRC}"
        -B "${_LE_COPY_NOW_BUILD}"
        -DDEMO_ENABLE_COPY_NOW=ON
        -DDEMO_ENABLE_BUILD=OFF)

add_test(NAME license_embed.copy_now.check_no_build_needed
    COMMAND ${CMAKE_COMMAND}
        -DEXPECTED=${_LE_COPY_NOW_BUILD}/licenses/zlib/LICENSE
        -DEXPECTED2=${_LE_COPY_NOW_BUILD}/licenses/fmt/LICENSE
        -DEXPECTED3=${_LE_COPY_NOW_BUILD}/licenses/boost-asio/LICENSE
        -DEXPECTED4=${_LE_COPY_NOW_BUILD}/spdx/myapp.spdx.json
        -DEXPECTED5=${_LE_COPY_NOW_BUILD}/spdx/myapp.spdx.xml
        -P "${CMAKE_CURRENT_SOURCE_DIR}/assert_exists.cmake")
set_tests_properties(license_embed.copy_now.check_no_build_needed PROPERTIES
    DEPENDS license_embed.copy_now.configure)

# ---------------------------------------------------------------------------
# Scenario: get_destinations — run as cmake -P script, no sub-build required.
# ---------------------------------------------------------------------------
set(_LE_INSTALL_DIR "${CMAKE_INSTALL_DATAROOTDIR}/licenses")
add_test(NAME license_embed.get_destinations
    COMMAND ${CMAKE_COMMAND}
        -DDEMO_SRC=${_LE_DEMO_SRC}
        "-DEXPECTED_BASE=${_LE_INSTALL_DIR}"
        "-DEXPECTED_NAMES=zlib;fmt;boost-asio"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/check_destinations.cmake")

# ---------------------------------------------------------------------------
# Scenario: custom build licenses dir.
# ---------------------------------------------------------------------------
set(_LE_CUSTOM_DIR  "${CMAKE_BINARY_DIR}/tests/custom_licenses")
set(_LE_CUSTOM_BUILD "${CMAKE_BINARY_DIR}/tests/custom-dir-build")
_le_scenario(custom-dir
    "-DLICENSE_EMBED_BUILD_LICENSES_DIR=${_LE_CUSTOM_DIR}")

add_test(NAME license_embed.custom_build_dir.check
    COMMAND ${CMAKE_COMMAND}
        -DEXPECTED=${_LE_CUSTOM_DIR}/zlib/LICENSE
        -DEXPECTED2=${_LE_CUSTOM_DIR}/fmt/LICENSE
        -DEXPECTED3=${_LE_CUSTOM_DIR}/boost-asio/LICENSE
        -P "${CMAKE_CURRENT_SOURCE_DIR}/assert_exists.cmake")
set_tests_properties(license_embed.custom_build_dir.check PROPERTIES
    DEPENDS license_embed.custom-dir.build)

# ---------------------------------------------------------------------------
# Scenario: Android — assets/license populated when ANDROID is set.
# ---------------------------------------------------------------------------
set(_LE_ANDROID_BUILD "${CMAKE_BINARY_DIR}/tests/android-build")
set(_LE_ANDROID_OFF_BUILD "${CMAKE_BINARY_DIR}/tests/android-off-build")

add_test(NAME license_embed.android.configure
    COMMAND ${CMAKE_COMMAND} -S "${_LE_DEMO_SRC}" -B "${_LE_ANDROID_BUILD}" -DANDROID=ON)

add_test(NAME license_embed.android.check
    COMMAND ${CMAKE_COMMAND}
        -DEXPECTED=${_LE_ANDROID_BUILD}/assets/license/zlib/LICENSE
        -DEXPECTED2=${_LE_ANDROID_BUILD}/assets/license/fmt/LICENSE
        -DEXPECTED3=${_LE_ANDROID_BUILD}/assets/license/boost-asio/LICENSE
        -P "${CMAKE_CURRENT_SOURCE_DIR}/assert_exists.cmake")
set_tests_properties(license_embed.android.check PROPERTIES
    DEPENDS license_embed.android.configure)

add_test(NAME license_embed.android_off.configure
    COMMAND ${CMAKE_COMMAND} -S "${_LE_DEMO_SRC}" -B "${_LE_ANDROID_OFF_BUILD}"
        -DANDROID=ON -DLICENSE_EMBED_ANDROID=OFF)

add_test(NAME license_embed.android_off.check_absent
    COMMAND ${CMAKE_COMMAND}
        -DEXPECTED=${_LE_ANDROID_OFF_BUILD}/assets/license/zlib/LICENSE
        -P "${CMAKE_CURRENT_SOURCE_DIR}/assert_not_exists.cmake")
set_tests_properties(license_embed.android_off.check_absent PROPERTIES
    DEPENDS license_embed.android_off.configure)
