# Demo consumer project exercising all four public macros.
# Works both as a subdirectory of the top-level project (via
# LICENSE_EMBED_BUILD_EXAMPLES) and as a standalone top-level project.

cmake_minimum_required(VERSION 3.20)
project(myapp VERSION 1.2.3 LANGUAGES C)

include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/LicenseEmbed.cmake")

add_executable(myapp src/main.c)

license_embed_add(NAME zlib       TYPE Zlib    PATH third_party/zlib/LICENSE)
license_embed_add(NAME fmt        TYPE MIT     PATH third_party/fmt/LICENSE)
license_embed_add(NAME boost-asio TYPE BSL-1.0 PATH third_party/asio/LICENSE_1_0.txt)

license_embed_target(TARGET myapp)
license_embed_enable_spdx()
license_embed_enable_build()
license_embed_enable_install()

install(TARGETS myapp RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
