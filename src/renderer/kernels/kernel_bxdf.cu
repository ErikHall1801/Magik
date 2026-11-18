#include "kernel_bxdf.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"

#include "relativity_utilities.cuh"
#include "metric_minkowski.cuh"
#include "metric_schwarzschild.cuh"
#include "metric_kerr.cuh"

#include "bxdf_utilities.cuh"
#include "matter_examples.cuh"

namespace magik
{
    struct kernel_bxdf_args_t
    {
        uint32_t* d_bxdf_queue_id = nullptr;
        uint32_t* d_bxdf_queue_count = nullptr;
        uint32_t* d_redistribute_queue_id = nullptr;
        uint32_t* d_redistribute_queue_count = nullptr;
        uint32_t* d_advance_A_queue_id = nullptr;
        uint32_t* d_advance_A_queue_count = nullptr;

        uint32_t* d_hit_matter_slot = nullptr;
        vec4f* d_hit_normal = nullptr;
        float* d_sensor_wavelength_nm = nullptr;
        curandState_t* d_random_device = nullptr;
        uint32_t* d_n_reflected = nullptr;
        float* d_spectral_radiance = nullptr;
        vec4f* d_current_four_position = nullptr;
        vec4f* d_current_four_momentum = nullptr;
        vec4f* d_next_four_position = nullptr;
        vec4f* d_next_four_momentum = nullptr;
        vec4f* d_momentum_derivative_start = nullptr;
        vec4f* d_momentum_derivative_end = nullptr;
        float* d_initial_four_vector_contraction = nullptr;
        float* d_monte_carlo_weight = nullptr;
        float* d_affine_parameter = nullptr;
        float* d_delta_affine_parameter = nullptr;

        __host__ void create(wavefront_buffer_t* wb)
        {
            d_bxdf_queue_id = wb->queue_pool.get_id_ptr<bxdf_queue_t>();
            d_bxdf_queue_count = wb->queue_pool.get_count_ptr<bxdf_queue_t>();
            d_redistribute_queue_id = wb->queue_pool.get_id_ptr<redistribute_queue_t>();
            d_redistribute_queue_count = wb->queue_pool.get_count_ptr<redistribute_queue_t>();
            d_advance_A_queue_id = wb->queue_pool.get_id_ptr<advance_A_queue_t>();
            d_advance_A_queue_count = wb->queue_pool.get_count_ptr<advance_A_queue_t>();

            d_hit_matter_slot = wb->ray_pool.get<hit_matter_slot_t>();
            d_hit_normal = wb->ray_pool.get<hit_normal_t>();
            d_sensor_wavelength_nm = wb->ray_pool.get<sensor_wavelength_nm_t>();
            d_random_device = wb->ray_pool.get<random_device_t>();
            d_n_reflected = wb->ray_pool.get<n_reflected_t>();
            d_spectral_radiance = wb->ray_pool.get<spectral_radiance_t>();
            d_current_four_position = wb->ray_pool.get<current_four_position_t>();
            d_current_four_momentum = wb->ray_pool.get<current_four_momentum_t>();
            d_next_four_position = wb->ray_pool.get<next_four_position_t>();
            d_next_four_momentum = wb->ray_pool.get<next_four_momentum_t>();
            d_momentum_derivative_start = wb->ray_pool.get<momentum_derivative_start_t>();
            d_momentum_derivative_end = wb->ray_pool.get<momentum_derivative_end_t>();
            d_initial_four_vector_contraction = wb->ray_pool.get<initial_four_vector_contraction_t>();
            d_monte_carlo_weight = wb->ray_pool.get<monte_carlo_weight_t>();
            d_affine_parameter = wb->ray_pool.get<affine_parameter_t>();
            d_delta_affine_parameter = wb->ray_pool.get<delta_affine_parameter_t>();
        }
    };

