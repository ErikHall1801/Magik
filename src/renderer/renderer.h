#pragma once

#include "magik.h"
#include "framebuffer.h"
#include "cqs.h"
#include "stage.h"

#include <thread>
#include <atomic>

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

    // framebuffer <- You know, the framebuffer being drawn to
    // cqs <- Command Queue System
    // stage <- The collection of scenes this manager... manages ?  
};
