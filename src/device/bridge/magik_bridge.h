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
#include <cstddef>
#include "magik_error.h"

namespace magik::bridge
{
    bool host_gl_init(void* (*loader)(const char*));

    int32_t host_get_n_cuda_device();

    void host_get_system_info();

    float* host_allocate_device_memory(size_t size);

    float* host_allocate_host_memory(size_t size);

    void host_destroy_device_memory(float* d_ptr);

    void host_destroy_host_memory(float* h_ptr);

    void host_memcpy_device_to_host(float* h_ptr, float* d_ptr, size_t size);

    void host_memcpy_device_to_device(float* d_ptr_0, float* d_ptr_1, size_t size);

    void call_test_pattern_julia_set_kernel(void* user_stream, float* d_rgba_fb, uint32_t x_resolution, uint32_t y_resolution, float c0, float c1, float c2, float real, float imag);

    void set_cuda_device(uint32_t cuda_device);

    e_magik_result_types host_allocate_gl_buffer(const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t channels, uint32_t* gl_buffer_id, void** cuda_resource);

    e_magik_result_types host_free_gl_buffer(uint32_t* gl_buffer_id, void** cuda_resource);

    e_magik_result_types host_map_cuda_to_gl_buffer(const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t channels, void** cuda_resource, float* d_ptr);

    void host_create_cuda_stream(void** user_stream);

    void host_destroy_cuda_stream(void** user_stream);

    void host_cuda_semaphore(void** user_stream);
}
