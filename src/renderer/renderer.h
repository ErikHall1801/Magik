#pragma once

#include "magik.h"
#include "magik_error.h"
#include "framebuffer.h"
#include "command.h"
#include "stage.h"
#include "cuda_host_utilities.h"
#include <thread>
#include <atomic>
#include <chrono>

/*
We need to be structured about this, which means lets port the "run" function. 
*/

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

    /*
    What now ? Well, we have to port the kernel and make sure all logic 
    is transfered, then make it compile. 
    Now its time to change what "magik.cpp" does. Link the new functions
    and make all of this like, compile. 
    */
};

namespace magik
{
    void run(magik_render_manager* manager);
}
