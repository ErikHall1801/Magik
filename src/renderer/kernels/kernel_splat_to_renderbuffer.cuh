#pragma once

#include <cstdint>
#include "internal_math.h"
#include "wavefront.h"

namespace magik
{
    void launch_kernel_splat_to_renderbuffer_async(wavefront_buffer_t& wavefront_buffer, cudaStream_t user_stream, render_settings_t& render_settings, color_settings_t& color_settings, color_pipeline_descriptor_t& color_pipeline_descriptor, uint32_t x_sample, float* d_renderbuffer);
}
