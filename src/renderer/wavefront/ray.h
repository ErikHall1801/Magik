#pragma once

#include "internal_math.h"
#include <cstdint>

namespace magik
{
    struct ray_queue
    {
        uint32_t count = 0;
        uint32_t* d_ray_id = nullptr;
    };

    struct ray_pool
    {
        // We dont need anything more complex here.

        vec3f* pos = nullptr;
        vec3f* dir = nullptr;
        vec3f* rgb = nullptr;
    };
}
