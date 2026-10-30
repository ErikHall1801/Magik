#pragma once

#include "internal_math.h"
#include <cstdint>

namespace magik
{
    struct ray_queue_t
    {
        /*
        Now things get interesting, because this "count" value needs to be on the GPU. 
        Moreover, we have to actually consider how this architecture will work. In depth. 

        */

        uint32_t* d_count = nullptr; 
        uint32_t* d_id = nullptr;
    };

    struct ray_pool_t
    {
        // We dont need anything more complex here.

        vec3f* d_pos = nullptr;
        vec3f* d_dir = nullptr;
        vec3f* d_rgb = nullptr;

        float* d_step_distance = nullptr;
    };
}
