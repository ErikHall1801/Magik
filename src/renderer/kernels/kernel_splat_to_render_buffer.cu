#include "kernel_splat_to_render_buffer.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"

namespace magik
{
    static __global__ void kernel_splat_to_render_buffer(float* d_data, vec3f* d_pos, uint32_t x_resolution, uint32_t y_resolution)
    {
        if(!magik::is_valid_thread(x_resolution, y_resolution)) return;

        uint32_t i_x = threadIdx.x + blockIdx.x * blockDim.x;
        uint32_t i_y = threadIdx.y + blockIdx.y * blockDim.y;

        uint32_t thread_id = magik::get_n_dimensional_thread_id(x_resolution, 1);
        uint32_t render_buffer_id = magik::get_n_dimensional_thread_id(x_resolution, 3);

        d_data[render_buffer_id + 0] = d_pos[thread_id].x;
        d_data[render_buffer_id + 1] = d_pos[thread_id].y;
        d_data[render_buffer_id + 2] = d_pos[thread_id].z;
    }

    void launch_kernel_splat_to_render_buffer_sync(void** user_stream, uint32_t x_threads_per_block, uint32_t y_threads_per_block, uint32_t x_resolution, uint32_t y_resolution, float* d_data, vec3f* d_pos)
    {
        dim3 threads_per_block = dim3(x_threads_per_block, y_threads_per_block, 1);
        dim3 n_block = magik::compute_n_blocks(x_resolution, y_resolution, x_threads_per_block, y_threads_per_block);

        kernel_splat_to_render_buffer<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(*user_stream)>>>(d_data, d_pos, x_resolution, y_resolution);
        check_cuda_errors(cudaStreamSynchronize(static_cast<cudaStream_t>(*user_stream)));
        check_cuda_errors(cudaGetLastError());
    }
}
