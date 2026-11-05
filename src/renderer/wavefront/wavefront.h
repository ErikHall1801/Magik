#pragma once

#include <cstdint>
#include "ray.h"
#include "device_arena.h"
#include "renderer.h"

namespace magik
{
    struct wavefront_buffer_t
    {
        uint32_t x_resolution = 0;
        uint32_t y_resolution = 0;

        uint32_t queue_ceiling = 0;

        device_mem_arena arena;

        queue_pool_t<
        advance_A_queue_t,
        advance_B_queue_t,
        intersect_queue_t,
        bxdf_queue_t,
        redistribute_queue_t,
        splat_queue_t>
        queue_pool;

        ray_pool_t<
        sensor_wavelength_nm_t,
        monte_carlo_weight_t,
        spectral_radiance_t,
        intrinsic_spectral_irradiance_t,
        random_device_t,
        initial_observer_three_direction_t,
        initial_observer_three_position_t,
        initial_four_vector_contraction_t,
        affine_parameter_t,
        delta_affine_parameter_t,
        current_four_position_t,
        current_four_momentum_t,
        next_four_position_t,
        next_four_momentum_t,
        momentum_derivative_start_t,
        momentum_derivative_end_t,
        hit_id_t,
        hit_normal_t,
        n_geodesic_step_t,
        n_bounce_t> 
        ray_pool;

        // Align up
        static constexpr size_t align_up(size_t x)
        {
            return (x + 255) & ~(255);
        }

        // allocate
        void allocate_async(cudaStream_t user_stream, uint32_t n_bin, const uint32_t x_resolution, const uint32_t y_resolution, bool set_zero)
        {
            ray_pool.set_n_dimension<intrinsic_spectral_irradiance_t>(n_bin);

            // Allocation stage
            size_t total_size = 0;
            total_size += align_up(queue_pool.total_bytes(x_resolution, y_resolution) + ray_pool.total_bytes(x_resolution, y_resolution));
            arena = device_arena_create_async(user_stream, total_size);

            // Note, right now we chose to assign the queue's and ray's in order, but it would likely be better
            // to put queue's in locations where specific ray's need them. This would requiere a templated 
            // allocator where the order of the variadic arguments determins the layout. 
            // The assignment needs to be a member function too. I think. So we can all assign() on either type. 

            // Queue assignment 
            queue_pool.assign(&arena, x_resolution, y_resolution);

            // Ray assignment 
            ray_pool.assign(&arena, x_resolution, y_resolution);

            // Memset
            if(set_zero)
            {
                check_cuda_errors(cudaMemsetAsync(arena.d_base, 0x0, total_size, user_stream));
            }
        }

        void release_async(cudaStream_t user_stream)
        {
            device_arena_destroy_async(user_stream, &arena);
        }
    };

    struct wavefront_sample_statistics_t
    {
        uint32_t total_iterations = 0;

        uint32_t history_length = 0;

        uint32_t* h_latest_advance_queue_history = nullptr;
        uint32_t* h_latest_intersect_queue_history = nullptr;
        uint32_t* h_latest_bxdf_queue_history = nullptr;
        uint32_t* h_latest_color_queue_history = nullptr;

        uint32_t* h_average_advance_queue_history = nullptr;
        uint32_t* h_average_intersect_queue_history = nullptr;
        uint32_t* h_average_bxdf_queue_history = nullptr;
        uint32_t* h_average_color_queue_history = nullptr;

        // What else can we really do ? Well, it would be really cool if we could get
        // a queue history. In principle the number of iterations has a hard cap given
        // by n_step. So we can allocate memory and actually record the counts. 
        // We can do both average and latest. 
        // The kinda general idea here is to one set of these on the device, then 
        // update the statistics at the end of the wavefront sample. 
    };

    void realloc_wavefront_buffer(cudaStream_t user_stream, wavefront_buffer_t* wavefront_buffer, uint32_t n_bin, uint32_t x_resolution_target, uint32_t y_resolution_target);

    void reset_wavefront_process_async(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer);

    void wavefront_sample(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer);
}
