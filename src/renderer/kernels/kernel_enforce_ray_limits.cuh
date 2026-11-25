#pragma once

#include <cstdint>
#include "internal_math.h"
#include "wavefront.h"

namespace magik
{
    void launch_kernel_enforce_ray_limits_async(wavefront_buffer_t& wavefront_buffer, cudaStream_t user_stream, render_settings_t& render_settings);
}
