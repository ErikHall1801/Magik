#include "kernel_intersect.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"
#include "traceables.cuh"
#include "stage.h"

#include "relativity_utilities.cuh"
#include "metric_minkowski.cuh"
#include "metric_schwarzschild.cuh"
#include "metric_kerr.cuh"

namespace magik
{
    struct kernel_intersect_args_t
    {
        vec4f* d_current_four_position = nullptr;
        vec4f* d_next_four_position = nullptr;
        uint32_t* d_hit_matter_slot = nullptr;
        vec4f* d_hit_normal = nullptr;
        uint32_t* d_intersect_queue_count = nullptr;
        uint32_t* d_intersect_queue_id = nullptr;
        uint32_t* d_advance_queue_A_count = nullptr;
        uint32_t* d_advance_queue_A_id = nullptr;
        uint32_t* d_bxdf_queue_count = nullptr;
        uint32_t* d_bxdf_queue_id = nullptr;

        vec3f box_min;
        vec3f box_max;
        vec3f light_min;
        vec3f light_max;
        float celestial_sphere_radius;
        vec3f observer_origin;

        __host__ void create(wavefront_buffer_t& wavefront_buffer, stage_t& stage)
        {
            d_current_four_position = wavefront_buffer.ray_pool.get<current_four_position_t>();
            d_next_four_position = wavefront_buffer.ray_pool.get<next_four_position_t>();
            d_hit_matter_slot = wavefront_buffer.ray_pool.get<hit_matter_slot_t>();
            d_hit_normal = wavefront_buffer.ray_pool.get<hit_normal_t>();
            d_intersect_queue_count = wavefront_buffer.queue_pool.get_count_ptr<intersect_queue_t>();
            d_intersect_queue_id = wavefront_buffer.queue_pool.get_id_ptr<intersect_queue_t>();
            d_advance_queue_A_count = wavefront_buffer.queue_pool.get_count_ptr<advance_A_queue_t>();
            d_advance_queue_A_id = wavefront_buffer.queue_pool.get_id_ptr<advance_A_queue_t>();
            d_bxdf_queue_count = wavefront_buffer.queue_pool.get_count_ptr<bxdf_queue_t>();
            d_bxdf_queue_id = wavefront_buffer.queue_pool.get_id_ptr<bxdf_queue_t>();

            box_min = stage.box_min;
            box_max = stage.box_max;
            light_min = stage.light_min;
            light_max = stage.light_max;
            celestial_sphere_radius = stage.relativity_settings.celestial_sphere_radius;
            observer_origin = stage.optical_system_settings.position;
        }
    };

    template<e_magik_spacetime_metric_types T> static __global__ void kernel_intersect(typename metric<T>::params_t metric_parameters, kernel_intersect_args_t args)
    {
        // Reads "intersect queue"
        // Writes "advance queue" or "bxdf queue"

        uint32_t queue_index = blockIdx.x * blockDim.x + threadIdx.x;
        if(queue_index >= *args.d_intersect_queue_count) return;
        uint32_t ray_id = args.d_intersect_queue_id[queue_index];

        float length_scale = metric<T>::length_scale(metric_parameters);
        vec4f current_four_position = args.d_current_four_position[ray_id] * length_scale;
        vec4f next_four_position = args.d_next_four_position[ray_id] * length_scale;

        vec3f origin = vec3f{current_four_position.x, current_four_position.y, current_four_position.z};
        vec3f direction = vec3f{next_four_position.x - current_four_position.x, next_four_position.y - current_four_position.y, next_four_position.z - current_four_position.z}.norm();
        float step_euclidian = vector_distance(vec3f{current_four_position.x, current_four_position.y, current_four_position.z}, vec3f{next_four_position.x, next_four_position.y, next_four_position.z});

        // 3. Do work
        bool hit_any = false;
        uint32_t local_hit_id = 0; // That is ok, if nothing is hit the implication is null-matter. 

        float closest_hit = 1e30f;
        vec3f closest_normal;
        float candidate_hit_parameter = 1e30f;
        vec3f candidate_hit_normal;

        if(affine_aabb_intersection(&candidate_hit_parameter, &candidate_hit_normal, direction, origin, 1.0f/step_euclidian, args.box_min, args.box_max))
        {
            closest_hit = candidate_hit_parameter;
            closest_normal = candidate_hit_normal;
            hit_any = true;
            local_hit_id = 1; // Diffuse
        }

        candidate_hit_parameter = 1e30f;

        if(affine_aabb_intersection(&candidate_hit_parameter, &candidate_hit_normal, direction, origin, 1.0f/step_euclidian, args.light_min, args.light_max))
        {
            if(candidate_hit_parameter < closest_hit)
            {
                closest_hit = candidate_hit_parameter;
                closest_normal = candidate_hit_normal;
                hit_any = true;
                local_hit_id = 2; // Illuminant
            }
        }

        candidate_hit_parameter = 1e30f;

        if(affine_celestial_sphere_intersection(&candidate_hit_parameter, &candidate_hit_normal, length_scale, args.d_current_four_position[ray_id], args.d_next_four_position[ray_id], args.celestial_sphere_radius, args.observer_origin))
        {
            if(candidate_hit_parameter < closest_hit)
            {
                closest_hit = candidate_hit_parameter;
                closest_normal = candidate_hit_normal;
                hit_any = true;
                local_hit_id = 3;
            }
        }

        if(!hit_any && metric<T>::in_domain(next_four_position/length_scale, metric_parameters))
        {
            hit_any = true;
            closest_hit = 1.0f;
            local_hit_id = 3; // 0th slot is reservered for the horizon !
        }

        // 4. Append to queues
        uint32_t slot = 0;

        if(hit_any)
        {
            slot = atomicAdd(args.d_bxdf_queue_count, 1);
            args.d_bxdf_queue_id[slot] = ray_id;
            args.d_next_four_position[ray_id] = lerp(current_four_position, next_four_position, closest_hit)/length_scale;
            args.d_hit_matter_slot[ray_id] = local_hit_id;
            args.d_hit_normal[ray_id] = vec4f{closest_normal.x, closest_normal.y, closest_normal.z, 0.0f};
        }
        else
        {
            slot = atomicAdd(args.d_advance_queue_A_count, 1);
            args.d_advance_queue_A_id[slot] = ray_id;
        }
    }

    void launch_kernel_intersect_async(wavefront_buffer_t& wavefront_buffer, cudaStream_t user_stream, stage_t& stage)
    {
        uint32_t threads_per_block = stage.render_settings.wavefront_threads_per_block;
        uint32_t n_block = (wavefront_buffer.queue_ceiling + threads_per_block - 1) / threads_per_block;

        kernel_intersect_args_t args;
        args.create(wavefront_buffer, stage);
        bool time_reversed = true;

        bool successful = dispatch_list(supported_metrics{}, stage.relativity_settings.metric_type, [&](auto tag)
        {
            constexpr auto T = decltype(tag)::value;
            kernel_intersect<T><<<n_block, threads_per_block, 0, user_stream>>>(metric<T>::make_params(stage.relativity_settings, time_reversed), args);
        });

        check_cuda_errors(cudaGetLastError());

        wavefront_buffer.queue_pool.store_count_in_history<intersect_queue_t>(user_stream, wavefront_buffer.iteration, stage.render_settings.n_geodesic_step_limit);
        wavefront_buffer.queue_pool.zero_count_async<intersect_queue_t>(user_stream);

        // Do status 
    }
}
