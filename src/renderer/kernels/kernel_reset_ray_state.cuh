#pragma once

#include <cstdint>
#include "internal_math.h"
#include "wavefront.h"

namespace magik
{
    void launch_kernel_reset_ray_state_sync(void** user_stream, ray_pool_t ray_pool, uint32_t x_resolution, uint32_t y_resolution);
}