    template<e_magik_spacetime_metric_types T, class bxdf_matter> static __global__ void kernel_bxdf(typename metric<T>::params_t metric_parameters, uint32_t kernel_matter_slot, kernel_bxdf_args_t args)
    {
        uint32_t queue_index = blockIdx.x * blockDim.x + threadIdx.x;
        if(queue_index >= *args.d_bxdf_queue_count) return;
        uint32_t ray_id = args.d_bxdf_queue_id[queue_index];
        uint32_t matter_slot = args.d_hit_matter_slot[ray_id];
        if(matter_slot != kernel_matter_slot) return;

        bxdf_velocity_context v_context = generate_velocity_context(args.d_sensor_wavelength_nm[ray_id], metric<T>::length_scale(metric_parameters), args.d_initial_four_vector_contraction[ray_id], args.d_affine_parameter[ray_id], args.d_delta_affine_parameter[ray_id], args.d_monte_carlo_weight[ray_id], args.d_current_four_position[ray_id], args.d_current_four_momentum[ray_id], args.d_next_four_position[ray_id], args.d_next_four_momentum[ray_id], args.d_momentum_derivative_start[ray_id], args.d_momentum_derivative_end[ray_id], vec3f{args.d_hit_normal[ray_id].x, args.d_hit_normal[ray_id].y, args.d_hit_normal[ray_id].z}, &args.d_random_device[ray_id]);
        vec3f result_three_velocity = -bxdf_matter::local_proper_velocity_function(v_context); // Negated so authors direct physical velocities

        bxdf_material_context m_context = generate_material_context<T>(metric_parameters, v_context, -result_three_velocity / magik::speed_of_light);
        bxdf_result result_material = bxdf_matter::material_function(m_context);

        apply_bxdf_result<T>(metric_parameters, result_material, ray_id, args.d_n_reflected, args.d_spectral_radiance, args.d_current_four_position, args.d_current_four_momentum, args.d_next_four_position, args.d_next_four_momentum, args.d_initial_four_vector_contraction, args.d_monte_carlo_weight, m_context.redshift_factor, m_context.dimensionless_four_velocity, m_context.global_frame_facing_normal);

        if(result_material.type == ABSORBED)
        {
            uint32_t redistribute_slot = atomicAdd(args.d_redistribute_queue_count, 1);
            args.d_redistribute_queue_id[redistribute_slot] = ray_id;
        }
        else
        {
            uint32_t advance_slot = atomicAdd(args.d_advance_A_queue_count, 1);
            args.d_advance_A_queue_id[advance_slot] = ray_id;
        }
    }
 
    /*
    This is temporary logic to get something on the screen. The proper bxdf pipeline will
    utilize NVRTC throughout and not rely on a compile-time matter list at all. The hope 
    is that once we expand the system, while a lot of logic will have to change, the core
    concepts stay the same. 
    Regardless of how NVRTC works, we will need to sort the bxdf queue and matter evalu-
    uation stays the same too. 
    */
    template<class... T> struct matter_list {};

    using registered_matter = matter_list<bxdf_null_matter_t, bxdf_diffuse_matter_t, bxdf_illuminant_matter_t, bxdf_horizon_matter_t>;

    template<e_magik_spacetime_metric_types T, class... matter_type> static void launch_all_matter_types(typename metric<T>::params_t metric_parameters, uint32_t threads_per_block, uint32_t n_block, cudaStream_t user_stream, kernel_bxdf_args_t args, matter_list<matter_type...>)
    {
        uint32_t slot = 0;
        (kernel_bxdf<T, matter_type><<<n_block, threads_per_block, 0, user_stream>>>(metric_parameters, slot++, args), ...);
    }

    void launch_kernel_bxdf_async(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer)
    {
        uint32_t threads_per_block = manager->stage.settings.wavefront_threads_per_block;
        uint32_t n_block = (wavefront_buffer->queue_ceiling + threads_per_block - 1) / threads_per_block;

        kernel_bxdf_args_t args;
        args.create(wavefront_buffer);
        bool time_reversed = true;

        bool successful = dispatch_list(supported_metrics{}, manager->stage.settings.metric_type, [&](auto tag)
        {
            constexpr auto T = decltype(tag)::value;
            launch_all_matter_types<T>(metric<T>::make_params(manager, time_reversed), threads_per_block, n_block, static_cast<cudaStream_t>(manager->cuda_stream), args, registered_matter{});
        });

        check_cuda_errors(cudaGetLastError());

        wavefront_buffer->queue_pool.store_count_in_history<bxdf_queue_t>(static_cast<cudaStream_t>(manager->cuda_stream), wavefront_buffer->iteration, manager->stage.settings.n_geodesic_step_limit);
        wavefront_buffer->queue_pool.zero_count_async<bxdf_queue_t>(static_cast<cudaStream_t>(manager->cuda_stream));

        if(!successful)
        {
            e_magik_result_types expected = MAGIK_SUCCESS, result = MAGIK_ERROR_UNKNOWN_METRIC;
            manager->atomic_last_error_type.compare_exchange_strong(expected, result);
            manager->is_running.store(false, std::memory_order_release);
        }
    }
}
