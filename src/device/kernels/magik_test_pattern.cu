/*
* This is a test kernel which servers to showcase Magik´s file structure. The core idea is to 
* place each kernel into its own translation unit with a single CPU-side call function, to be
* used in a wavefront-style renderer. 
* All kernels are in their own .cu file and every kernel CUH file only includes a single host
* caller. 
* The reasoning behind this is part compartimentalization and part not wanting to use the -rdc
* flag in NVCC, which degrades performance and makes compilation more difficult. 
*/

#include "magik_test_pattern.cuh"
#include "magik_library.cuh"

namespace magik::kernels
{
    /* [SECTION] - Tests */
    static __global__ void test_pattern_gradient(float* d_rgba_fb, const uint32_t x_resolution, const uint32_t y_resolution)
    {
        if(!magik::utilities::is_valid_thread(x_resolution, y_resolution)) return;

        uint32_t i_x = threadIdx.x + blockIdx.x * blockDim.x;
        uint32_t i_y = threadIdx.y + blockIdx.y * blockDim.y;
        uint32_t thread_id = magik::utilities::get_n_dimensional_thread_id(x_resolution, 4);

        d_rgba_fb[thread_id + 0] = static_cast<float>(i_x) / static_cast<float>(x_resolution);
        d_rgba_fb[thread_id + 1] = static_cast<float>(i_y) / static_cast<float>(y_resolution);
        d_rgba_fb[thread_id + 2] = 0.0f;
        d_rgba_fb[thread_id + 3] = 1.0f;
    }

    static __global__ void test_pattern_mandelbrot(float* d_rgba_fb, const uint32_t x_resolution, const uint32_t y_resolution)
    {
        if(!magik::utilities::is_valid_thread(x_resolution, y_resolution)) return;

        uint32_t i_x = threadIdx.x + blockIdx.x * blockDim.x;
        uint32_t i_y = threadIdx.y + blockIdx.y * blockDim.y;
        uint32_t thread_id = magik::utilities::get_n_dimensional_thread_id(x_resolution, 4);

        float x0 = (static_cast<float>(i_x)-static_cast<float>(x_resolution/2)) / sqrt(static_cast<float>((x_resolution*y_resolution)))*3.3f;
        float y0 = (static_cast<float>(i_y)-static_cast<float>(y_resolution/2)) / sqrt(static_cast<float>((x_resolution*y_resolution)))*3.3f;
        float x1 = 0.0f;
        float y1 = 0.0f;
        float x2 = 0.0f;
        float y2 = 0.0f;

        uint32_t max_iter = 32;
        uint32_t iter = 0;

        for(uint32_t i = 0; i < max_iter; i++)
        {
            if(x2+y2 > 4.0f) break;

            x2 = x1*x1;
            y2 = y1*y1;
            y1 = 2.0f*x1*y1+y0;
            x1 = x2-y2+x0;
            iter++;
        }

        if(iter >= max_iter)
        {
            d_rgba_fb[thread_id + 0] = 0.0f;
            d_rgba_fb[thread_id + 1] = 0.0f;
            d_rgba_fb[thread_id + 2] = 0.0f;
        }
        else
        {
            float log_zn = logf(x2 + y2) / 2.0f;
            float nu = logf(log_zn / 0.69314718f) / 0.69314718f;
            float smooth_i = static_cast<float>(iter) + 1.0f - nu;
            float t = smooth_i / static_cast<float>(max_iter);

            float r = 0.5f + 0.5f * cosf(6.28318f * (1.0f * t + 0.0f));
            float g = 0.5f + 0.5f * cosf(6.28318f * (1.0f * t + 0.25f));
            float b = 0.5f + 0.5f * cosf(6.28318f * (1.0f * t + 0.5f));

            d_rgba_fb[thread_id + 0] = r;
            d_rgba_fb[thread_id + 1] = g;
            d_rgba_fb[thread_id + 2] = b;
        }
        
        d_rgba_fb[thread_id + 3] = 1.0f;
    }

    void launch_test_pattern_gradient(float* d_rgba_fb, const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t x_threads_per_block, const uint32_t y_threads_per_block)
    {
        dim3 threads_per_block = dim3(x_threads_per_block, y_threads_per_block, 1);
        dim3 n_block = magik::utilities::compute_n_blocks(x_resolution, y_resolution, x_threads_per_block, y_threads_per_block);

        test_pattern_gradient<<<n_block, threads_per_block>>>(d_rgba_fb, x_resolution, y_resolution);
        check_cuda_errors(cudaGetLastError());
        check_cuda_errors(cudaDeviceSynchronize());
    }

    void launch_test_pattern_mandelbrot(float* d_rgba_fb, const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t x_threads_per_block, const uint32_t y_threads_per_block)
    {
        dim3 threads_per_block = dim3(x_threads_per_block, y_threads_per_block, 1);
        dim3 n_block = magik::utilities::compute_n_blocks(x_resolution, y_resolution, x_threads_per_block, y_threads_per_block);

        test_pattern_mandelbrot<<<n_block, threads_per_block>>>(d_rgba_fb, x_resolution, y_resolution);
        check_cuda_errors(cudaGetLastError());
        check_cuda_errors(cudaDeviceSynchronize());
    }
}
