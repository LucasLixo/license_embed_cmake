# Tiny helper: fail with non-zero exit if any of EXPECTED, EXPECTED2, ...
# variables points to a non-existent path.
foreach(_var EXPECTED EXPECTED2 EXPECTED3 EXPECTED4 EXPECTED5 EXPECTED6 EXPECTED7 EXPECTED8)
    if(DEFINED ${_var})
        if(NOT EXISTS "${${_var}}")
            message(FATAL_ERROR "assert_exists: missing path '${${_var}}'")
        endif()
    endif()
endforeach()
