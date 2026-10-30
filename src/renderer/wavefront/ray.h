#pragma once

#include "internal_math.h"
#include <cstdint>

namespace magik
{
    struct ray_queue_t
    {
        uint32_t* d_count = nullptr; 
        uint32_t* d_id = nullptr;
    };

    struct ray_pool_t
    {
        // We dont need anything more complex here.

        vec3f* d_pos = nullptr;
        vec3f* d_dir = nullptr;

        float* d_step_distance = nullptr;

        // All of these need to be re-initalized each sample to sensible values. 
        vec3f* d_rgb = nullptr;
        uint32_t* n_step = nullptr;
        uint32_t* hit_id = nullptr;
        vec3f* hit_normal = nullptr;
    };
}
