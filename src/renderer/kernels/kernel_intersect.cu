#include "kernel_intersect.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"
#include "traceables.cuh"

namespace magik
{
    static __global__ void kernel_intersect(ray_pool_t ray_pool, ray_queue_t intersect_queue, ray_queue_t advance_queue, ray_queue_t bxdf_queue, vec3f box_min, vec3f box_max, vec3f light_min, vec3f light_max)
    {
        // Reads "intersect queue"
        // Writes "advance queue" or "bxdf queue"

        // 1. Fetch ray id
        uint32_t queue_index = blockIdx.x * blockDim.x + threadIdx.x;
        if(queue_index >= *intersect_queue.d_count) return;
        uint32_t ray_id = intersect_queue.d_id[queue_index];

        // 2. Fetch ray-specific data
        vec3f ray_orig = ray_pool.d_pos[ray_id];
        vec3f ray_dir = ray_pool.d_dir[ray_id];
        float distance = ray_pool.d_step_distance[ray_id];

        // 3. Do work
        bool hit_any = false;
        uint32_t hit_id = 0;

        float closest_hit = 1e30f;
        vec3f closest_normal;
        float candidate_hit_parameter = 1e30f;
        vec3f candidate_hit_normal;

        if(affine_aabb_intersection(&candidate_hit_parameter, &candidate_hit_normal, ray_dir, ray_orig, 1.0f/distance, box_min, box_max))
        {
            closest_hit = candidate_hit_parameter;
            closest_normal = candidate_hit_normal;
            hit_any = true;
            hit_id = 1;
        }

        candidate_hit_parameter = 1e30f;

        if(affine_aabb_intersection(&candidate_hit_parameter, &candidate_hit_normal, ray_dir, ray_orig, 1.0f/distance, light_min, light_max))
        {
            if(candidate_hit_parameter < closest_hit)
            {
                closest_hit = candidate_hit_parameter;
                closest_normal = candidate_hit_normal;
                hit_any = true;
                hit_id = 2;
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
            ray_pool.d_pos[ray_id] = ray_orig + ray_dir * distance * closest_hit;
            ray_pool.hit_id[ray_id] = hit_id;
            ray_pool.hit_normal[ray_id] = closest_normal;
        }
        else
        {
            slot = atomicAdd(advance_queue.d_count, 1);
            advance_queue.d_id[slot] = ray_id;
        }
    }

    void launch_kernel_intersect_async(void** user_stream, uint32_t x_resolution, uint32_t y_resolution, ray_pool_t ray_pool, ray_queue_t intersect_queue, ray_queue_t advance_queue, ray_queue_t shade_queue, vec3f box_min, vec3f box_max, vec3f light_min, vec3f light_max)
    {
        uint32_t threads_per_block = 256; // 16²
        uint32_t n_block = ((x_resolution*y_resolution) + threads_per_block - 1) / threads_per_block;

        kernel_intersect<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(*user_stream)>>>(ray_pool, intersect_queue, advance_queue, shade_queue, box_min, box_max, light_min, light_max);
        check_cuda_errors(cudaGetLastError());
    }
}
