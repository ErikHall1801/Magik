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
        ray_queue_t shade_queue;
        ray_queue_t color_queue;

        ray_pool_t ray_pool;
    };

    void realloc_wavefront_ray_buffer(wavefront_ray_buffer_t* buffer, uint32_t x_resolution_target, uint32_t y_resolution_target);

    void destroy_wavefront_ray_buffer(wavefront_ray_buffer_t* buffer);

    void wavefront_reset(magik_render_manager* manager, wavefront_ray_buffer_t* buffer);

    void wavefront_sample(magik_render_manager* manager, wavefront_ray_buffer_t* buffer);
}
