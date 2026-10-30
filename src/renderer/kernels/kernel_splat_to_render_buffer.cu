#include "kernel_splat_to_render_buffer.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"

namespace magik
{
    static __global__ void kernel_splat_to_render_buffer(float* d_data, vec3f* d_rgb, uint32_t x_resolution, uint32_t y_resolution, uint32_t x_sample)
    {
        if(!magik::is_valid_thread(x_resolution, y_resolution)) return;

        uint32_t i_x = threadIdx.x + blockIdx.x * blockDim.x;
        uint32_t i_y = threadIdx.y + blockIdx.y * blockDim.y;

        uint32_t thread_id = magik::get_n_dimensional_thread_id(x_resolution, 1);
        uint32_t render_buffer_id = magik::get_n_dimensional_thread_id(x_resolution, 3);

        /*
        Conceptually, what is the idea here ? 
        
        We are at sample N, and wish to accumulate it into the buffer. 
        The buffer was last normalized with N-1. Thus, we have to 
        multiply by N-1, add the new color, then divide again. 

        */

        float x_samplef = (float)(x_sample);
        vec3f old_color = vec3f{d_data[render_buffer_id + 0], d_data[render_buffer_id + 1], d_data[render_buffer_id + 2]};
        vec3f new_color = ((old_color*x_samplef)+d_rgb[thread_id])/(x_samplef+1.0f);

        d_data[render_buffer_id + 0] = new_color.x;
        d_data[render_buffer_id + 1] = new_color.y;
        d_data[render_buffer_id + 2] = new_color.z;
    }

    void launch_kernel_splat_to_render_buffer_sync(void** user_stream, uint32_t x_threads_per_block, uint32_t y_threads_per_block, uint32_t x_resolution, uint32_t y_resolution, float* d_data, vec3f* d_rgb, uint32_t x_sample)
    {
        dim3 threads_per_block = dim3(x_threads_per_block, y_threads_per_block, 1);
        dim3 n_block = magik::compute_n_blocks(x_resolution, y_resolution, x_threads_per_block, y_threads_per_block);

        kernel_splat_to_render_buffer<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(*user_stream)>>>(d_data, d_rgb, x_resolution, y_resolution, x_sample);
        check_cuda_errors(cudaStreamSynchronize(static_cast<cudaStream_t>(*user_stream)));
        check_cuda_errors(cudaGetLastError());
    }
}
