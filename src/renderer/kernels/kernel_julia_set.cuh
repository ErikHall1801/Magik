#pragma once

#include <cstdint>

namespace magik
{
    void launch_kernel_julia_set(void* user_stream, float* d_target_framebuffer, const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t x_threads_per_block, const uint32_t y_threads_per_block, float c0, float c1, float c2, float real, float imag);
}
