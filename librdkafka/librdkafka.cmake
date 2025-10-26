# creates:
#  - An imported target: rdkafka::rdkafkacpp
#  - A helper function:   librdkafka_setup_runtime(target)

cmake_minimum_required(VERSION 3.15)

# --- 1. Define package paths ---
# Get the directory this script is in (e.g., .../cmake/)
get_filename_component(LIBRDKAFKA_CMAKE_DIR "${CMAKE_CURRENT_LIST_DIR}" REALPATH)
# Get the root of the package (e.g., .../cmake/../)
get_filename_component(LIBRDKAFKA_PACKAGE_ROOT "${LIBRDKAFKA_CMAKE_DIR}/.." REALPATH)

# Define all subdirectories based on the package root
set(RDKAFKA_INCLUDE_DIR "${LIBRDKAFKA_PACKAGE_ROOT}/include")
set(RDKAFKA_DEBUG_BIN_DIR   "${LIBRDKAFKA_PACKAGE_ROOT}/debug/bin")
set(RDKAFKA_DEBUG_LIB_DIR   "${LIBRDKAFKA_PACKAGE_ROOT}/debug/lib")
set(RDKAFKA_RELEASE_BIN_DIR "${LIBRDKAFKA_PACKAGE_ROOT}/release/bin")
set(RDKAFKA_RELEASE_LIB_DIR "${LIBRDKAFKA_PACKAGE_ROOT}/release/lib")


# --- 2. Create the IMPORTED target ---
if(NOT TARGET rdkafka::rdkafkacpp)
    add_library(rdkafka::rdkafkacpp SHARED IMPORTED GLOBAL)
endif()


# --- 3. Set platform-specific properties ---
# This section handles the differences between Windows (.dll/.lib) and Linux (.so)

if(WIN32)
    set_target_properties(rdkafka::rdkafkacpp PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${RDKAFKA_INCLUDE_DIR}"

        # --- Debug ---
        IMPORTED_IMPLIB_DEBUG     "${RDKAFKA_DEBUG_LIB_DIR}/librdkafkacpp.lib"
        IMPORTED_LOCATION_DEBUG   "${RDKAFKA_DEBUG_BIN_DIR}/librdkafkacpp.dll"

        # --- Release ---
        IMPORTED_IMPLIB_RELEASE   "${RDKAFKA_RELEASE_LIB_DIR}/librdkafkacpp.lib"
        IMPORTED_LOCATION_RELEASE "${RDKAFKA_RELEASE_BIN_DIR}/librdkafkacpp.dll"

        # --- RelWithDebInfo (Use Release files) ---
        IMPORTED_IMPLIB_RELWITHDEBINFO   "${RDKAFKA_RELEASE_LIB_DIR}/librdkafkacpp.lib"
        IMPORTED_LOCATION_RELWITHDEBINFO "${RDKAFKA_RELEASE_BIN_DIR}/librdkafkacpp.dll"

        # --- MinSizeRel (Use Release files) ---
        IMPORTED_IMPLIB_MINSIZEREL   "${RDKAFKA_RELEASE_LIB_DIR}/librdkafkacpp.lib"
        IMPORTED_LOCATION_MINSIZEREL "${RDKAFKA_RELEASE_BIN_DIR}/librdkafkacpp.dll"
    )
else()
    # On Linux, the .so is the "location" and "import library"
    set_target_properties(rdkafka::rdkafkacpp PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${RDKAFKA_INCLUDE_DIR}"

        # --- Debug ---
        IMPORTED_LOCATION_DEBUG   "${RDKAFKA_DEBUG_LIB_DIR}/librdkafkacpp.so"

        # --- Release ---
        IMPORTED_LOCATION_RELEASE "${RDKAFKA_RELEASE_LIB_DIR}/librdkafkacpp.so"

        # --- RelWithDebInfo (Use Release files) ---
        IMPORTED_LOCATION_RELWITHDEBINFO "${RDKAFKA_RELEASE_BIN_DIR}/librdkafkacpp.so"

        # --- MinSizeRel (Use Release files) ---
        IMPORTED_LOCATION_MINSIZEREL "${RDKAFKA_RELEASE_BIN_DIR}/librdkafkacpp.so"
    )
endif()

# --- 4. Helper function to copy runtime DLLs (Windows-only) ---
if(WIN32)
    function(librdkafka_setup_runtime TARGET_NAME)
        message(STATUS "Setting up runtime DLL copy for ${TARGET_NAME}")

        set(RDKAFKA_BIN_DIR "$<IF:$<CONFIG:Debug>,${RDKAFKA_DEBUG_BIN_DIR},${RDKAFKA_RELEASE_BIN_DIR}>")
        
        set(CURL_DLL "$<IF:$<CONFIG:Debug>,libcurl-d.dll,libcurl.dll>")
        set(ZLIB_DLL "$<IF:$<CONFIG:Debug>,zlibd1.dll,zlib1.dll>")

        # List of all required DLLs
        # This part was fine, but now the variables above will evaluate correctly.
        set(RUNTIME_DLLS
            "${RDKAFKA_BIN_DIR}/libcrypto-3-x64.dll"
            "${RDKAFKA_BIN_DIR}/${CURL_DLL}"
            "${RDKAFKA_BIN_DIR}/librdkafka.dll"
            "${RDKAFKA_BIN_DIR}/librdkafkacpp.dll"
            "${RDKAFKA_BIN_DIR}/libssl-3-x64.dll"
            "${RDKAFKA_BIN_DIR}/${ZLIB_DLL}"
            "${RDKAFKA_BIN_DIR}/zstd.dll"
        )

        # Add the post-build command to copy them
        add_custom_command(
            TARGET ${TARGET_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    ${RUNTIME_DLLS}
                    $<TARGET_FILE_DIR:${TARGET_NAME}>
            COMMENT "Copying rdkafka runtime dependencies ($<CONFIG>)"
        )
    endfunction()
else()
    # On Linux/macOS, do nothing. RPATH handling is preferred.
    function(librdkafka_setup_runtime TARGET_NAME)
        # Dummy function for cross-platform compatibility
    endfunction()
endif()