# Tiny helper: fail with non-zero exit if any of EXPECTED, EXPECTED2, ...
# variables points to a path that DOES exist (inverse of assert_exists.cmake).
foreach(_var EXPECTED EXPECTED2 EXPECTED3 EXPECTED4 EXPECTED5)
    if(DEFINED ${_var})
        if(EXISTS "${${_var}}")
            message(FATAL_ERROR
                "assert_not_exists: path should be absent but found '${${_var}}'")
        endif()
    endif()
endforeach()
