#pragma once

#include <cstdint>
#include "internal_math.h"
#include "wavefront.h"
#include "stage.h"

namespace magik
{
    void launch_kernel_advance_geodesic_async(wavefront_buffer_t& wavefront_buffer, cudaStream_t user_stream, stage_t& stage);
}
