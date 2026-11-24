#pragma once

#include "magik.h"
#include "wavefront.h"
#include "framebuffer.h"
#include "command.h"
#include "stage.h"
#include "cuda_host_utilities.h"
#include "color_pipeline.cuh"
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

    // CUDA
    void* cuda_stream = nullptr;
    bool owns_stream = false;
    uint32_t cuda_device = 0;

    // DCC <-> worker
    magik::command_context_t command_context;
    magik::framebuffer_swapchain_t framebuffer_swapchain;
    e_magik_manager_display_types display_type;

    // Worker only
    magik::stage_t stage;
    e_magik_command_update_policy_types pending_update_policy;
    magik::wavefront_buffer_t wavefront_buffer;
    magik::color_pipeline_descriptor_t color_pipeline_descriptor;
};

namespace magik
{
    void run(magik_render_manager* manager);
}
