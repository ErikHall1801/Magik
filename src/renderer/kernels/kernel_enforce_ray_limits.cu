#include "kernel_enforce_ray_limits.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"

namespace magik
{
    static __global__ void kernel_enforce_ray_limits(uint32_t* d_n_step, uint32_t* d_advance_A_queue_count, uint32_t* d_advance_A_queue_id, uint32_t* d_advance_B_queue_count, uint32_t* d_advance_B_queue_id, uint32_t* d_splat_queue_count, uint32_t* d_splat_queue_id)
    {
        // Reads "advance queue A"
        // Writes "advance queue B" or "splat queue"

        uint32_t queue_index = blockIdx.x * blockDim.x + threadIdx.x;
        if(queue_index >= *d_advance_A_queue_count) return;
        uint32_t ray_id = d_advance_A_queue_id[queue_index];

        uint32_t n_step = d_n_step[ray_id];

        bool terminate = false;

        if(n_step > 24)
        {
            terminate = true;
        }

        uint32_t slot = 0;

        if(terminate) // Note, the ray is terminated, so it carries no radiance. We can go directly to the splat queue. 
        {
            slot = atomicAdd(d_splat_queue_count, 1);
            d_splat_queue_id[slot] = ray_id;
        }
        else
        {
            slot = atomicAdd(d_advance_B_queue_count, 1);
            d_advance_B_queue_id[slot] = ray_id;
        }
    }

    void launch_kernel_enforce_ray_limits_async(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer)
    {
        uint32_t threads_per_block = manager->stage.settings.wavefront_threads_per_block;
        uint32_t n_block = (wavefront_buffer->queue_ceiling + threads_per_block - 1) / threads_per_block;

        uint32_t* d_n_step = wavefront_buffer->ray_pool.get<n_step_t>();

        uint32_t* d_advance_A_queue_count = wavefront_buffer->queue_pool.get_count_ptr<advance_A_queue_t>();
        uint32_t* d_advance_A_queue_id = wavefront_buffer->queue_pool.get_id_ptr<advance_A_queue_t>();

        uint32_t* d_advance_B_queue_count = wavefront_buffer->queue_pool.get_count_ptr<advance_B_queue_t>();
        uint32_t* d_advance_B_queue_id = wavefront_buffer->queue_pool.get_id_ptr<advance_B_queue_t>();

        uint32_t* d_splat_queue_count = wavefront_buffer->queue_pool.get_count_ptr<splat_queue_t>();
        uint32_t* d_splat_queue_id = wavefront_buffer->queue_pool.get_id_ptr<splat_queue_t>();

        kernel_enforce_ray_limits<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(d_n_step, d_advance_A_queue_count, d_advance_A_queue_id, d_advance_B_queue_count, d_advance_B_queue_id, d_splat_queue_count, d_splat_queue_id);
        check_cuda_errors(cudaGetLastError());

        wavefront_buffer->queue_pool.zero_count_async<advance_A_queue_t>(static_cast<cudaStream_t>(manager->cuda_stream));
    }
}
