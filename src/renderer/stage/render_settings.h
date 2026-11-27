#pragma once

#include "internal_math.h"
#include <cstdint>

namespace magik
{
    struct render_settings_t
    {
        // CUDA Specific
        uint32_t threads_per_block_x = 16;
        uint32_t threads_per_block_y = 16;
        uint32_t wavefront_threads_per_block = 256;

        // Ray limits
        uint32_t n_geodesic_step_limit = 512;
        uint32_t x_sample_limit = 1024;
        uint32_t n_reflected_limit = 10; // Once the bxdf is re-integrated we have to include a sub-section for the layered bounces ! 
    };
}
