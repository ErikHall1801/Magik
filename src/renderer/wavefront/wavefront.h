#pragma once

#include <cstdint>
#include "ray.h"
#include "device_arena.h"
#include "color_pipeline.h" 
#include "stage.h"

namespace magik
{
    typedef enum e_magik_wavefront_buffer_update_policy_types : uint32_t
    {
        MAGIK_WAVEFRONT_UPDATE_POLICY_NONE = 0,
        MAGIK_WAVEFRONT_UPDATE_POLICY_RESET = 1,
        MAGIK_WAVEFRONT_UPDATE_POLICY_REALLOC = 2,
    } e_magik_wavefront_buffer_update_policy_types;

    using queue_pool_layout = queue_pool_t<advance_A_queue_t, advance_B_queue_t, intersect_queue_t, bxdf_queue_t, redistribute_queue_t, splat_queue_t>;

    using ray_pool_layout = ray_pool_t<sensor_wavelength_nm_t, throughput_t, spectral_radiance_t, intrinsic_spectral_irradiance_t, random_device_t, initial_observer_spatial_direction_t, initial_observer_spatial_position_t, initial_four_vector_contraction_t, affine_parameter_t, delta_affine_parameter_t, current_four_position_t, current_four_momentum_t, next_four_position_t, next_four_momentum_t, momentum_derivative_start_t, momentum_derivative_end_t, hit_matter_slot_t, hit_normal_t, n_geodesic_step_t, n_reflected_t>;

    struct wavefront_buffer_t
    {
        uint32_t x_resolution = 0;
        uint32_t y_resolution = 0;
        uint32_t n_isi_bin = 0;
        uint32_t n_geodesic_step_limit = 0;

        uint32_t queue_ceiling = 0;
        uint32_t iteration = 0;
 
        device_mem_arena arena;

        queue_pool_layout queue_pool;
        ray_pool_layout ray_pool;
    };

    struct update_wavefront_buffer_t
    {
        e_magik_wavefront_buffer_update_policy_types& update_policy;

        wavefront_buffer_t& wavefront_buffer;
        uint32_t& x_sample;
        cudaStream_t user_stream;
        uint32_t x_resolution_target;
        uint32_t y_resolution_target;
        uint32_t n_geodesic_step_limit;
        uint32_t n_isi_bin;
    };

    void update_wavefront_buffer(update_wavefront_buffer_t args);

    struct wavefront_sample_args_t
    {
        float* d_renderbuffer;

        wavefront_buffer_t& wavefront_buffer;
        uint32_t& x_sample;
        stage_t& stage;
        color_pipeline_descriptor_t& color_pipeline;
        cudaStream_t user_stream;
    };

    void wavefront_sample(wavefront_sample_args_t args);

    void release_wavefront_buffer(device_mem_arena* wavefront_buffer_arena, cudaStream_t user_stream);
}
