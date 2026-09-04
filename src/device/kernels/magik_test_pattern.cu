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
    struct complex 
    {
        float x = 0.0f;
        float y = 0.0f;
    };

    static __device__ complex add(complex a, complex b)
    {
        complex c;
        c.x = a.x + b.x;
        c.y = a.y + b.y;
        return c;
    };

    static __device__ complex sqr(complex a){
        complex c;
        c.x = a.x*a.x - a.y*a.y;
        c.y = 2*a.x*a.y;
        return c;
    }

    static __device__ complex mapPoint(int width,int height,double radius,int x,int y){
        complex c;
        int l = (width<height)?width:height;
        
        c.x = 2*radius*(x - width/2.0)/l;
        c.y = 2*radius*(y - height/2.0)/l;
        
        return c;
    }

    static __global__ void test_pattern_julia_set(float* d_rgba_fb, uint32_t clock, float c0, float c1, float c2, float real, float imag, const uint32_t x_resolution, const uint32_t y_resolution)
    {
        if(!magik::utilities::is_valid_thread(x_resolution, y_resolution)) return;

        uint32_t i_x = threadIdx.x + blockIdx.x * blockDim.x;
        uint32_t i_y = threadIdx.y + blockIdx.y * blockDim.y;
        uint32_t thread_id = magik::utilities::get_n_dimensional_thread_id(x_resolution, 3);

        float radius = 1.5f;
        uint32_t max_iter = 32;
        uint32_t iter = 0;
        complex z0, z1;
        complex c = {real, imag};

        z0 = mapPoint(x_resolution, y_resolution, radius, i_x, i_y);

        for(iter = 0; iter < max_iter; iter++)
        {
            z1 = add(sqr(z0), c);
            if((z1.x * z1.x + z1.y * z1.y) > (radius * radius)) break;
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
            float mod_sq = z1.x * z1.x + z1.y * z1.y;
            
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

    void launch_test_pattern_julia_set(float* d_rgba_fb, const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t x_threads_per_block, const uint32_t y_threads_per_block, float c0, float c1, float c2, float real, float imag)
    {
        dim3 threads_per_block = dim3(x_threads_per_block, y_threads_per_block, 1);
        dim3 n_block = magik::utilities::compute_n_blocks(x_resolution, y_resolution, x_threads_per_block, y_threads_per_block);

        test_pattern_julia_set<<<n_block, threads_per_block>>>(d_rgba_fb, clock(), c0, c1, c2, real, imag, x_resolution, y_resolution);
        check_cuda_errors(cudaGetLastError());
        check_cuda_errors(cudaDeviceSynchronize());
    }
}
