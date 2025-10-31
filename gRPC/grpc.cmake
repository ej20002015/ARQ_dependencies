# creates:
#  - Imported targets: grpc_interface (library interface containing both grpc and libprotobuf dependencies), gRPC::protoc (protobuf compiler executable)

cmake_minimum_required(VERSION 3.15)

# --- 1. Define package paths ---
get_filename_component(GRPC_CMAKE_DIR "${CMAKE_CURRENT_LIST_DIR}" REALPATH)
get_filename_component(GRPC_PACKAGE_ROOT "${GRPC_CMAKE_DIR}/.." REALPATH)

set(GRPC_INCLUDE_DIR        "${GRPC_PACKAGE_ROOT}/include")
set(GRPC_DEBUG_LIB_DIR      "${GRPC_PACKAGE_ROOT}/debug/lib")
set(GRPC_RELEASE_LIB_DIR    "${GRPC_PACKAGE_ROOT}/release/lib")
set(GRPC_BIN_DIR            "${GRPC_PACKAGE_ROOT}/bin")

# --- Load protobuf_generate CMake function ---
include("${GRPC_CMAKE_DIR}/protobuf-generate.cmake")

# --- 2. Create the INTERFACE target: grpc_interface ---
if(NOT TARGET grpc_interface)
    # Create an INTERFACE library. It has no .lib file itself,
    # it just bundles dependencies.
    add_library(grpc_interface INTERFACE)
endif()

if(WIN32)
    set(EXE_EXTENSION ".exe")
else()
    set(EXE_EXTENSION "")
endif()

# --- 3. Create the IMPORTED target: gRPC::protoc ---
if(NOT TARGET gRPC::protoc)
    add_executable(gRPC::protoc IMPORTED GLOBAL)
    set_target_properties(gRPC::protoc PROPERTIES
        IMPORTED_LOCATION "${GRPC_BIN_DIR}/protoc${EXE_EXTENSION}"
    )
endif()

# --- Create the IMPORTED target: gRPC::grpc_cpp_plugin ---
if(NOT TARGET gRPC::grpc_cpp_plugin)
    add_executable(gRPC::grpc_cpp_plugin IMPORTED GLOBAL)
    set_target_properties(gRPC::grpc_cpp_plugin PROPERTIES
        IMPORTED_LOCATION "${GRPC_BIN_DIR}/grpc_cpp_plugin${EXE_EXTENSION}"
    )
endif()

# --- 4. Read Library Lists from Text Files ---

if(WIN32)
    set(LIB_TXT_FILE_SUFFIX "windows")
else()
    set(LIB_TXT_FILE_SUFFIX "linux")
endif()

set(DEBUG_LIST_PATH "${GRPC_CMAKE_DIR}/grpc_debug_libs_${LIB_TXT_FILE_SUFFIX}.txt")
set(RELEASE_LIST_PATH "${GRPC_CMAKE_DIR}/grpc_release_libs_${LIB_TXT_FILE_SUFFIX}.txt")

if(NOT EXISTS "${DEBUG_LIST_PATH}")
    message(FATAL_ERROR "[grpc.cmake] Debug lib list not found: ${DEBUG_LIST_PATH}")
endif()
if(NOT EXISTS "${RELEASE_LIST_PATH}")
    message(FATAL_ERROR "[grpc.cmake] Release lib list not found: ${RELEASE_LIST_PATH}")
endif()

# Read Debug libs
file(STRINGS "${DEBUG_LIST_PATH}" GRPC_DEBUG_LIB_NAMES)
set(GRPC_DEBUG_LIBS "") # Clear list
foreach(lib_name ${GRPC_DEBUG_LIB_NAMES})
    # set(full_path "${GRPC_DEBUG_LIB_DIR}/${lib_name}")
    # message(STATUS "[grpc.cmake] Appending Debug Lib: ${full_path}") # Uncomment for extreme detail
    list(APPEND GRPC_DEBUG_LIBS "${GRPC_DEBUG_LIB_DIR}/${lib_name}")
endforeach()

# Read Release libs
file(STRINGS "${RELEASE_LIST_PATH}" GRPC_RELEASE_LIB_NAMES)
set(GRPC_RELEASE_LIBS "") # Clear list
foreach(lib_name ${GRPC_RELEASE_LIB_NAMES})
    # set(full_path "${GRPC_RELEASE_LIB_DIR}/${lib_name}")
    # message(STATUS "[grpc.cmake] Appending Release Lib: ${full_path}") # Uncomment for extreme detail
    list(APPEND GRPC_RELEASE_LIBS "${GRPC_RELEASE_LIB_DIR}/${lib_name}")
endforeach()

# System libraries (these are the same for all configs)
if(WIN32)
    set(GRPC_SYSTEM_LIBS
        iphlpapi.lib
        ws2_32.lib
        crypt32.lib
    )
else()
    set(GRPC_SYSTEM_LIBS
        dl
        m
        rt
    )
endif()

# --- 5. Set target properties for grpc_interface ---
set_target_properties(grpc_interface PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${GRPC_INCLUDE_DIR}"
    
    # --- Set all dependencies ---
    # If config is Debug, use GRPC_DEBUG_LIBS, otherwise use GRPC_RELEASE_LIBS
    INTERFACE_LINK_LIBRARIES "$<IF:$<CONFIG:Debug>,${GRPC_DEBUG_LIBS},${GRPC_RELEASE_LIBS}>;${GRPC_SYSTEM_LIBS}"
)