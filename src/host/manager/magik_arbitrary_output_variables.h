#pragma once
#include <atomic>
#include <memory>
#include <string>
#include <unordered_map>
#include "magik.h" 
#include "magik_bridge.h"
#include "magik_error.h"

struct magik_aov_raw_buffer_external
{
    uint32_t x_resolution = 0;
    uint32_t y_resolution = 0;

    uint32_t channels = 0;

    struct 
    {
        float* h_data = nullptr;
        size_t host_size = 0;
    } config_host;

    struct
    {
        float* d_data = nullptr;
        size_t device_size = 0;
    } config_cuda;

    struct
    {
        uint32_t gl_buffer_id = 0;
        void* cuda_resource = nullptr;
    } config_open_gl_interop;

    struct
    {
        void* win32_handle = nullptr;
        int fd = -1;
        uint32_t allocation_size = 0;
    } config_vulkan_interop;
};

struct magik_aov_framebuffer_object_external
{
    e_magik_aov_config_types config_type; 

    std::unordered_map<std::string, magik_aov_raw_buffer_external> collection;
};

namespace magik::aov
{
    struct raw_buffer
    {
        // LPE doohicky 
        // Data format other than channels ? 

        uint32_t x_resolution = 0;
        uint32_t y_resolution = 0;

        uint32_t channels = 0;

        float* d_data = nullptr;
    };

    struct framebuffer_object
    {
        std::unordered_map<std::string, raw_buffer> collection;
    };

    struct context
    {
        uint32_t x_resolution_target = 2880;
        uint32_t y_resolution_target = 2160;

        framebuffer_object framebuffer_object_collection[3];

        framebuffer_object* front_framebuffer_object = nullptr;
        std::atomic<framebuffer_object*> ready_framebuffer_object{nullptr};
        framebuffer_object* back_framebuffer_object = nullptr;
        framebuffer_object render_framebuffer_object;

        std::atomic<bool> is_ready_updated = false;
    };

    e_magik_result_types initialize_framebuffer_collection(magik::aov::context* ctx);

    e_magik_result_types allocate_render_framebuffer_object(magik::aov::context* ctx);

    e_magik_result_types memcpy_render_to_back_framebuffer_object(magik::aov::context* ctx);

    e_magik_result_types swap_back_framebuffer(magik::aov::context* ctx);

    e_magik_result_types memcpy_front_framebuffer_to_dcc_framebuffer(magik::aov::context* ctx, magik_aov_framebuffer_object_external* dcc_buffer);

    bool try_swap_front_framebuffer(magik::aov::context* ctx);

    e_magik_result_types destroy_framebuffer_collection(magik::aov::context* ctx);
}
