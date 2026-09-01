/*
* This file bridges the gap between the host and device logic. 
* magik.cpp includes this standard C header file which contains
* all logic to interact with the device, without directly 
* invoking CUDA logic. This file never calls a CUDA function 
* directly, it calls a standard C++ function from the kernel 
* files which then launches the device code.  
*/

#pragma once
#include <stdint.h>

namespace magik::bridge
{
    float* host_allocate_device_memory(size_t size);

    float* host_allocate_host_memory(size_t size);

    void host_destroy_device_memory(float* d_ptr);

    void host_destroy_host_memory(float* h_ptr);

    void host_memcpy_device_to_host(float* h_ptr, float* d_ptr, size_t size);

    void call_test_pattern_gradient_kernel(float* d_rgba_fb, uint32_t x_resolution, uint32_t y_resolution);

    void call_test_pattern_mandelbrot_kernel(float* d_rgba_fb, uint32_t x_resolution, uint32_t y_resolution);

    void set_cuda_device(uint32_t cuda_device);
}
