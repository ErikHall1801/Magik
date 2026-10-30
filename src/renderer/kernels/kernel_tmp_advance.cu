#include "kernel_tmp_advance.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"

namespace magik
{
    static __global__ void kernel_tmp_advance(uint32_t* d_advance_queue_count, uint32_t* d_advance_queue_id, uint32_t* d_intersect_queue_count, uint32_t* d_intersect_queue_id, ray_pool_t ray_pool)
    {
        // Reads "advance queue"
        // Writes "intersect queue"

        uint32_t queue_index = blockIdx.x * blockDim.x + threadIdx.x;
        if(queue_index >= *d_advance_queue_count) return;
        uint32_t ray_id = d_advance_queue_id[queue_index];

        float h_now = ray_pool.d_step_distance[ray_id];
        ray_pool.d_pos[ray_id] = ray_pool.d_pos[ray_id] + ray_pool.d_dir[ray_id] * h_now;
        ray_pool.d_step_distance[ray_id] = 10.0f; // The value here is arbitrary. 
        ray_pool.n_step[ray_id]++;

        uint32_t slot = atomicAdd(d_intersect_queue_count, 1);
        d_intersect_queue_id[slot] = ray_id;
    }

    void launch_kernel_tmp_advance_async(void** user_stream, uint32_t x_resolution, uint32_t y_resolution, ray_pool_t ray_pool, ray_queue_t advance_queue, ray_queue_t intersect_queue)
    {
        uint32_t threads_per_block = 256; // 16²
        uint32_t n_block = ((x_resolution*y_resolution) + threads_per_block - 1) / threads_per_block;

        kernel_tmp_advance<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(*user_stream)>>>(advance_queue.d_count, advance_queue.d_id, intersect_queue.d_count, intersect_queue.d_id, ray_pool);
        check_cuda_errors(cudaGetLastError());
    }
}
