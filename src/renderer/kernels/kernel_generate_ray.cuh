#pragma once

#include <cstdint>
#include "internal_math.h"
#include "wavefront.h"

namespace magik
{
    void launch_kernel_generate_ray_sync(void** user_stream, uint32_t x_threads_per_block, uint32_t y_threads_per_block, uint32_t x_resolution, uint32_t y_resolution, ray_pool_t ray_pool, ray_queue_t advance_queue, float focal_length, float sensor_diagonal_mm, vec3f position, mat3f orientation);
}
