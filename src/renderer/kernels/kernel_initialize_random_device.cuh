#pragma once

#include <cstdint>
#include "internal_math.h"
#include "wavefront.h"

namespace magik
{
    void launch_kernel_initialize_random_device_async(wavefront_buffer_t& wavefront_buffer, cudaStream_t user_stream);
}
