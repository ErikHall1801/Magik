#pragma once

#include <cstdint>
#include "internal_math.h"
#include "wavefront.h"

namespace magik
{
    void launch_kernel_splat_to_render_buffer_sync(void** user_stream, uint32_t x_threads_per_block, uint32_t y_threads_per_block, wavefront_ray_buffer_t* buffer, float* d_data, uint32_t x_sample);
}
