# creates:
#  - Imported targets: rdkafka::rdkafkacpp (depends on rdkafka::rdkafka)
#                      rdkafka::rdkafka (C library + dependencies)
#  - Helper function:   librdkafka_setup_runtime(target)

cmake_minimum_required(VERSION 3.15)
message(STATUS "Using custom librdkafka module from package")

# --- 1. Define package paths ---
get_filename_component(LIBRDKAFKA_CMAKE_DIR "${CMAKE_CURRENT_LIST_DIR}" REALPATH)
get_filename_component(LIBRDKAFKA_PACKAGE_ROOT "${LIBRDKAFKA_CMAKE_DIR}/.." REALPATH)

set(RDKAFKA_INCLUDE_DIR        "${LIBRDKAFKA_PACKAGE_ROOT}/include")
set(RDKAFKA_DEBUG_BIN_DIR      "${LIBRDKAFKA_PACKAGE_ROOT}/debug/bin")
set(RDKAFKA_DEBUG_LIB_DIR      "${LIBRDKAFKA_PACKAGE_ROOT}/debug/lib")
set(RDKAFKA_RELEASE_BIN_DIR    "${LIBRDKAFKA_PACKAGE_ROOT}/release/bin")
set(RDKAFKA_RELEASE_LIB_DIR    "${LIBRDKAFKA_PACKAGE_ROOT}/release/lib")

# --- Find Dependencies (Required by the C library) ---
# This assumes OpenSSL and ZLIB packages have already been included/found
# in the main CMakeLists.txt and have defined these targets.
if(NOT TARGET OpenSSL::SSL OR NOT TARGET OpenSSL::Crypto)
    message(FATAL_ERROR "OpenSSL targets (OpenSSL::SSL, OpenSSL::Crypto) not found. Include the OpenSSL package first.")
endif()
if(NOT TARGET ZLIB::ZLIB)
     message(FATAL_ERROR "ZLIB target (ZLIB::ZLIB) not found. Include the ZLIB package first.")
endif()

# --- 2. Create the IMPORTED targets ---
# C library target
if(NOT TARGET rdkafka::rdkafka)
    add_library(rdkafka::rdkafka SHARED IMPORTED GLOBAL)
endif()
# C++ library target
if(NOT TARGET rdkafka::rdkafkacpp)
    add_library(rdkafka::rdkafkacpp SHARED IMPORTED GLOBAL)
    # --- === ADD THIS === ---
    # Define the dependency: C++ lib links against C lib
    set_target_properties(rdkafka::rdkafkacpp PROPERTIES
        INTERFACE_LINK_LIBRARIES rdkafka::rdkafka
    )
endif()


# --- 3. Set platform-specific properties ---
if(WIN32)
    # --- Properties for C++ Target (rdkafka::rdkafkacpp) ---
    set_target_properties(rdkafka::rdkafkacpp PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${RDKAFKA_INCLUDE_DIR}"
        IMPORTED_IMPLIB_DEBUG     "${RDKAFKA_DEBUG_LIB_DIR}/librdkafkacpp.lib"
        IMPORTED_LOCATION_DEBUG   "${RDKAFKA_DEBUG_BIN_DIR}/librdkafkacpp.dll"
        IMPORTED_IMPLIB_RELEASE   "${RDKAFKA_RELEASE_LIB_DIR}/librdkafkacpp.lib"
        IMPORTED_LOCATION_RELEASE "${RDKAFKA_RELEASE_BIN_DIR}/librdkafkacpp.dll"
        IMPORTED_IMPLIB_RELWITHDEBINFO   "${RDKAFKA_RELEASE_LIB_DIR}/librdkafkacpp.lib"
        IMPORTED_LOCATION_RELWITHDEBINFO "${RDKAFKA_RELEASE_BIN_DIR}/librdkafkacpp.dll"
        IMPORTED_IMPLIB_MINSIZEREL   "${RDKAFKA_RELEASE_LIB_DIR}/librdkafkacpp.lib"
        IMPORTED_LOCATION_MINSIZEREL "${RDKAFKA_RELEASE_BIN_DIR}/librdkafkacpp.dll"
    )

    # --- Properties for C Target (rdkafka::rdkafka) ---
    set_target_properties(rdkafka::rdkafka PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${RDKAFKA_INCLUDE_DIR}"
        IMPORTED_IMPLIB_DEBUG     "${RDKAFKA_DEBUG_LIB_DIR}/librdkafka.lib"
        IMPORTED_LOCATION_DEBUG   "${RDKAFKA_DEBUG_BIN_DIR}/librdkafka.dll"
        IMPORTED_IMPLIB_RELEASE   "${RDKAFKA_RELEASE_LIB_DIR}/librdkafka.lib"
        IMPORTED_LOCATION_RELEASE "${RDKAFKA_RELEASE_BIN_DIR}/librdkafka.dll"
        IMPORTED_IMPLIB_RELWITHDEBINFO   "${RDKAFKA_RELEASE_LIB_DIR}/librdkafka.lib"
        IMPORTED_LOCATION_RELWITHDEBINFO "${RDKAFKA_RELEASE_BIN_DIR}/librdkafka.dll"
        IMPORTED_IMPLIB_MINSIZEREL   "${RDKAFKA_RELEASE_LIB_DIR}/librdkafka.lib"
        IMPORTED_LOCATION_MINSIZEREL "${RDKAFKA_RELEASE_BIN_DIR}/librdkafka.dll"
        # --- === ADD THIS === ---
        # Link C library against its dependencies
        INTERFACE_LINK_LIBRARIES "OpenSSL::SSL;OpenSSL::Crypto;ZLIB::ZLIB;${RDKAFKA_SYSTEM_LIBS}"
    )
