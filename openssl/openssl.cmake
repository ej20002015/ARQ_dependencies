# Creates imported targets for a pre-built OpenSSL package

cmake_minimum_required(VERSION 3.15)
message(STATUS "Using custom OpenSSL module from package")

# --- 1. Define package paths ---
get_filename_component(OPENSSL_CMAKE_DIR "${CMAKE_CURRENT_LIST_DIR}" REALPATH)
get_filename_component(OPENSSL_PACKAGE_ROOT "${OPENSSL_CMAKE_DIR}/.." REALPATH)

set(OPENSSL_INCLUDE_DIR        "${OPENSSL_PACKAGE_ROOT}/include")
set(OPENSSL_DEBUG_BIN_DIR      "${OPENSSL_PACKAGE_ROOT}/debug/bin")
set(OPENSSL_DEBUG_LIB_DIR      "${OPENSSL_PACKAGE_ROOT}/debug/lib")
set(OPENSSL_RELEASE_BIN_DIR    "${OPENSSL_PACKAGE_ROOT}/release/bin")
set(OPENSSL_RELEASE_LIB_DIR    "${OPENSSL_PACKAGE_ROOT}/release/lib")

# --- 2. Create IMPORTED targets ---
if(NOT TARGET OpenSSL::SSL)
    add_library(OpenSSL::SSL SHARED IMPORTED GLOBAL)
endif()
if(NOT TARGET OpenSSL::Crypto)
    add_library(OpenSSL::Crypto SHARED IMPORTED GLOBAL)
    # SSL depends on Crypto
    set_target_properties(OpenSSL::SSL PROPERTIES INTERFACE_LINK_LIBRARIES OpenSSL::Crypto)
endif()

# --- 3. Set properties ---
if(WIN32)
    # --- Crypto ---
    set_target_properties(OpenSSL::Crypto PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIR}"
        IMPORTED_IMPLIB_DEBUG     "${OPENSSL_DEBUG_LIB_DIR}/libcrypto.lib"
        IMPORTED_LOCATION_DEBUG   "${OPENSSL_DEBUG_BIN_DIR}/libcrypto-3-x64.dll"
        IMPORTED_IMPLIB_RELEASE   "${OPENSSL_RELEASE_LIB_DIR}/libcrypto.lib"
        IMPORTED_LOCATION_RELEASE "${OPENSSL_RELEASE_BIN_DIR}/libcrypto-3-x64.dll"
        IMPORTED_IMPLIB_RELWITHDEBINFO   "${OPENSSL_RELEASE_LIB_DIR}/libcrypto.lib"
        IMPORTED_LOCATION_RELWITHDEBINFO "${OPENSSL_RELEASE_BIN_DIR}/libcrypto-3-x64.dll"
        IMPORTED_IMPLIB_MINSIZEREL   "${OPENSSL_RELEASE_LIB_DIR}/libcrypto.lib"
        IMPORTED_LOCATION_MINSIZEREL "${OPENSSL_RELEASE_BIN_DIR}/libcrypto-3-x64.dll"
    )
    # --- SSL ---
    set_target_properties(OpenSSL::SSL PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIR}"
        IMPORTED_IMPLIB_DEBUG     "${OPENSSL_DEBUG_LIB_DIR}/libssl.lib"
        IMPORTED_LOCATION_DEBUG   "${OPENSSL_DEBUG_BIN_DIR}/libssl-3-x64.dll"
        IMPORTED_IMPLIB_RELEASE   "${OPENSSL_RELEASE_LIB_DIR}/libssl.lib"
        IMPORTED_LOCATION_RELEASE "${OPENSSL_RELEASE_BIN_DIR}/libssl-3-x64.dll"
        IMPORTED_IMPLIB_RELWITHDEBINFO   "${OPENSSL_RELEASE_LIB_DIR}/libssl.lib"
        IMPORTED_LOCATION_RELWITHDEBINFO "${OPENSSL_RELEASE_BIN_DIR}/libssl-3-x64.dll"
        IMPORTED_IMPLIB_MINSIZEREL   "${OPENSSL_RELEASE_LIB_DIR}/libssl.lib"
        IMPORTED_LOCATION_MINSIZEREL "${OPENSSL_RELEASE_BIN_DIR}/libssl-3-x64.dll"
    )
else() # Linux/Unix
    # --- Crypto ---
    set_target_properties(OpenSSL::Crypto PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIR}"
        IMPORTED_LOCATION_DEBUG   "${OPENSSL_DEBUG_LIB_DIR}/libcrypto.so"
        IMPORTED_LOCATION_RELEASE "${OPENSSL_RELEASE_LIB_DIR}/libcrypto.so"
        IMPORTED_LOCATION_RELWITHDEBINFO "${OPENSSL_RELEASE_LIB_DIR}/libcrypto.so"
        IMPORTED_LOCATION_MINSIZEREL "${OPENSSL_RELEASE_LIB_DIR}/libcrypto.so"
        # Add system deps like dl, pthread if needed for crypto
        INTERFACE_LINK_LIBRARIES "$<LINK_ONLY:dl>;$<LINK_ONLY:Threads::Threads>" #  TODO: work this out
    )
    # --- SSL ---
    set_target_properties(OpenSSL::SSL PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIR}"
        IMPORTED_LOCATION_DEBUG   "${OPENSSL_DEBUG_LIB_DIR}/libssl.so"
        IMPORTED_LOCATION_RELEASE "${OPENSSL_RELEASE_LIB_DIR}/libssl.so"
        IMPORTED_LOCATION_RELWITHDEBINFO "${OPENSSL_RELEASE_LIB_DIR}/libssl.so"
        IMPORTED_LOCATION_MINSIZEREL "${OPENSSL_RELEASE_LIB_DIR}/libssl.so"
    )
endif()

# --- 4. Helper function to copy runtime DLLs (Windows-only) ---
if(WIN32)
    function(openssl_setup_runtime TARGET_NAME)
        message(STATUS "Setting up OpenSSL runtime DLL copy for ${TARGET_NAME}")
        set(OPENSSL_BIN_DIR "$<IF:$<CONFIG:Debug>,${OPENSSL_DEBUG_BIN_DIR},${OPENSSL_RELEASE_BIN_DIR}>")
        set(RUNTIME_DLLS
            "${OPENSSL_BIN_DIR}/libcrypto-3-x64.dll" # Adjust names if needed
            "${OPENSSL_BIN_DIR}/libssl-3-x64.dll"
        )
        add_custom_command(
            TARGET ${TARGET_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    ${RUNTIME_DLLS}
                    $<TARGET_FILE_DIR:${TARGET_NAME}>
            COMMENT "Copying OpenSSL runtime dependencies ($<CONFIG>)"
        )
    endfunction()
else()
    function(openssl_setup_runtime TARGET_NAME) # Dummy
    endfunction()
endif()