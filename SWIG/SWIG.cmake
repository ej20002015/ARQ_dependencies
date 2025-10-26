# Defines variables for using swig

# Get the directory this script is in (e.g., .../cmake/)
get_filename_component(SWIG_CMAKE_DIR "${CMAKE_CURRENT_LIST_DIR}" REALPATH)
# Get the root of the package (e.g., .../cmake/../)
get_filename_component(SWIG_PACKAGE_ROOT "${SWIG_CMAKE_DIR}/.." REALPATH)

set(SWIG_EXECUTABLE ${SWIG_PACKAGE_ROOT}/SWIG/swig.exe)
set(SWIG_DIR ${SWIG_PACKAGE_ROOT}/SWIG/Lib)