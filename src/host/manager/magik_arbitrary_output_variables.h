#pragma once
#include <atomic>
#include <memory>
#include "magik.h" 
#include "magik_bridge.h"
#include "magik_error.h"
 
union backend
{
    struct 
    {
        float* h_albedo;
        size_t host_size;
    } config_host;

    struct
    {
        float* d_albedo;
        size_t device_size;
    } config_cuda;

    struct
    {
        uint32_t gl_buffer_id;
        void* cuda_resource;
    } config_open_gl_interop;

    struct
    {
        void* win32_handle;
        int fd;
        uint32_t allocation_size;
    } config_vulkan_interop;
};

struct magik_aov_framebuffer_object_external
{
    /*
    So, now we have to define this one. 
    Again, the idea is that this is a different frame buffer type because it is a union. 
    */

    e_magik_aov_config_types config_type; 
    uint32_t x_resolution = 0;
    uint32_t y_resolution = 0;

    backend data = {};
};

namespace magik::aov
{
    struct framebuffer_object
    {
        uint32_t x_resolution = 0;
        uint32_t y_resolution = 0;
        uint32_t n_spectral_bin = 0;

        uint32_t debug_id = 0;

        float* d_albedo = nullptr; //RGB, no alpha !, d_ for device ptr
        size_t size_of_d_albedo = 0;
    };

    struct context
    {
        uint32_t x_resolution = 2880;
        uint32_t y_resolution = 2160; 
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

    e_magik_result_types memcpy_front_framebuffer_to_dcc_framebuffer(magik::aov::context* ctx, magik_aov_framebuffer_object_external* dcc_buffer);

    bool try_swap_front_framebuffer(magik::aov::context* ctx);

    e_magik_result_types destroy_framebuffer_collection(magik::aov::context* ctx);
}
