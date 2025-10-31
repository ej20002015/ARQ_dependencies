# Creates imported targets for a pre-built zlib package

cmake_minimum_required(VERSION 3.15)
message(STATUS "Using custom zlib module from package")

# --- 1. Define package paths ---
get_filename_component(ZLIB_CMAKE_DIR "${CMAKE_CURRENT_LIST_DIR}" REALPATH)
get_filename_component(ZLIB_PACKAGE_ROOT "${ZLIB_CMAKE_DIR}/.." REALPATH)

set(ZLIB_INCLUDE_DIR        "${ZLIB_PACKAGE_ROOT}/include")
set(ZLIB_DEBUG_BIN_DIR      "${ZLIB_PACKAGE_ROOT}/debug/bin")
set(ZLIB_DEBUG_LIB_DIR      "${ZLIB_PACKAGE_ROOT}/debug/lib")
set(ZLIB_RELEASE_BIN_DIR    "${ZLIB_PACKAGE_ROOT}/release/bin")
set(ZLIB_RELEASE_LIB_DIR    "${ZLIB_PACKAGE_ROOT}/release/lib")

# --- 2. Create IMPORTED target ---
# vcpkg usually builds zlib as ZLIB::ZLIB
if(NOT TARGET ZLIB::ZLIB)
    add_library(ZLIB::ZLIB SHARED IMPORTED GLOBAL)
endif()

# --- 3. Set properties ---
if(WIN32)
    set_target_properties(ZLIB::ZLIB PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${ZLIB_INCLUDE_DIR}"
        # --- Debug ---
        IMPORTED_IMPLIB_DEBUG     "${ZLIB_DEBUG_LIB_DIR}/zlibd.lib"   # Import lib
        IMPORTED_LOCATION_DEBUG   "${ZLIB_DEBUG_BIN_DIR}/zlibd1.dll"  # DLL
        # --- Release ---
        IMPORTED_IMPLIB_RELEASE   "${ZLIB_RELEASE_LIB_DIR}/zlib.lib"    # Import lib
        IMPORTED_LOCATION_RELEASE "${ZLIB_RELEASE_BIN_DIR}/zlib1.dll"   # DLL
        # --- RelWithDebInfo ---
        IMPORTED_IMPLIB_RELWITHDEBINFO   "${ZLIB_RELEASE_LIB_DIR}/zlib.lib"
        IMPORTED_LOCATION_RELWITHDEBINFO "${ZLIB_RELEASE_BIN_DIR}/zlib1.dll"
        # --- MinSizeRel ---
        IMPORTED_IMPLIB_MINSIZEREL   "${ZLIB_RELEASE_LIB_DIR}/zlib.lib"
        IMPORTED_LOCATION_MINSIZEREL "${ZLIB_RELEASE_BIN_DIR}/zlib1.dll"
    )
else() # Linux/Unix
    set_target_properties(ZLIB::ZLIB PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${ZLIB_INCLUDE_DIR}"
        IMPORTED_LOCATION_DEBUG   "${ZLIB_DEBUG_LIB_DIR}/libz.so" # Adjust .so name if needed
        IMPORTED_LOCATION_RELEASE "${ZLIB_RELEASE_LIB_DIR}/libz.so"
        IMPORTED_LOCATION_RELWITHDEBINFO "${ZLIB_RELEASE_LIB_DIR}/libz.so"
        IMPORTED_LOCATION_MINSIZEREL "${ZLIB_RELEASE_LIB_DIR}/libz.so"
    )
endif()

# --- 4. Helper function to copy runtime DLLs (Windows-only) ---
if(WIN32)
    function(zlib_setup_runtime TARGET_NAME)
        message(STATUS "Setting up zlib runtime DLL copy for ${TARGET_NAME}")
        set(ZLIB_BIN_DIR "$<IF:$<CONFIG:Debug>,${ZLIB_DEBUG_BIN_DIR},${ZLIB_RELEASE_BIN_DIR}>")
        set(ZLIB_DLL_NAME "$<IF:$<CONFIG:Debug>,zlibd1.dll,zlib1.dll>")
        set(RUNTIME_DLLS
            "${ZLIB_BIN_DIR}/${ZLIB_DLL_NAME}"
        )
        add_custom_command(
            TARGET ${TARGET_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    ${RUNTIME_DLLS}
                    $<TARGET_FILE_DIR:${TARGET_NAME}>
            COMMENT "Copying zlib runtime dependencies ($<CONFIG>)"
        )
    endfunction()
else()
    function(zlib_setup_runtime TARGET_NAME) # Dummy
    endfunction()
endif()