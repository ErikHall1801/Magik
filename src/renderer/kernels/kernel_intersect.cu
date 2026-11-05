#include "kernel_intersect.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"
#include "traceables.cuh"

#include "relativity_utilities.cuh"
#include "metric_minkowski.cuh"
#include "metric_schwarzschild.cuh"
#include "metric_kerr.cuh"

namespace magik
{
    template<e_magik_spacetime_metric_types T> static __global__ void kernel_intersect(typename metric<T>::params_t parameters, vec4f* d_current_four_position, vec4f* d_next_four_position, uint32_t* hit_id, vec4f* hit_normal, uint32_t* d_intersect_queue_count, uint32_t* d_intersect_queue_id, uint32_t* d_advance_queue_A_count, uint32_t* d_advance_queue_A_id, uint32_t* d_bxdf_queue_count, uint32_t* d_bxdf_queue_id, vec3f box_min, vec3f box_max, vec3f light_min, vec3f light_max)
    {
        // Reads "intersect queue"
        // Writes "advance queue" or "bxdf queue"

        uint32_t queue_index = blockIdx.x * blockDim.x + threadIdx.x;
        if(queue_index >= *d_intersect_queue_count) return;
        uint32_t ray_id = d_intersect_queue_id[queue_index];

        // What is the strategy ? Well, we have to find the closest intersection. 
        // Being inside the domaine means the ray hit it. Or, at least, the next four
        // position is inside. So if anything is closer, its closer. Meaning, we check
        // the domaine last, since if we know something is closer, we dont need to
        // check. 

        float length_scale = metric<T>::length_scale(parameters);
        vec4f current_four_position = d_current_four_position[ray_id] * length_scale;
        vec4f next_four_position = d_next_four_position[ray_id] * length_scale;

        vec3f origin = vec3f{current_four_position.x, current_four_position.y, current_four_position.z};
        vec3f direction = vec3f{current_four_position.x - next_four_position.x, current_four_position.y - next_four_position.y, current_four_position.z - next_four_position.z}.norm();
        float step_euclidian = vector_distance(vec3f{current_four_position.x, current_four_position.y, current_four_position.z}, vec3f{next_four_position.x, next_four_position.y, next_four_position.z});

        // 3. Do work
        bool hit_any = false;
        uint32_t local_hit_id = 0;

        float closest_hit = 1e30f;
        vec3f closest_normal;
        float candidate_hit_parameter = 1e30f;
        vec3f candidate_hit_normal;

        if(affine_aabb_intersection(&candidate_hit_parameter, &candidate_hit_normal, direction, origin, 1.0f/step_euclidian, box_min, box_max))
        {
            closest_hit = candidate_hit_parameter;
            closest_normal = candidate_hit_normal;
            hit_any = true;
            local_hit_id = 1;
        }

        candidate_hit_parameter = 1e30f;

        if(affine_aabb_intersection(&candidate_hit_parameter, &candidate_hit_normal, direction, origin, 1.0f/step_euclidian, light_min, light_max))
        {
            if(candidate_hit_parameter < closest_hit)
            {
                closest_hit = candidate_hit_parameter;
                closest_normal = candidate_hit_normal;
                hit_any = true;
                local_hit_id = 2;
            }
        }

        if(!hit_any && metric<T>::in_domain(current_four_position/length_scale, parameters))
        {
            hit_any = true;
            closest_hit = 1.0f;
            local_hit_id = 3;
        }

        // 4. Append to queues
        uint32_t slot = 0;

        if(hit_any)
        {
            slot = atomicAdd(d_bxdf_queue_count, 1);
            d_bxdf_queue_id[slot] = ray_id;

            d_next_four_position[ray_id] = lerp(current_four_position, next_four_position, closest_hit)/length_scale;

            hit_id[ray_id] = local_hit_id;
            hit_normal[ray_id] = vec4f{closest_normal.x, closest_normal.y, closest_normal.z, 0.0f};
        }
        else
        {
            slot = atomicAdd(d_advance_queue_A_count, 1);
            d_advance_queue_A_id[slot] = ray_id;
        }
    }

    void launch_kernel_intersect_async(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer)
    {
        uint32_t threads_per_block = manager->stage.settings.wavefront_threads_per_block;
        uint32_t n_block = (wavefront_buffer->queue_ceiling + threads_per_block - 1) / threads_per_block;

        vec4f* d_current_four_position = wavefront_buffer->ray_pool.get<current_four_position_t>();
        vec4f* d_next_four_position = wavefront_buffer->ray_pool.get<next_four_position_t>();

        uint32_t* d_hit_id = wavefront_buffer->ray_pool.get<hit_id_t>();
        vec4f* d_hit_normal = wavefront_buffer->ray_pool.get<hit_normal_t>();

        uint32_t* d_intersect_queue_count = wavefront_buffer->queue_pool.get_count_ptr<intersect_queue_t>();
        uint32_t* d_intersect_queue_id = wavefront_buffer->queue_pool.get_id_ptr<intersect_queue_t>();
        uint32_t* d_advance_queue_A_count = wavefront_buffer->queue_pool.get_count_ptr<advance_A_queue_t>();
        uint32_t* d_advance_queue_A_id = wavefront_buffer->queue_pool.get_id_ptr<advance_A_queue_t>();
        uint32_t* d_bxdf_queue_count = wavefront_buffer->queue_pool.get_count_ptr<bxdf_queue_t>();
        uint32_t* d_bxdf_queue_id = wavefront_buffer->queue_pool.get_id_ptr<bxdf_queue_t>();

        bool successful = dispatch_metric(manager->stage.settings.metric_type, [&](auto tag)
        {
            constexpr auto T = decltype(tag)::value;
            kernel_intersect<T><<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(metric<T>::make_params(manager), d_current_four_position, d_next_four_position, d_hit_id, d_hit_normal, d_intersect_queue_count, d_intersect_queue_id, d_advance_queue_A_count, d_advance_queue_A_id, d_bxdf_queue_count, d_bxdf_queue_id, manager->stage.box_min, manager->stage.box_max, manager->stage.light_min, manager->stage.light_max);
        });

        check_cuda_errors(cudaGetLastError());

        wavefront_buffer->queue_pool.zero_count_async<intersect_queue_t>(static_cast<cudaStream_t>(manager->cuda_stream));

        if(!successful) return; // Error !
    }
}
