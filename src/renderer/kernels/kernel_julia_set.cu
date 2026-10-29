#include "kernel_julia_set.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"
#include "internal_math.h"

namespace magik
{
    static __device__ magik::complex_type<float, float> mapPoint(int width,int height,double radius,int x,int y)
    {
        magik::complex_type<float, float> c;
        int l = (width<height)?width:height;
        
        c.real = 2.0f*radius*(x - width/2.0f)/l;
        c.imag = 2.0f*radius*(y - height/2.0f)/l;

        return c;
    }

    static __global__ void test_pattern_julia_set(float* d_rgba_fb, float c0, float c1, float c2, float real, float imag, const uint32_t x_resolution, const uint32_t y_resolution)
    {
        if(!magik::is_valid_thread(x_resolution, y_resolution)) return;

        uint32_t i_x = threadIdx.x + blockIdx.x * blockDim.x;
        uint32_t i_y = threadIdx.y + blockIdx.y * blockDim.y;
        uint32_t thread_id = magik::get_n_dimensional_thread_id(x_resolution, 3);

        float radius = 1.5f;
        uint32_t max_iter = 256;
        uint32_t iter = 0;

        magik::complex_type<float, float> z0, z1, c = {real, imag};
        z0 = mapPoint(x_resolution, y_resolution, radius, i_x, i_y);

        for(iter = 0; iter < max_iter; iter++)
        {
            z1 = z0*z0 + c;
            if((z1.real * z1.real + z1.imag * z1.imag) > (radius * radius)) break;
            z0 = z1;
        }

        if(iter == max_iter)
        {
            d_rgba_fb[thread_id + 0] = 0.0f;
            d_rgba_fb[thread_id + 1] = 0.0f;
            d_rgba_fb[thread_id + 2] = 0.0f;
        }
        else
        {
            float mod_sq = z1.real * z1.real + z1.imag * z1.imag;
            
            float log_zn = logf(mod_sq) / 2.0f;
            float nu = logf(log_zn / 0.69314718f) / 0.69314718f;
            float smooth_i = static_cast<float>(iter) + 1.0f - nu;
            
            float t = smooth_i * 0.05f;

            float r = 0.5f + 0.5f * cosf(6.28318f * (t + c0));
            float g = 0.5f + 0.5f * cosf(6.28318f * (t + c1));
            float b = 0.5f + 0.5f * cosf(6.28318f * (t + c2));

            d_rgba_fb[thread_id + 0] = r;
            d_rgba_fb[thread_id + 1] = g;
            d_rgba_fb[thread_id + 2] = b;
        }
    }

    void launch_kernel_julia_set(void* user_stream, float* d_target_framebuffer, const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t x_threads_per_block, const uint32_t y_threads_per_block, float c0, float c1, float c2, float real, float imag)
    {
        dim3 threads_per_block = dim3(x_threads_per_block, y_threads_per_block, 1);
        dim3 n_block = magik::compute_n_blocks(x_resolution, y_resolution, x_threads_per_block, y_threads_per_block);

        test_pattern_julia_set<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(user_stream)>>>(d_target_framebuffer, c0, c1, c2, real, imag, x_resolution, y_resolution);
        check_cuda_errors(cudaGetLastError());
    }
}
