#pragma once

#include <cstdint>
#include "ray.h"
#include "internal_memory.h"
#include "device_arena.h"
#include "renderer.h"

namespace magik
{
    struct wavefront_buffer_t
    {
        uint32_t x_resolution = 0;
        uint32_t y_resolution = 0;

        // Perhaps a queue_pool ? In a non-random order ? 
        // Sure, but at that point why have these be in a 
        // ray-class ? Why not put all the logic right here ? 
        // This way we could more easily make one overall pool 
        // template.
        // On the other hand, we ideally want one arena. Right
        // now we are heading for two. This would be less of 
        // a problem if this struct held all the needed logic. 
        // i say less because, we still need a template with two
        // types. We will have to figure this out eventually, 
        // since the assets are going to be packed memory too. 
        //
        // We can make seperate ray_pool and queue_pool objects
        // which are managed jointly in this struct. So each 
        // type has its own functions, but the memory stuff 
        // is handled in here. 

        ray_queue_t advance_queue_A;
        ray_queue_t advance_queue_B;
        ray_queue_t intersect_queue;
        ray_queue_t bxdf_queue;
        ray_queue_t redistribute_queue;
        ray_queue_t splat_queue;

        ray_pool_t<
        sensor_wavelength_nm_t,
        monte_carlo_weight_t,
        spectral_radiance_t,
        intrinsic_spectral_irradiance_t,
        random_device_t,
        position_t,
        direction_t,
        step_distance_t,
        n_step_t,
        hit_id_t,
        hit_normal_t> 
        ray_pool;
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

    void reset_queue_async(uint32_t* d_count, void** user_stream);

    void realloc_wavefront_buffer(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer, uint32_t x_resolution_target, uint32_t y_resolution_target);

    void destroy_wavefront_buffer(cudaStream_t user_stream, wavefront_buffer_t* wavefront_buffer);

    void reset_wavefront_buffer(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer);

    void wavefront_sample(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer);
}
