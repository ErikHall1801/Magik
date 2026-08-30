/*
* 
*/

#pragma once

namespace magik::kernels
{
    void launch_test_pattern_gradient(float* d_rgba_fb, const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t x_threads_per_block, const uint32_t y_threads_per_block);

    void launch_test_pattern_mandelbrot(float* d_rgba_fb, const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t x_threads_per_block, const uint32_t y_threads_per_block);
}
