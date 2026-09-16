#pragma once
#include <glad/glad.h>
#include "cuda_runtime.h"
#include "cuda_gl_interop.h"
#include "magik_library.cuh"

namespace magik::interops
{
    bool gl_init(void* (*loader)(const char*));

    void get_gl_info();

    void allocate_gl_buffer(const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t channels, uint32_t* gl_buffer_id, void** cuda_resource);

    void free_gl_buffer(uint32_t* gl_buffer_id, void** cuda_resource);

    void map_cuda_to_gl_buffer(const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t channels, void** cuda_resource, float* d_ptr);
}
