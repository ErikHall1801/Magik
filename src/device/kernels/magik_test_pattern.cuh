/*
* 
*/

#pragma once

namespace magik::kernels
{
    void launch_test_pattern_julia_set(float* d_rgba_fb, const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t x_threads_per_block, const uint32_t y_threads_per_block, float c0, float c1, float c2);
}
