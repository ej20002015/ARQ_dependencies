# Creates an imported target for a pre-built nats.c static library package

cmake_minimum_required(VERSION 3.15)
message(STATUS "Using custom nats.c module from package")

# --- 1. Define package paths ---
get_filename_component(NATS_CMAKE_DIR "${CMAKE_CURRENT_LIST_DIR}" REALPATH)
get_filename_component(NATS_PACKAGE_ROOT "${NATS_CMAKE_DIR}/.." REALPATH)

set(NATS_INCLUDE_DIR        "${NATS_PACKAGE_ROOT}/include")
set(NATS_DEBUG_LIB_DIR      "${NATS_PACKAGE_ROOT}/debug/lib")
set(NATS_RELEASE_LIB_DIR    "${NATS_PACKAGE_ROOT}/release/lib")

# --- 2. Create the IMPORTED target ---
# Using the target name convention from the nats.c build
if(NOT TARGET nats::nats_static)
    # It's a STATIC library
    add_library(nats::nats_static STATIC IMPORTED GLOBAL)
endif()

# --- 3. Set properties ---
if(WIN32)
    # Windows requires linking ws2_32 for networking
    set(NATS_SYSTEM_LIBS ws2_32.lib)

    set_target_properties(nats::nats_static PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${NATS_INCLUDE_DIR}"

        # --- Set library locations for each config ---
        IMPORTED_LOCATION_DEBUG           "${NATS_DEBUG_LIB_DIR}/nats_staticd.lib"
        IMPORTED_LOCATION_RELEASE         "${NATS_RELEASE_LIB_DIR}/nats_static.lib"
        IMPORTED_LOCATION_RELWITHDEBINFO  "${NATS_RELEASE_LIB_DIR}/nats_static.lib"
        IMPORTED_LOCATION_MINSIZEREL      "${NATS_RELEASE_LIB_DIR}/nats_static.lib"

        # --- Link system dependencies ---
        INTERFACE_LINK_LIBRARIES "${NATS_SYSTEM_LIBS};OpenSSL::SSL"
    )
else() # Linux/Unix
    find_package(Threads REQUIRED)
    # Linux might need pthread, potentially others depending on build options
    set(NATS_SYSTEM_LIBS Threads::Threads rt -lpthread)

    set_target_properties(nats::nats_static PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${NATS_INCLUDE_DIR}"

        # --- Set library locations for each config ---
        IMPORTED_LOCATION_DEBUG           "${NATS_DEBUG_LIB_DIR}/libnats_static.a" # Adjust name if needed
        IMPORTED_LOCATION_RELEASE         "${NATS_RELEASE_LIB_DIR}/libnats_static.a"
        IMPORTED_LOCATION_RELWITHDEBINFO  "${NATS_RELEASE_LIB_DIR}/libnats_static.a"
        IMPORTED_LOCATION_MINSIZEREL      "${NATS_RELEASE_LIB_DIR}/libnats_static.a"

        # --- Link system dependencies ---
        INTERFACE_LINK_LIBRARIES "${NATS_SYSTEM_LIBS};OpenSSL::SSL"
    )
endif()