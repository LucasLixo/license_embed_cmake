cmake_minimum_required(VERSION 3.20)

project(license_embed_cmake
    VERSION 0.1.0
    DESCRIPTION "Pure-CMake utility for embedding third-party licenses and emitting SPDX SBOMs"
    LANGUAGES NONE
)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

option(LICENSE_EMBED_BUILD_EXAMPLES "Build the bundled example consumer project" OFF)
option(LICENSE_EMBED_BUILD_TESTS    "Build the bundled CTest harness"            OFF)

set(LICENSE_EMBED_MODULE_INSTALL_DIR
    "${CMAKE_INSTALL_DATAROOTDIR}/cmake/LicenseEmbed"
    CACHE PATH
    "Install location for the LicenseEmbed CMake module files.")

install(FILES
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake/LicenseEmbed.cmake"
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake/LicenseEmbedSPDX.cmake"
    DESTINATION "${LICENSE_EMBED_MODULE_INSTALL_DIR}"
    COMPONENT Devel)

configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/LicenseEmbedConfig.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/LicenseEmbedConfig.cmake"
    INSTALL_DESTINATION "${LICENSE_EMBED_MODULE_INSTALL_DIR}"
)
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/LicenseEmbedConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)
install(FILES
        "${CMAKE_CURRENT_BINARY_DIR}/LicenseEmbedConfig.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/LicenseEmbedConfigVersion.cmake"
    DESTINATION "${LICENSE_EMBED_MODULE_INSTALL_DIR}"
    COMPONENT Devel)

if(LICENSE_EMBED_BUILD_EXAMPLES)
    add_subdirectory(examples)
endif()

if(LICENSE_EMBED_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
