#pragma once

#include "magik.h"
#include "magik_error.h"
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
    std::atomic<bool> is_running = false;
    std::thread worker_thread;

    std::atomic<e_magik_result_types> atomic_last_error_type = {MAGIK_SUCCESS};

    e_magik_manager_display_types display_type = MAGIK_DISPLAY_SWAPCHAIN;

    void* cuda_stream = nullptr;
    bool owns_stream = false;
    uint32_t cuda_device = 0;

    magik::command_context_t command_context;
    magik::framebuffer_swapchain_t framebuffer_swapchain;
    magik::stage_t stage;

    magik::color_pipeline_descriptor_t color_pipeline_descriptor;

    std::atomic<uint32_t> x_sample = 0;
};

namespace magik
{
    void run(magik_render_manager* manager);
}
