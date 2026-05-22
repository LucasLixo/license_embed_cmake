# LicenseEmbedSPDX.cmake
#
# Internal SPDX 2.3 serializer used by LicenseEmbed.cmake.
# Emits two artifacts in parallel:
#   - <project>.spdx.json (SPDX 2.3 JSON schema, primary)
#   - <project>.spdx.xml  (SPDX 2.3 XML schema)
#
# Not intended for direct consumer use; symbols are underscore-prefixed.

if(DEFINED _LICENSE_EMBED_SPDX_INCLUDED)
    return()
endif()
set(_LICENSE_EMBED_SPDX_INCLUDED 1)

# Escape a string for safe embedding inside a JSON string literal.
function(_license_embed_escape_json OUT_VAR IN_STR)
    set(_s "${IN_STR}")
    string(REPLACE "\\" "\\\\" _s "${_s}")
    string(REPLACE "\"" "\\\"" _s "${_s}")
    string(REPLACE "\n" "\\n"  _s "${_s}")
    string(REPLACE "\r" "\\r"  _s "${_s}")
    string(REPLACE "\t" "\\t"  _s "${_s}")
    set(${OUT_VAR} "${_s}" PARENT_SCOPE)
endfunction()

# Escape a string for safe embedding inside an XML text node or attribute.
function(_license_embed_escape_xml OUT_VAR IN_STR)
    set(_s "${IN_STR}")
    string(REPLACE "&"  "&amp;"  _s "${_s}")
    string(REPLACE "<"  "&lt;"   _s "${_s}")
    string(REPLACE ">"  "&gt;"   _s "${_s}")
    string(REPLACE "\"" "&quot;" _s "${_s}")
    string(REPLACE "'"  "&apos;" _s "${_s}")
    set(${OUT_VAR} "${_s}" PARENT_SCOPE)
endfunction()

# Return the current UTC time formatted per ISO 8601 (SPDX creationInfo.created).
function(_license_embed_iso8601_now OUT_VAR)
    string(TIMESTAMP _ts "%Y-%m-%dT%H:%M:%SZ" UTC)
    set(${OUT_VAR} "${_ts}" PARENT_SCOPE)
endfunction()

# Derive a deterministic UUID-shaped string (8-4-4-4-12) from a seed string.
# Stable across reconfigures of the same project, so documentNamespace does
# not churn on every cmake run.
function(_license_embed_uuid OUT_VAR SEED)
    string(SHA1 _h "${SEED}")
    string(SUBSTRING "${_h}"  0 8 _a)
    string(SUBSTRING "${_h}"  8 4 _b)
    string(SUBSTRING "${_h}" 12 4 _c)
    string(SUBSTRING "${_h}" 16 4 _d)
    string(SUBSTRING "${_h}" 20 12 _e)
    set(${OUT_VAR} "${_a}-${_b}-${_c}-${_d}-${_e}" PARENT_SCOPE)
endfunction()

# Sanitize a free-form NAME into the character set allowed for an SPDX
# element ref (letters, digits, period, hyphen). All other bytes collapse to "-".
function(_license_embed_sanitize_id OUT_VAR IN_STR)
    string(REGEX REPLACE "[^A-Za-z0-9.-]+" "-" _s "${IN_STR}")
    set(${OUT_VAR} "${_s}" PARENT_SCOPE)
endfunction()

