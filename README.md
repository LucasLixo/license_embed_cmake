# License Embed CMake

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![CMake](https://img.shields.io/badge/CMake-3.20%2B-blue.svg)](https://cmake.org)

A pure-CMake utility module for embedding third-party dependency license files
into your project's build tree and install tree, and for optionally generating
an [SPDX 2.3](https://spdx.github.io/spdx-spec/v2.3/) Software Bill of
Materials (SBOM) in JSON and/or XML format.

---

## Requirements

- CMake 3.20 or later
- No C/C++ compiler required (pure CMake, `LANGUAGES NONE`)
- Python 3 (optional — only needed to run the bundled test suite's SPDX validators)

---

## Integration

### FetchContent (recommended)

```cmake
include(FetchContent)
FetchContent_Declare(
    LicenseEmbed
    GIT_REPOSITORY https://github.com/LucasLixo/license_embed_cmake.git
    GIT_TAG        main
)
FetchContent_MakeAvailable(LicenseEmbed)
include("${licenseembed_SOURCE_DIR}/cmake/LicenseEmbed.cmake")
```

### add_subdirectory

```cmake
add_subdirectory(third_party/license_embed_cmake)
include("${CMAKE_CURRENT_SOURCE_DIR}/third_party/license_embed_cmake/cmake/LicenseEmbed.cmake")
```

### find_package (after install)

```cmake
# Install the module to a prefix first, then:
find_package(LicenseEmbed REQUIRED)
```

---

## Quick Start

```cmake
cmake_minimum_required(VERSION 3.20)
project(myapp VERSION 1.0.0 LANGUAGES CXX)

# ... fetch / add_subdirectory / find_package LicenseEmbed here ...

add_executable(myapp src/main.cpp)

# 1. Register third-party licenses
license_embed_add(NAME zlib       TYPE Zlib        PATH third_party/zlib/LICENSE)
license_embed_add(NAME fmt        TYPE MIT         PATH third_party/fmt/LICENSE)
license_embed_add(NAME boost-asio TYPE BSL-1.0     PATH third_party/asio/LICENSE_1_0.txt)

# 2. Bind licenses to a target (optional but recommended)
license_embed_target(TARGET myapp)

# 3. Generate SPDX SBOM at configure time (JSON + XML by default)
license_embed_enable_spdx()

# 4. Copy licenses into the build tree at build time
license_embed_enable_build()

# 5. Add install() rules
license_embed_enable_install()

install(TARGETS myapp RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
```

After `cmake --install`:

```
<prefix>/
  bin/myapp
  share/licenses/
    zlib/LICENSE.txt
    fmt/LICENSE.txt
    boost-asio/LICENSE.txt
  share/spdx/
    myapp.spdx.json
    myapp.spdx.xml
```

---

## Reference

### `license_embed_add(NAME <id> TYPE <spdx-id> PATH <file>)`

Registers one third-party dependency license. Must be called before any
`enable_*` macro.

| Argument | Required | Description |
|---|---|---|
| `NAME` | yes | Unique identifier for the dependency. No `\|` characters allowed. |
| `TYPE` | yes | SPDX short-form license identifier (e.g. `MIT`, `Apache-2.0`, `BSD-3-Clause`). Compound expressions are accepted (`MIT OR Apache-2.0`). Unknown identifiers emit a `WARNING` but are not rejected. |
| `PATH` | yes | Path to the license file. Resolved to absolute. `FATAL_ERROR` if the file does not exist. |

Errors:
- `FATAL_ERROR` if any argument is missing.
- `FATAL_ERROR` if `NAME` is registered more than once (idempotency guard).
- `FATAL_ERROR` if `PATH` does not exist on disk.

```cmake
license_embed_add(NAME zlib   TYPE Zlib        PATH third_party/zlib/LICENSE)
license_embed_add(NAME openssl TYPE Apache-2.0 PATH third_party/openssl/LICENSE.txt)
# Compound expression example:
license_embed_add(NAME dual   TYPE "MIT OR Apache-2.0" PATH third_party/dual/LICENSE)
```

---

### `license_embed_target(TARGET <target-or-list>)`

Binds the registered license set to one or more existing CMake targets so that
`enable_build()` can add the appropriate `add_dependencies` relationship.

| Argument | Required | Description |
|---|---|---|
| `TARGET` | yes | One or more existing CMake target names (space-separated). |

If this macro is never called, `enable_build()` still creates the copy step
(attached to `ALL`) but no target dependency is wired up.

```cmake
license_embed_target(TARGET myapp)
license_embed_target(TARGET mylib myapp)   # multiple targets at once
```

---

### `license_embed_enable_spdx([FORMAT <JSON|XML|BOTH>])`

Writes an [SPDX 2.3](https://spdx.github.io/spdx-spec/v2.3/) SBOM document at
**CMake configure time** (no build step required).

| Argument | Required | Default | Description |
|---|---|---|---|
| `FORMAT` | no | `BOTH` | Which serialization(s) to emit. `JSON` → `.spdx.json` only; `XML` → `.spdx.xml` only; `BOTH` → both files. |

- Output path: `${LICENSE_EMBED_BUILD_SPDX_DIR}/<project>.spdx.{json,xml}`
- The document namespace is derived deterministically from `PROJECT_NAME` and
  `PROJECT_VERSION` (SHA1-based UUID), so it is stable across reconfigures of
  the same project version.
- Call this macro **before** `enable_install()` and `enable_copy_now()` to
  ensure SPDX files are included in those operations.
- Emits `WARNING` (no `FATAL_ERROR`) if called before any `license_embed_add()`.

```cmake
license_embed_enable_spdx()                  # JSON + XML (default)
license_embed_enable_spdx(FORMAT JSON)       # JSON only
license_embed_enable_spdx(FORMAT XML)        # XML only
```

---

### `license_embed_enable_build()`

Creates a CMake custom target `license_embed_<PROJECT_NAME>` added to `ALL`.
During `cmake --build`, each registered license file is copied to:

```
${LICENSE_EMBED_BUILD_LICENSES_DIR}/<NAME>/LICENSE
```

If `license_embed_target()` was called, each bound target gains an
`add_dependencies` on this copy target so licenses are always present before
the main binary is linked.

```cmake
license_embed_enable_build()
```

---

### `license_embed_enable_copy_now()`

Copies all registered license files **immediately at CMake configure time**
using `configure_file(COPYONLY)`. No build step is required.

- Destination: `${LICENSE_EMBED_BUILD_LICENSES_DIR}/<NAME>/LICENSE` (same
  directory as `enable_build()`).
- Because `configure_file` tracks source file dependencies, CMake will
  automatically reconfigure when any registered license file changes on disk.
- Call `enable_spdx()` **before** this macro if you want SPDX files to be
  present in the same location right after configure.
- Calling both `enable_copy_now()` and `enable_build()` is safe; the build
  step will skip unchanged files.

```cmake
license_embed_enable_spdx()       # write SPDX at configure time
license_embed_enable_copy_now()   # copy licenses at configure time
# No cmake --build needed to have licenses in the build tree
```

---

### `license_embed_enable_install()`

Adds `install()` rules for all registered licenses and (if `enable_spdx()` was
called) for the SPDX documents. All artifacts use the
`${LICENSE_EMBED_INSTALL_COMPONENT}` component (default: `LicenseEmbed`).

Install layout:

```
${LICENSE_EMBED_INSTALL_LICENSES_DIR}/<NAME>/LICENSE
${LICENSE_EMBED_INSTALL_SPDX_DIR}/<project>.spdx.json   (if FORMAT JSON or BOTH)
${LICENSE_EMBED_INSTALL_SPDX_DIR}/<project>.spdx.xml    (if FORMAT XML  or BOTH)
```

```cmake
license_embed_enable_install()

# Install only the LicenseEmbed component (CPack / cmake --install):
# cmake --install build --component LicenseEmbed
```

---

### `license_embed_enable_android()`

Android integration. When the build targets Android (detected through the
`ANDROID` variable or `CMAKE_SYSTEM_NAME` being `Android`, as set by the NDK
toolchain) and `LICENSE_EMBED_ANDROID` is `ON`, copies all registered licenses
at **configure time** to:

```
${LICENSE_EMBED_ANDROID_ASSETS_DIR}/<NAME>/LICENSE
```

On any other platform, or when `LICENSE_EMBED_ANDROID=OFF`, the macro does
nothing, so it is safe to leave in cross-platform projects. Point
`LICENSE_EMBED_ANDROID_ASSETS_DIR` at your Gradle module's assets folder so the
files are packaged into the APK/AAB.

```cmake
license_embed_enable_android()
```

```sh
# Enable (default) and send licenses to the Gradle assets folder
cmake -DLICENSE_EMBED_ANDROID_ASSETS_DIR=/path/app/src/main/assets/license ...

# Disable the Android integration
cmake -DLICENSE_EMBED_ANDROID=OFF ...
```

---

### `license_embed_get_destinations(<out-var> MODE <install|build|configure|android>)`

Populates `<out-var>` with the list of absolute paths where the registered
licenses would land for the given mode. Useful for integrating with custom
install rules, manifests, or packaging scripts.

| Argument | Required | Description |
|---|---|---|
| `<out-var>` | yes | CMake variable that receives the result list. |
| `MODE` | yes | `install` uses `LICENSE_EMBED_INSTALL_LICENSES_DIR`; `build` and `configure` both use `LICENSE_EMBED_BUILD_LICENSES_DIR`; `android` uses `LICENSE_EMBED_ANDROID_ASSETS_DIR`. |

```cmake
license_embed_get_destinations(MY_INSTALL_PATHS MODE install)
# MY_INSTALL_PATHS == [
#   /usr/share/licenses/zlib/LICENSE.txt
#   /usr/share/licenses/fmt/LICENSE.txt
#   /usr/share/licenses/boost-asio/LICENSE.txt
# ]

license_embed_get_destinations(MY_BUILD_PATHS MODE build)
```

---

## Cache Variables

All variables can be overridden via `-D` on the CMake command line or by
`set(... CACHE ...)` before including the module.

| Variable | Type | Default | Description |
|---|---|---|---|
| `LICENSE_EMBED_INSTALL_LICENSES_DIR` | PATH | `${CMAKE_INSTALL_DATAROOTDIR}/licenses` | Install root for per-dependency license files. One subdirectory per `NAME`. |
| `LICENSE_EMBED_INSTALL_SPDX_DIR` | PATH | `${CMAKE_INSTALL_DATAROOTDIR}/spdx` | Install root for SPDX SBOM documents. |
| `LICENSE_EMBED_BUILD_LICENSES_DIR` | PATH | `${CMAKE_BINARY_DIR}/licenses` | Build-tree root for per-dependency license files. |
| `LICENSE_EMBED_BUILD_SPDX_DIR` | PATH | `${CMAKE_BINARY_DIR}/spdx` | Build-tree root for SPDX SBOM documents. |
| `LICENSE_EMBED_ANDROID` | BOOL | `ON` | Enable/disable the Android integration (`license_embed_enable_android()`). |
| `LICENSE_EMBED_ANDROID_ASSETS_DIR` | PATH | `${CMAKE_BINARY_DIR}/assets/license` | Android `assets/license` directory that receives the license files. |
| `LICENSE_EMBED_INSTALL_COMPONENT` | STRING | `LicenseEmbed` | CPack / `cmake --install --component` name for all license artifacts. |

Example — place licenses next to the binary:

```cmake
set(LICENSE_EMBED_BUILD_LICENSES_DIR "${CMAKE_BINARY_DIR}/bin/licenses" CACHE PATH "" FORCE)
```

Or from the command line:

```sh
cmake -B build -DLICENSE_EMBED_BUILD_LICENSES_DIR=/custom/path/licenses
```

---

## SPDX Notes

The generated SBOM follows the [SPDX 2.3 specification](https://spdx.github.io/spdx-spec/v2.3/).

**Supported output formats:**

| Format | Extension | Notes |
|---|---|---|
| JSON | `.spdx.json` | Primary; widely supported by tools (Syft, Grype, GitHub Dependency Graph). |
| XML | `.spdx.xml` | Per SPDX 2.3; support in tools varies. |

**Minimum fields written per package:**

| Field | Value |
|---|---|
| `SPDXID` | `SPDXRef-Package-<sanitized-NAME>` |
| `name` | The `NAME` argument passed to `license_embed_add()` |
| `downloadLocation` | `NOASSERTION` |
| `filesAnalyzed` | `false` |
| `licenseConcluded` | The `TYPE` argument (SPDX expression) |
| `licenseDeclared` | Same as `licenseConcluded` |
| `copyrightText` | `NOASSERTION` |

**Document namespace** is stable across reconfigures of the same
`PROJECT_NAME` + `PROJECT_VERSION` pair (derived via SHA1 → UUID).

**SPDX license identifiers** — a curated shortlist is validated at registration
time. Unknown identifiers emit a `WARNING` and are accepted as-is so the module
never blocks a valid SPDX expression that post-dates the list. See the full
identifier list at [spdx.org/licenses](https://spdx.org/licenses/).

---

## License

Shield: [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
