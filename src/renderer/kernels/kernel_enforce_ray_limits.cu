#include "kernel_enforce_ray_limits.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"

namespace magik
{
    static __global__ void kernel_enforce_ray_limits(ray_pool_t ray_pool, ray_queue_t advance_queue_A, ray_queue_t advance_queue_B, ray_queue_t splat_queue)
    {
        // Reads "advance queue A"
        // Writes "advance queue B" or "splat queue"

        uint32_t queue_index = blockIdx.x * blockDim.x + threadIdx.x;
        if(queue_index >= *advance_queue_A.d_count) return;
        uint32_t ray_id = advance_queue_A.d_id[queue_index];

        uint32_t n_step = ray_pool.n_step[ray_id];

        bool terminate = false;

        if(n_step > 24)
        {
            terminate = true;
        }

        uint32_t slot = 0;

        if(terminate) // Note, the ray is terminated, so it carries no radiance. We can go directly to the splat queue. 
        {
            slot = atomicAdd(splat_queue.d_count, 1);
            splat_queue.d_id[slot] = ray_id;
        }
        else
        {
            slot = atomicAdd(advance_queue_B.d_count, 1);
            advance_queue_B.d_id[slot] = ray_id;
        }
    }

    void launch_kernel_enforce_ray_limits_async(magik_render_manager* manager, wavefront_ray_buffer_t* buffer)
    {
        uint32_t threads_per_block = manager->stage.settings.wavefront_threads_per_block;
        uint32_t n_block = ((buffer->x_resolution*buffer->y_resolution) + threads_per_block - 1) / threads_per_block;

        kernel_enforce_ray_limits<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(buffer->ray_pool, buffer->advance_queue_A, buffer->advance_queue_B, buffer->splat_queue);
        check_cuda_errors(cudaGetLastError());

        reset_queue_async(buffer->advance_queue_A.d_count, &manager->cuda_stream);
    }
}
