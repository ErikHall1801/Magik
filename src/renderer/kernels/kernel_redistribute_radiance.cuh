#pragma once

#include <cstdint>
#include "internal_math.h"
#include "wavefront.h"

namespace magik
{
    void launch_kernel_redistribute_radiance_async(wavefront_buffer_t& wavefront_buffer, cudaStream_t user_stream, stage_t& stage);
}
