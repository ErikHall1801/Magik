#pragma once

#include <cstdint>
#include "internal_math.h"
#include "wavefront.h"

namespace magik
{
    void launch_kernel_enforce_ray_limits_async(void** user_stream, wavefront_ray_buffer_t* buffer);
}
