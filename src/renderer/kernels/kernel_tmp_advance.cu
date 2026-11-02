#include "kernel_tmp_advance.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"

namespace magik
{
    static __global__ void kernel_tmp_advance(float* d_step_distance, vec4f* d_pos, vec4f* d_dir, uint32_t* n_step, uint32_t* d_advance_queue_count, uint32_t* d_advance_queue_id, uint32_t* d_intersect_queue_count, uint32_t* d_intersect_queue_id)
    {
        // Reads "advance queue"
        // Writes "intersect queue"

        uint32_t queue_index = blockIdx.x * blockDim.x + threadIdx.x;
        if(queue_index >= *d_advance_queue_count) return;
        uint32_t ray_id = d_advance_queue_id[queue_index];

        float h_now = d_step_distance[ray_id];
        d_pos[ray_id] = d_pos[ray_id] + d_dir[ray_id] * h_now;
        d_step_distance[ray_id] = 10.0f; // The value here is arbitrary. 
        n_step[ray_id]++;

        uint32_t slot = atomicAdd(d_intersect_queue_count, 1);
        d_intersect_queue_id[slot] = ray_id;
    }

    void launch_kernel_tmp_advance_async(magik_render_manager* manager, wavefront_ray_buffer_t* buffer)
    {
        uint32_t threads_per_block = manager->stage.settings.wavefront_threads_per_block;
        uint32_t n_block = ((buffer->x_resolution*buffer->y_resolution) + threads_per_block - 1) / threads_per_block;

        float* d_step_distance = buffer->ray_pool.get<step_distance_t>(); 
        vec4f* d_pos = buffer->ray_pool.get<position_t>(); 
        vec4f* d_dir = buffer->ray_pool.get<direction_t>(); 
        uint32_t* n_step = buffer->ray_pool.get<n_step_t>();

        kernel_tmp_advance<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(d_step_distance, d_pos, d_dir, n_step, buffer->advance_queue_A.d_count, buffer->advance_queue_A.d_id, buffer->intersect_queue.d_count, buffer->intersect_queue.d_id);
        check_cuda_errors(cudaGetLastError());

        reset_queue_async(buffer->advance_queue_A.d_count, &manager->cuda_stream);
    }
}