# Write the SPDX 2.3 JSON document to OUT_PATH.
#   ENTRIES_VAR is the name of a variable that holds a list of
#   "NAME|TYPE|ABSPATH" rows.
function(_license_embed_write_spdx_json OUT_PATH PROJECT_NAME_ARG PROJECT_VERSION_ARG TOOL_VERSION DOC_NAMESPACE ENTRIES_VAR)
    set(_entries "${${ENTRIES_VAR}}")
    _license_embed_iso8601_now(_created)

    _license_embed_escape_json(_e_name "${PROJECT_NAME_ARG}")
    _license_embed_escape_json(_e_ns   "${DOC_NAMESPACE}")
    _license_embed_escape_json(_e_tool "Tool: license_embed_cmake-${TOOL_VERSION}")

    set(_pkg_blocks "")
    set(_first TRUE)
    foreach(_row IN LISTS _entries)
        string(REPLACE "|" ";" _parts "${_row}")
        list(GET _parts 0 _name)
        list(GET _parts 1 _type)
        list(GET _parts 2 _path)
        _license_embed_sanitize_id(_sid "${_name}")
        _license_embed_escape_json(_je_name "${_name}")
        _license_embed_escape_json(_je_type "${_type}")

        if(_first)
            set(_first FALSE)
        else()
            string(APPEND _pkg_blocks ",\n")
        endif()
        string(APPEND _pkg_blocks
            "    {\n"
            "      \"SPDXID\": \"SPDXRef-Package-${_sid}\",\n"
            "      \"name\": \"${_je_name}\",\n"
            "      \"downloadLocation\": \"NOASSERTION\",\n"
            "      \"filesAnalyzed\": false,\n"
            "      \"licenseConcluded\": \"${_je_type}\",\n"
            "      \"licenseDeclared\": \"${_je_type}\",\n"
            "      \"copyrightText\": \"NOASSERTION\"\n"
            "    }"
        )
    endforeach()

    set(_doc "")
    string(APPEND _doc "{\n")
    string(APPEND _doc "  \"spdxVersion\": \"SPDX-2.3\",\n")
    string(APPEND _doc "  \"dataLicense\": \"CC0-1.0\",\n")
    string(APPEND _doc "  \"SPDXID\": \"SPDXRef-DOCUMENT\",\n")
    string(APPEND _doc "  \"name\": \"${_e_name}\",\n")
    string(APPEND _doc "  \"documentNamespace\": \"${_e_ns}\",\n")
    string(APPEND _doc "  \"creationInfo\": {\n")
    string(APPEND _doc "    \"created\": \"${_created}\",\n")
    string(APPEND _doc "    \"creators\": [\"${_e_tool}\"]\n")
    string(APPEND _doc "  },\n")
    string(APPEND _doc "  \"packages\": [\n")
    string(APPEND _doc "${_pkg_blocks}\n")
    string(APPEND _doc "  ]\n")
    string(APPEND _doc "}\n")
    file(WRITE "${OUT_PATH}" "${_doc}")
endfunction()

# Write the SPDX 2.3 XML document to OUT_PATH.
function(_license_embed_write_spdx_xml OUT_PATH PROJECT_NAME_ARG PROJECT_VERSION_ARG TOOL_VERSION DOC_NAMESPACE ENTRIES_VAR)
    set(_entries "${${ENTRIES_VAR}}")
    _license_embed_iso8601_now(_created)

    _license_embed_escape_xml(_e_name "${PROJECT_NAME_ARG}")
    _license_embed_escape_xml(_e_ns   "${DOC_NAMESPACE}")
    _license_embed_escape_xml(_e_tool "Tool: license_embed_cmake-${TOOL_VERSION}")

    set(_pkg_blocks "")
    foreach(_row IN LISTS _entries)
        string(REPLACE "|" ";" _parts "${_row}")
        list(GET _parts 0 _name)
        list(GET _parts 1 _type)
        list(GET _parts 2 _path)
        _license_embed_sanitize_id(_sid "${_name}")
        _license_embed_escape_xml(_xe_name "${_name}")
        _license_embed_escape_xml(_xe_type "${_type}")
        string(APPEND _pkg_blocks
            "  <packages>\n"
            "    <SPDXID>SPDXRef-Package-${_sid}</SPDXID>\n"
            "    <name>${_xe_name}</name>\n"
            "    <downloadLocation>NOASSERTION</downloadLocation>\n"
            "    <filesAnalyzed>false</filesAnalyzed>\n"
            "    <licenseConcluded>${_xe_type}</licenseConcluded>\n"
            "    <licenseDeclared>${_xe_type}</licenseDeclared>\n"
            "    <copyrightText>NOASSERTION</copyrightText>\n"
            "  </packages>\n"
        )
    endforeach()

    set(_doc "")
    string(APPEND _doc "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
    string(APPEND _doc "<Document xmlns=\"http://spdx.org/rdf/terms#\">\n")
    string(APPEND _doc "  <spdxVersion>SPDX-2.3</spdxVersion>\n")
    string(APPEND _doc "  <dataLicense>CC0-1.0</dataLicense>\n")
    string(APPEND _doc "  <SPDXID>SPDXRef-DOCUMENT</SPDXID>\n")
    string(APPEND _doc "  <name>${_e_name}</name>\n")
    string(APPEND _doc "  <documentNamespace>${_e_ns}</documentNamespace>\n")
    string(APPEND _doc "  <creationInfo>\n")
    string(APPEND _doc "    <created>${_created}</created>\n")
    string(APPEND _doc "    <creators>${_e_tool}</creators>\n")
    string(APPEND _doc "  </creationInfo>\n")
    string(APPEND _doc "${_pkg_blocks}")
    string(APPEND _doc "</Document>\n")
    file(WRITE "${OUT_PATH}" "${_doc}")
endfunction()
