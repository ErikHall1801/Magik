#pragma once

#include "magik_error.h"
#include "cuda_defines.cuh"

#include <stdint.h>

namespace magik
{
    bool opengl_init(void* (*loader)(const char*));

    e_magik_result_types get_opengl_info();

    e_magik_result_types allocate_opengl_buffer(const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t channels, uint32_t* gl_buffer_id, void** cuda_resource);

    e_magik_result_types free_opengl_buffer(uint32_t* gl_buffer_id, void** cuda_resource);

    e_magik_result_types map_cuda_to_opengl_buffer(const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t channels, void** cuda_resource, float* d_ptr);
}