else() # Linux/Unix
    find_package(Threads REQUIRED)
    # Linux system libraries needed by librdkafka C library
    set(RDKAFKA_SYSTEM_LIBS Threads::Threads dl rt m) # No z - provided by ZLIB::ZLIB

    # --- Properties for C++ Target (rdkafka::rdkafkacpp) ---
    set_target_properties(rdkafka::rdkafkacpp PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${RDKAFKA_INCLUDE_DIR}"
        IMPORTED_LOCATION_DEBUG   "${RDKAFKA_DEBUG_LIB_DIR}/librdkafka++.so"
        IMPORTED_LOCATION_RELEASE "${RDKAFKA_RELEASE_LIB_DIR}/librdkafka++.so"
        IMPORTED_LOCATION_RELWITHDEBINFO "${RDKAFKA_RELEASE_LIB_DIR}/librdkafka++.so"
        IMPORTED_LOCATION_MINSIZEREL "${RDKAFKA_RELEASE_LIB_DIR}/librdkafka++.so"
    )

    # --- Properties for C Target (rdkafka::rdkafka) ---
    set_target_properties(rdkafka::rdkafka PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${RDKAFKA_INCLUDE_DIR}"
        IMPORTED_LOCATION_DEBUG   "${RDKAFKA_DEBUG_LIB_DIR}/librdkafka.so"
        IMPORTED_LOCATION_RELEASE "${RDKAFKA_RELEASE_LIB_DIR}/librdkafka.so"
        IMPORTED_LOCATION_RELWITHDEBINFO "${RDKAFKA_RELEASE_LIB_DIR}/librdkafka.so"
        IMPORTED_LOCATION_MINSIZEREL "${RDKAFKA_RELEASE_LIB_DIR}/librdkafka.so"
        # Link C library against its dependencies
        INTERFACE_LINK_LIBRARIES "OpenSSL::SSL;OpenSSL::Crypto;ZLIB::ZLIB;${RDKAFKA_SYSTEM_LIBS}"
    )
endif()

# --- 4. Helper function to copy runtime files (Windows-only) ---
if(WIN32)
    function(librdkafka_setup_runtime TARGET_NAME)
        message(STATUS "Setting up librdkafka runtime DLL copy for ${TARGET_NAME}")

        set(RDKAFKA_BIN_DIR "$<IF:$<CONFIG:Debug>,${RDKAFKA_DEBUG_BIN_DIR},${RDKAFKA_RELEASE_BIN_DIR}>")
        set(CURL_DLL "$<IF:$<CONFIG:Debug>,libcurl-d.dll,libcurl.dll>") # Assuming curl is packaged separately or found

        # List of DLLs provided DIRECTLY by this package + direct deps (curl, zstd)
        set(RUNTIME_DLLS
            "${RDKAFKA_BIN_DIR}/librdkafka.dll"
            "${RDKAFKA_BIN_DIR}/librdkafkacpp.dll"
            "${RDKAFKA_BIN_DIR}/${CURL_DLL}"
            "${RDKAFKA_BIN_DIR}/zstd.dll"
            # DO NOT list OpenSSL or Zlib DLLs here
        )

        add_custom_command(
            TARGET ${TARGET_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    ${RUNTIME_DLLS}
                    $<TARGET_FILE_DIR:${TARGET_NAME}>
            COMMENT "Copying librdkafka runtime dependencies ($<CONFIG>)"
        )
    endfunction()
else()
    # On Linux/macOS, do nothing. RPATH handling is preferred.
    function(librdkafka_setup_runtime TARGET_NAME)
        # Dummy function for cross-platform compatibility
    endfunction()
endif()