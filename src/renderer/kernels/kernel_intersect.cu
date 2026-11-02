#include "kernel_intersect.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"
#include "traceables.cuh"

namespace magik
{
    static __global__ void kernel_intersect(vec4f* d_pos, vec4f* d_dir, float* d_step_distance, uint32_t* hit_id, vec4f* hit_normal, ray_queue_t intersect_queue, ray_queue_t advance_queue, ray_queue_t bxdf_queue, vec3f box_min, vec3f box_max, vec3f light_min, vec3f light_max)
    {
        // Reads "intersect queue"
        // Writes "advance queue" or "bxdf queue"

        // 1. Fetch ray id
        uint32_t queue_index = blockIdx.x * blockDim.x + threadIdx.x;
        if(queue_index >= *intersect_queue.d_count) return;
        uint32_t ray_id = intersect_queue.d_id[queue_index];

        // 2. Fetch ray-specific data
        vec3f ray_orig = vec3f{d_pos[ray_id].x, d_pos[ray_id].y, d_pos[ray_id].z};
        vec3f ray_dir = vec3f{d_dir[ray_id].x, d_dir[ray_id].y, d_dir[ray_id].z};
        float distance = d_step_distance[ray_id];

        // 3. Do work
        bool hit_any = false;
        uint32_t local_hit_id = 0;

        float closest_hit = 1e30f;
        vec3f closest_normal;
        float candidate_hit_parameter = 1e30f;
        vec3f candidate_hit_normal;

        if(affine_aabb_intersection(&candidate_hit_parameter, &candidate_hit_normal, ray_dir, ray_orig, 1.0f/distance, box_min, box_max))
        {
            closest_hit = candidate_hit_parameter;
            closest_normal = candidate_hit_normal;
            hit_any = true;
            local_hit_id = 1;
        }

        candidate_hit_parameter = 1e30f;

        if(affine_aabb_intersection(&candidate_hit_parameter, &candidate_hit_normal, ray_dir, ray_orig, 1.0f/distance, light_min, light_max))
        {
            if(candidate_hit_parameter < closest_hit)
            {
                closest_hit = candidate_hit_parameter;
                closest_normal = candidate_hit_normal;
                hit_any = true;
                local_hit_id = 2;
            }
        }

        // 4. Append to queues
        uint32_t slot = 0;

        if(hit_any)
        {
            slot = atomicAdd(bxdf_queue.d_count, 1);
            bxdf_queue.d_id[slot] = ray_id;

            // As before, we define that, if there was a hit, by the end of this operation
            // the ray is at that position. 
            vec3f new_pos = ray_orig + ray_dir * distance * closest_hit;
            d_pos[ray_id] = vec4f{new_pos.x, new_pos.y, new_pos.z, 0.0f};
            hit_id[ray_id] = local_hit_id;
            hit_normal[ray_id] = vec4f{closest_normal.x, closest_normal.y, closest_normal.z, 0.0f};
        }
        else
        {
            slot = atomicAdd(advance_queue.d_count, 1);
            advance_queue.d_id[slot] = ray_id;
        }
    }

    void launch_kernel_intersect_async(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer)
    {
        uint32_t threads_per_block = manager->stage.settings.wavefront_threads_per_block;
        uint32_t n_block = ((wavefront_buffer->x_resolution*wavefront_buffer->y_resolution) + threads_per_block - 1) / threads_per_block;

        vec4f* d_pos = wavefront_buffer->ray_pool.get<position_t>();
        vec4f* d_dir = wavefront_buffer->ray_pool.get<direction_t>();
        float* d_step_distance = wavefront_buffer->ray_pool.get<step_distance_t>();
        uint32_t* d_hit_id = wavefront_buffer->ray_pool.get<hit_id_t>();
        vec4f* d_hit_normal = wavefront_buffer->ray_pool.get<hit_normal_t>();

        kernel_intersect<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(d_pos, d_dir, d_step_distance, d_hit_id, d_hit_normal, wavefront_buffer->intersect_queue, wavefront_buffer->advance_queue_A, wavefront_buffer->bxdf_queue, manager->stage.box_min, manager->stage.box_max, manager->stage.light_min, manager->stage.light_max);
        check_cuda_errors(cudaGetLastError());

        reset_queue_async(wavefront_buffer->intersect_queue.d_count, &manager->cuda_stream);
    }
}
