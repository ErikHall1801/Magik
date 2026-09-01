#pragma once
#include <atomic>
#include <memory>
#include "magik.h" 
#include "magik_bridge.h"
#include "magik_error.h"

namespace magik::aov
{
    struct framebuffer_object
    {
        uint32_t debug_id = 0;

        uint32_t x_resolution = 0;
        uint32_t y_resolution = 0;
        uint32_t n_spectral_bin = 0;

        float* d_albedo = nullptr; //RGB, no alpha !, d_ for device ptr
        size_t size_of_d_albedo = 0;
    };

    struct context
    {
        uint32_t x_resolution = 400;
        uint32_t y_resolution = 300; 
        uint32_t n_spectral_bin = 0;

        framebuffer_object framebuffer_object_collection[3];

        framebuffer_object* front = nullptr;
        std::atomic<framebuffer_object*> ready{nullptr};
        framebuffer_object* back = nullptr;

        std::atomic<bool> is_ready_updated = false;
    };

    e_magik_result_types initialize_framebuffer_collection(magik::aov::context* ctx);

    e_magik_result_types allocate_back_framebuffer(magik::aov::context* ctx);

    e_magik_result_types swap_back_framebuffer(magik::aov::context* ctx);

    e_magik_result_types swap_front_framebuffer(magik::aov::context* ctx);

    e_magik_result_types destroy_framebuffer_collection(magik::aov::context* ctx);
}

struct magik_aov_buffer_external
{
    e_magik_aov_config_types type; 
    uint32_t x_resolution = 0;
    uint32_t y_resolution = 0; 
};
