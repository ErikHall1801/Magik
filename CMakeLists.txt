# Standard setup
cmake_minimum_required(VERSION 3.21)
project(Magik VERSION 0.1.0 LANGUAGES CXX C CUDA)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_RUNTIME_LIBRARY Static)

# Link static libraries

# Declare a shared library
add_library(magik SHARED 
    # Renderer
        # bxdf

        # command
        src/renderer/command/command.cpp

        # framebuffer
        src/renderer/framebuffer/framebuffer.cpp
        src/renderer/framebuffer/opengl_interop.cu

        # kernels
        src/renderer/kernels/kernel_julia_set.cu

        # memory
        src/renderer/memory/host_arena.cpp

        # metrics

        # optics

        # stage

        # traceables

        src/renderer/renderer.cpp

    # Utility
        # cuda
        src/utility/cuda/cuda_device_utilities.cu
        src/utility/cuda/cuda_host_utilities.cu

        # error
        src/utility/error/magik_error.cpp

        # math

    # Core
    src/magik.cpp
)

# Define the location of the header files
target_include_directories(magik 
    # Public includes exposed to users of the library
    PUBLIC 
        ${CMAKE_CURRENT_SOURCE_DIR}/include/magik

    # Private includes for internal build
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src/renderer
        ${CMAKE_CURRENT_SOURCE_DIR}/src/renderer/bxdf
        ${CMAKE_CURRENT_SOURCE_DIR}/src/renderer/command
        ${CMAKE_CURRENT_SOURCE_DIR}/src/renderer/framebuffer
        ${CMAKE_CURRENT_SOURCE_DIR}/src/renderer/kernels
        ${CMAKE_CURRENT_SOURCE_DIR}/src/renderer/memory
        ${CMAKE_CURRENT_SOURCE_DIR}/src/renderer/metrics
        ${CMAKE_CURRENT_SOURCE_DIR}/src/renderer/optics
        ${CMAKE_CURRENT_SOURCE_DIR}/src/renderer/stage
        ${CMAKE_CURRENT_SOURCE_DIR}/src/renderer/traceables
        ${CMAKE_CURRENT_SOURCE_DIR}/src/renderer/wavefront

        ${CMAKE_CURRENT_SOURCE_DIR}/src/utility
        ${CMAKE_CURRENT_SOURCE_DIR}/src/utility/cuda
        ${CMAKE_CURRENT_SOURCE_DIR}/src/utility/error
        ${CMAKE_CURRENT_SOURCE_DIR}/src/utility/math
)

# Find packages
find_package(glad CONFIG REQUIRED)

target_link_libraries(magik PRIVATE
    glad::glad
)

find_package(CUDAToolkit REQUIRED)
target_link_libraries(magik PRIVATE glad::glad CUDA::cudart)

target_compile_definitions(magik PRIVATE MAGIK_BUILD_DLL)

# Set properties
target_compile_features(magik PRIVATE cxx_std_20)
set_target_properties(magik PROPERTIES
    CXX_EXTENSIONS OFF
    POSITION_INDEPENDENT_CODE ON

    # Linux specific so functions are hidden, following the Windows standard
    CXX_VISIBILITY_PRESET hidden
    C_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON

    CUDA_RUNTIME_LIBRARY Static
)

# Suppress static CRT conflicts caused by the static CUDA runtime in MSVC
if(MSVC)
    target_link_options(magik PRIVATE /NODEFAULTLIB:LIBCMT /NODEFAULTLIB:LIBCMTD)
endif()

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
