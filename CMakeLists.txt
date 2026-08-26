# Standard setup
cmake_minimum_required(VERSION 3.21)
project(Magik VERSION 0.1.0 LANGUAGES CXX C CUDA)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_CUDA_RUNTIME_LIBRARY Static)

# Find packages
# find_package(xyz CONFIG REQUIERED) for example

# Link static libraries

# Declare a shared library
add_library(magik SHARED src/magik.cpp src/cuda/cuda_test.cu)

# Define the location of the header files
target_include_directories(magik 
    PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include/magik

    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/src/cuda
)

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

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
