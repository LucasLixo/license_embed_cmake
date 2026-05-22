# CTest harness for license_embed_cmake.
#
# Each test drives an isolated sub-build of the example demo project and
# inspects the resulting tree, then validates the SPDX documents.

find_package(Python3 COMPONENTS Interpreter)

set(_LE_DEMO_SRC     "${CMAKE_SOURCE_DIR}/examples/demo")
set(_LE_DEMO_BUILD   "${CMAKE_BINARY_DIR}/tests/demo-build")
set(_LE_DEMO_STAGE   "${CMAKE_BINARY_DIR}/tests/demo-stage")

# Configure the demo project.
add_test(
    NAME license_embed.configure_demo
    COMMAND ${CMAKE_COMMAND}
        -S "${_LE_DEMO_SRC}"
        -B "${_LE_DEMO_BUILD}"
        -DCMAKE_INSTALL_PREFIX=${_LE_DEMO_STAGE}
)

# Build the demo project (triggers the license_embed_myapp custom target).
add_test(
    NAME license_embed.build_demo
    COMMAND ${CMAKE_COMMAND} --build "${_LE_DEMO_BUILD}"
)
set_tests_properties(license_embed.build_demo PROPERTIES
    DEPENDS license_embed.configure_demo)

# Check build-tree mirror artifacts.
add_test(
    NAME license_embed.check_build_tree
    COMMAND ${CMAKE_COMMAND}
        -DEXPECTED=${_LE_DEMO_BUILD}/licenses/zlib/LICENSE
        -DEXPECTED2=${_LE_DEMO_BUILD}/licenses/fmt/LICENSE
        -DEXPECTED3=${_LE_DEMO_BUILD}/licenses/boost-asio/LICENSE
        -DEXPECTED4=${_LE_DEMO_BUILD}/spdx/myapp.spdx.json
        -DEXPECTED5=${_LE_DEMO_BUILD}/spdx/myapp.spdx.xml
        -P "${CMAKE_CURRENT_SOURCE_DIR}/assert_exists.cmake"
)
set_tests_properties(license_embed.check_build_tree PROPERTIES
    DEPENDS license_embed.build_demo)

# Install to a staging prefix.
add_test(
    NAME license_embed.install_demo
    COMMAND ${CMAKE_COMMAND} --install "${_LE_DEMO_BUILD}" --prefix "${_LE_DEMO_STAGE}"
)
set_tests_properties(license_embed.install_demo PROPERTIES
    DEPENDS license_embed.build_demo)

# Check the install tree.
add_test(
    NAME license_embed.check_install_tree
    COMMAND ${CMAKE_COMMAND}
        -DEXPECTED=${_LE_DEMO_STAGE}/share/licenses/zlib/LICENSE
        -DEXPECTED2=${_LE_DEMO_STAGE}/share/licenses/fmt/LICENSE
        -DEXPECTED3=${_LE_DEMO_STAGE}/share/licenses/boost-asio/LICENSE
        -DEXPECTED4=${_LE_DEMO_STAGE}/share/spdx/myapp.spdx.json
        -DEXPECTED5=${_LE_DEMO_STAGE}/share/spdx/myapp.spdx.xml
        -P "${CMAKE_CURRENT_SOURCE_DIR}/assert_exists.cmake"
)
set_tests_properties(license_embed.check_install_tree PROPERTIES
    DEPENDS license_embed.install_demo)

# Validate the SPDX JSON and XML if a Python interpreter is available.
if(Python3_Interpreter_FOUND)
    add_test(
        NAME license_embed.validate_spdx_json
        COMMAND ${Python3_EXECUTABLE} -m json.tool
                "${_LE_DEMO_STAGE}/share/spdx/myapp.spdx.json"
    )
    set_tests_properties(license_embed.validate_spdx_json PROPERTIES
        DEPENDS license_embed.install_demo)

    add_test(
        NAME license_embed.validate_spdx_xml
        COMMAND ${Python3_EXECUTABLE} -c
                "import xml.etree.ElementTree as ET, sys; ET.parse(sys.argv[1])"
                "${_LE_DEMO_STAGE}/share/spdx/myapp.spdx.xml"
    )
    set_tests_properties(license_embed.validate_spdx_xml PROPERTIES
        DEPENDS license_embed.install_demo)
endif()
