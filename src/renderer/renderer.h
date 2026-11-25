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

    // Status 
    e_magik_manager_status_types status;
    e_magik_result_types status_reason;
    e_magik_manager_status_types initial_status;

    // CUDA
    void* cuda_stream = nullptr;
    bool owns_stream = false;
    uint32_t cuda_device = 0;

    // DCC <-> worker
    magik::stage_t stage;
    magik::command_swapchain_t command_swpachain;
    magik::framebuffer_swapchain_t framebuffer_swapchain;
    e_magik_manager_display_types display_type;

    // Worker only
    uint32_t x_sample;
    size_t total_iterations;
    magik::wavefront_buffer_t wavefront_buffer;
    magik::color_pipeline_descriptor_t color_pipeline_descriptor;

    struct sub_system_update_policies_t
    {
        magik::e_magik_framebuffer_update_policy_types framebuffer;
        magik::e_magik_wavefront_buffer_update_policy_types wavefront;
        magik::e_magik_color_pipeline_update_policy_types color_pipeline;
    } pending;

    MAGIK_HOST bool is_nominal()
    {
        return is_running.load(std::memory_order_relaxed) && (initial_status == MAGIK_STATUS_0);
    }
};

namespace magik
{
    void run(magik_render_manager* manager);
}
