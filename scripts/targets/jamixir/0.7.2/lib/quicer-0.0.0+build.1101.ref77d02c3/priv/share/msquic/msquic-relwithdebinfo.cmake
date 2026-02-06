#----------------------------------------------------------------
# Generated CMake target import file for configuration "RelWithDebInfo".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "msquic" for configuration "RelWithDebInfo"
set_property(TARGET msquic APPEND PROPERTY IMPORTED_CONFIGURATIONS RELWITHDEBINFO)
set_target_properties(msquic PROPERTIES
  IMPORTED_LOCATION_RELWITHDEBINFO "${_IMPORT_PREFIX}/lib/libmsquic.so.2.3.8"
  IMPORTED_SONAME_RELWITHDEBINFO "libmsquic.so.2"
  )

list(APPEND _cmake_import_check_targets msquic )
list(APPEND _cmake_import_check_files_for_msquic "${_IMPORT_PREFIX}/lib/libmsquic.so.2.3.8" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
