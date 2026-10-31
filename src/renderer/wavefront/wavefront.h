#pragma once

#include <cstdint>
#include "ray.h"
#include "internal_memory.h"
#include "renderer.h"

namespace magik
{
    struct wavefront_ray_buffer_t
    {
        uint32_t x_resolution = 0;
        uint32_t y_resolution = 0;

        ray_queue_t advance_queue_A;
        ray_queue_t advance_queue_B;
        ray_queue_t intersect_queue;
        ray_queue_t bxdf_queue;
        ray_queue_t redistribute_queue;
        ray_queue_t splat_queue;

        ray_pool_t ray_pool;
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

    void realloc_wavefront_ray_buffer(magik_render_manager* manager, wavefront_ray_buffer_t* buffer, uint32_t x_resolution_target, uint32_t y_resolution_target);

    void destroy_wavefront_ray_buffer(wavefront_ray_buffer_t* buffer);

    void wavefront_reset(magik_render_manager* manager, wavefront_ray_buffer_t* buffer);

    void wavefront_sample(magik_render_manager* manager, wavefront_ray_buffer_t* buffer);
}
