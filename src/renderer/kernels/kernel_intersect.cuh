#pragma once

#include <cstdint>
#include "internal_math.h"
#include "wavefront.h"

namespace magik
{
    void launch_kernel_intersect_async(void** user_stream, wavefront_ray_buffer_t* buffer, vec3f box_min, vec3f box_max, vec3f light_min, vec3f light_max);
}
