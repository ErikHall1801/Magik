#pragma once

#include "magik.h"
#include "internal_memory.h"
#include "internal_error.h"
#include "opengl_interop.cuh"

#include <atomic>
#include <memory>
#include <string>
#include <unordered_map>
#include <variant>

struct magik_aov_raw_buffer_external //Rename this !!!
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

struct magik_framebuffer_collection_external //Rename this !!!
{
    e_magik_framebuffer_collection_config_types config_type;
    std::unordered_map<std::string, magik_aov_raw_buffer_external> collection;
};

namespace magik
{
    typedef enum e_magik_framebuffer_update_policy_types : uint32_t
    {
        MAGIK_FRAMEBUFFER_UPDATE_POLICY_NONE = 0,
        MAGIK_FRAMEBUFFER_UPDATE_POLICY_REALLOC_RENDERBUFFER = 1
    } e_magik_framebuffer_update_policy_types;

    struct framebuffer_t
    {
        uint32_t x_resolution = 0;
        uint32_t y_resolution = 0;
        uint32_t channels = 0;
        float* d_data = nullptr;
    };

    struct framebuffer_collection_t
    {
        std::unordered_map<std::string, framebuffer_t> collection;
    };

    struct framebuffer_swapchain_t
    {
        framebuffer_collection_t framebuffer_collection[3];

        framebuffer_collection_t* front_framebuffer = nullptr;
        std::atomic<framebuffer_collection_t*> ready_framebuffer = nullptr;
        framebuffer_collection_t* back_framebuffer = nullptr;
        framebuffer_collection_t render_framebuffer;

        std::atomic<bool> is_ready_framebuffer_updated = false;
        bool clear_render_buffer = false;
    };

    // DCC 
    e_magik_result_types configure_external_framebuffer_collection(magik_framebuffer_collection_external_t* external_collection_framebuffer, e_magik_framebuffer_collection_config_types config_type);

    e_magik_result_types fetch_framebuffer_collection(bool is_running, e_magik_manager_display_types display_type, framebuffer_swapchain_t& framebuffer_swapchain, magik_framebuffer_collection_external_t external_collection_framebuffer, bool* is_new_fetch);

    e_magik_result_types extract_config_host(bool is_running, magik_framebuffer_container_config_host_t* container, magik_framebuffer_collection_external_t external_collection_framebuffer, const char* name);

    e_magik_result_types extract_config_opengl_interop(bool is_running, magik_framebuffer_container_config_opengl_interop_t* container, magik_framebuffer_collection_external_t external_collection_framebuffer, const char* name);

    e_magik_result_types destroy_external_framebuffer_collection(magik_framebuffer_collection_external_t external_collection_framebuffer);

    // Internal
    struct update_framebuffer_swapchain_t
    {
        e_magik_framebuffer_update_policy_types& update_policy;

        framebuffer_swapchain_t& framebuffer_swapchain;
        uint32_t x_resolution_target;
        uint32_t y_resolution_target;
    };

    void update_framebuffer_swapchain(update_framebuffer_swapchain_t args);

    void initialize_framebuffer_swapchain(framebuffer_swapchain_t& framebuffer_swapchain);

    void release_framebuffer_swapchain(framebuffer_swapchain_t& framebuffer_swapchain);
}
