#pragma once

#include <cstdint>
#include "internal_math.h"
#include "wavefront.h"

namespace magik
{
    void launch_kernel_generate_thin_lensray_async(void** user_stream, uint32_t x_threads_per_block, uint32_t y_threads_per_block, wavefront_ray_buffer_t* buffer, float focal_length, float sensor_diagonal_mm, vec3f position, mat3f orientation);
}
