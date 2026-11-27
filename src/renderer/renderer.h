#pragma once

#include "magik.h"
#include "wavefront.h"
#include "framebuffer.h"
#include "command.h"
#include "stage.h"
#include "cuda_host_utilities.h"
#include "color_pipeline.h"
#include <thread>
#include <atomic>
#include <chrono>
#include <cstring>

struct magik_render_manager
{
    // The manager is omniscient but greedy. 
    // It only hands the exact data functions 
    // need to work and not one byte more. 

    // thread and sync
    std::thread worker_thread;
    std::atomic<bool> is_running = false;

    // CUDA
    void* cuda_stream = nullptr;
    bool owns_stream = false;
    uint32_t cuda_device = 0;

    // DCC <-> worker
    magik::command_swapchain_t command_swpachain;
    magik::framebuffer_swapchain_t framebuffer_swapchain;
    e_magik_manager_display_types display_type;

    // Worker only
    magik::stage_t stage;
    magik::wavefront_buffer_t wavefront_buffer;
    magik::color_pipeline_descriptor_t color_pipeline_descriptor;

    struct activity_t
    {
        e_magik_activity_types type;
        uint32_t x_sample;
    } activity;

    struct status_t
    {
        e_magik_manager_status_types type;
        e_magik_result_types reason;
    } status;

    struct pending_t
    {
        magik::e_magik_framebuffer_update_policy_types framebuffer;
        magik::e_magik_wavefront_buffer_update_policy_types wavefront;
        magik::e_magik_color_pipeline_update_policy_types color_pipeline;
    } pending;

    MAGIK_HOST bool is_nominal()
    {
        return is_running.load(std::memory_order_relaxed);
    }
};

namespace magik
{
    void run(magik_render_manager* manager);
}
