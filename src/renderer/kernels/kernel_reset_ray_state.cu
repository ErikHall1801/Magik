#include "kernel_reset_ray_state.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"

namespace magik
{
    static __global__ void kernel_reset_ray_state(ray_pool_t ray_pool, uint32_t x_resolution, uint32_t y_resolution)
    {
        if(!magik::is_valid_thread(x_resolution, y_resolution)) return;

        uint32_t i_x = threadIdx.x + blockIdx.x * blockDim.x;
        uint32_t i_y = threadIdx.y + blockIdx.y * blockDim.y;
        uint32_t thread_id = magik::get_n_dimensional_thread_id(x_resolution, 1);

        ray_pool.n_step[thread_id] = 0;
        ray_pool.d_rgb[thread_id] = vec3f{0.0f, 0.0f, 0.0f};
    }

    void launch_kernel_reset_ray_state_sync(void** user_stream, ray_pool_t ray_pool, uint32_t x_resolution, uint32_t y_resolution)
    {
        dim3 threads_per_block = dim3(16, 16, 1);
        dim3 n_block = magik::compute_n_blocks(x_resolution, y_resolution, 16, 16);

        kernel_reset_ray_state<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(*user_stream)>>>(ray_pool, x_resolution, y_resolution);
        check_cuda_errors(cudaStreamSynchronize(static_cast<cudaStream_t>(*user_stream)));
        check_cuda_errors(cudaGetLastError());
    }
}
