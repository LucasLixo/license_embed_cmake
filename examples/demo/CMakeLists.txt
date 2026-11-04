# Demo consumer project exercising all public macros.
# Works both as a subdirectory of the top-level project (via
# LICENSE_EMBED_BUILD_EXAMPLES) and as a standalone top-level project.
#
# Cache variables that test scenarios may override via -D:
#   DEMO_SPDX_FORMAT      JSON | XML | BOTH (default: BOTH)
#   DEMO_ENABLE_COPY_NOW  ON | OFF          (default: OFF)
#   DEMO_ENABLE_BUILD     ON | OFF          (default: ON)

cmake_minimum_required(VERSION 3.20)
project(myapp VERSION 1.2.3 LANGUAGES C)

set(DEMO_SPDX_FORMAT "BOTH" CACHE STRING "SPDX format for the demo project.")
option(DEMO_ENABLE_COPY_NOW "Enable configure-time license copy in demo" OFF)
option(DEMO_ENABLE_BUILD    "Enable build-time license copy in demo"      ON)

include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/LicenseEmbed.cmake")

add_executable(myapp src/main.c)

license_embed_add(NAME zlib       TYPE Zlib    PATH third_party/zlib/LICENSE)
license_embed_add(NAME fmt        TYPE MIT     PATH third_party/fmt/LICENSE)
license_embed_add(NAME boost-asio TYPE BSL-1.0 PATH third_party/asio/LICENSE_1_0.txt)

license_embed_target(TARGET myapp)
license_embed_enable_spdx(FORMAT ${DEMO_SPDX_FORMAT})

if(DEMO_ENABLE_COPY_NOW)
    license_embed_enable_copy_now()
endif()
if(DEMO_ENABLE_BUILD)
    license_embed_enable_build()
endif()
license_embed_enable_android()
license_embed_enable_install()
