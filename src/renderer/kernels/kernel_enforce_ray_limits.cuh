#pragma once

#include <cstdint>
#include "internal_math.h"
#include "wavefront.h"

namespace magik
{
    void launch_kernel_enforce_ray_limits_async(void** user_stream, uint32_t x_resolution, uint32_t y_resolution, ray_pool_t ray_pool, ray_queue_t advance_queue_A, ray_queue_t advance_queue_B, ray_queue_t color_queue);
}
