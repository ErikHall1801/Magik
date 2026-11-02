#pragma once

#include <cstdint>
#include "internal_math.h"
#include "wavefront.h"

namespace magik
{
    void launch_kernel_initialize_random_device_sync(void** user_stream, wavefront_buffer_t* wavefront_buffer, uint32_t x_resolution, uint32_t y_resolution);
}
