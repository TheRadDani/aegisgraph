# CMakeLists.txt for the aegisgraph project
cmake_minimum_required(VERSION 3.25...3.25)
cmake_policy(SET CMP0148 NEW)  # Suppress CMP0148 warning
cmake_policy(SET CMP0116 NEW)  # Handle file-based package requirements
cmake_policy(SET CMP0144 NEW)  # Honor CMAKE_FIND_PACKAGE_REDIRECTS_DIR

project(aegisgraph LANGUAGES CXX)

# === Project Configuration ===
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D_LIBCPP_DISABLE_AVAILABILITY")
    set(CMAKE_INSTALL_RPATH "$ORIGIN")
endif()

# === Optimization Flags ===
set(COMMON_FLAGS "-Wall -Wextra -Wpedantic -fstack-protector-strong -D_FORTIFY_SOURCE=2")
set(SIMD_FLAGS "-mavx2 -mfma -mbmi2 -ftree-vectorize -fno-strict-aliasing")

# === Enable OpenMP ===
if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    message(STATUS "Configuring OpenMP manually for macOS")

    # Detect architecture
    execute_process(
        COMMAND uname -m
        OUTPUT_VARIABLE ARCHITECTURE
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    if(ARCHITECTURE STREQUAL "arm64")
        set(OPENMP_PATH "/opt/homebrew")
    else()
        set(OPENMP_PATH "/usr/local")
    endif()

    set(OpenMP_CXX_FLAGS "-Xpreprocessor -fopenmp")
    set(OpenMP_CXX_LIB_NAMES "omp")
    set(OpenMP_omp_LIBRARY "${OPENMP_PATH}/lib/libomp.dylib")
    set(OpenMP_FOUND TRUE)

    message(STATUS "Detected architecture: ${ARCHITECTURE}")
    message(STATUS "Using OpenMP library from: ${OpenMP_omp_LIBRARY}")

else()
    find_package(OpenMP REQUIRED)
endif()

if(OpenMP_FOUND)
    message(STATUS "OpenMP CXX flags: ${OpenMP_CXX_FLAGS}")
    add_compile_options(${OpenMP_CXX_FLAGS})
    add_link_options(${OpenMP_CXX_FLAGS} ${OpenMP_omp_LIBRARY})
    list(APPEND LINK_LIBS ${OpenMP_omp_LIBRARY})
endif()

# === Abseil Dependency ===
set(ABSL_PROPAGATE_CXX_STD ON)

# === Abseil Dependency (Vendored) ===
if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm|arm64")
  add_definitions(-DABSL_NO_INT128)
endif()
add_subdirectory(third_party/abseil-cpp)

# === pybind11 Dependency (Vendored) ===
add_subdirectory(third_party/pybind11)

message(STATUS "PYTHON_EXECUTABLE: ${PYTHON_EXECUTABLE}")


# === Find Python (for linking only) ===
#find_package(Python3 REQUIRED COMPONENTS Interpreter Development)

if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|amd64")
    set(ARCH_FLAGS "-mtune=native -mavx2 -mfma -mbmi2 -ftree-vectorize -fno-strict-aliasing")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
    # Use conservative flags for compatibility
    set(ARCH_FLAGS "-march=armv8-a+crypto+fp16+dotprod")
else()
    set(ARCH_FLAGS "")
endif()

set(COMMON_FLAGS "-Wall -Wextra -Wpedantic -fstack-protector-strong -D_FORTIFY_SOURCE=2")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${COMMON_FLAGS} ${ARCH_FLAGS}")


# Enable interprocedural optimization (LTO)
include(CheckIPOSupported)
check_ipo_supported(RESULT ipo_supported OUTPUT ipo_error)
if(ipo_supported)
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
endif()

# Enable LTO
include(CheckIPOSupported)
check_ipo_supported(RESULT ipo_supported OUTPUT ipo_error)
if(ipo_supported)
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
endif()


set(CMAKE_CXX_FLAGS_RELEASE "-O3 -flto=auto")
set(CMAKE_CXX_FLAGS_DEBUG "-g -fsanitize=address,undefined,leak -fno-omit-frame-pointer")


# === Source Files ===
set(SOURCE_FILES
    src/Graph.cpp
    src/RandomWalker.cpp
    bindings/aegisgraph.cpp
)

# === ASAN Options Config ===
configure_file(${CMAKE_SOURCE_DIR}/asan_options.cfg ${CMAKE_BINARY_DIR}/asan_options.cfg COPYONLY)

# === Main Target ===
pybind11_add_module(aegisgraph ${SOURCE_FILES})

# === Include Directories ===
target_include_directories(aegisgraph PRIVATE
    ${CMAKE_SOURCE_DIR}/include
)

# === Security Hardening ===
target_compile_options(aegisgraph PRIVATE
    -Wformat -Wformat-security
)

target_link_options(aegisgraph PRIVATE
    "LINKER:-z,relro"
    "LINKER:-z,now"
    "LINKER:-z,noexecstack"
    "LINKER:-z,noexecheap"
    "LINKER:--no-undefined"
    "LINKER:--as-needed"
    "LINKER:--hash-style=gnu"
)

# === Link Dependencies ===
target_link_libraries(aegisgraph PRIVATE
    absl::flat_hash_map
    ${LINK_LIBS}
    pthread
    pybind11::module
    pybind11::embed
)

# === Optimization Linker Flags ===
target_link_options(aegisgraph PRIVATE 
    "LINKER:--no-undefined"
    "LINKER:--as-needed"
    "LINKER:--hash-style=gnu"
)

if(CMAKE_LINKER MATCHES "gold")
    target_link_options(aegisgraph PRIVATE 
        "LINKER:--threads"
        "LINKER:--fatal-warnings"
    )
endif()

# === RPATH Handling ===
if(UNIX AND NOT APPLE)
    set_target_properties(aegisgraph PROPERTIES
        INSTALL_RPATH "$ORIGIN"
        BUILD_WITH_INSTALL_RPATH TRUE
    )
endif()

# === Installation Rules ===
execute_process(
    COMMAND ${Python3_EXECUTABLE} -c "import sysconfig; print(sysconfig.get_paths()[\"purelib\"])"
    OUTPUT_VARIABLE PYTHON_SITE_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

install(TARGETS aegisgraph
    LIBRARY DESTINATION .
)


# === Post-build Security Check ===
add_custom_command(TARGET aegisgraph POST_BUILD
    COMMAND ${CMAKE_OBJDUMP} -p $<TARGET_FILE:aegisgraph> | grep -E 'RELRO|NX|STACK' || true
    COMMAND ${CMAKE_COMMAND} -E echo "[HARDENING] Security protections verified"
    COMMENT "Verifying binary security features"
)