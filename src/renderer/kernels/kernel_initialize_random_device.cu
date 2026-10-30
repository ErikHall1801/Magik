#include "kernel_initialize_random_device.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"

namespace magik
{
    static __global__ void kernel_initialize_random_device(ray_pool_t ray_pool, uint32_t x_resolution, uint32_t y_resolution)
    {
        if(!is_valid_thread(x_resolution, y_resolution)) return;
        uint32_t thread_id = get_thread_id(x_resolution);

        curand_init(clock64(), thread_id, 0, &ray_pool.d_random_device[thread_id]);
    }

    void launch_kernel_initialize_random_device_sync(void** user_stream, ray_pool_t ray_pool, uint32_t x_resolution, uint32_t y_resolution)
    {
        dim3 threads_per_block = dim3(16, 16, 1);
        dim3 n_block = magik::compute_n_blocks(x_resolution, y_resolution, 16, 16);

        kernel_initialize_random_device<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(*user_stream)>>>(ray_pool, x_resolution, y_resolution);
        check_cuda_errors(cudaStreamSynchronize(static_cast<cudaStream_t>(*user_stream)));
        check_cuda_errors(cudaGetLastError());
    }
}
