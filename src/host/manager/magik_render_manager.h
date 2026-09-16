#pragma once
#include <thread>
#include <atomic>
#include <memory>
#include <variant>
#include "magik.h" 
#include "magik_arbitrary_output_variables.h" 
#include "magik_command_queue_system.h"

namespace magik::render_manager
{
    struct context
    {
        float c0 = 0.0f;
        float c1 = 0.15f;
        float c2 = 0.20f;

        float real = 0.0f;
        float imag = 0.0f;

        /*
        The problem here is that the render context kind of 
        has to be in the global namespace. So we can save it
        later. 
        But, this right here is the correct place for it. So
        what do we do ? 
        */
    };
}

struct magik_render_manager
{
    std::atomic<bool> is_running = false;
    std::thread worker_thread;

    e_magik_manager_display_types display_type = MAGIK_DISPLAY_SWAPCHAIN;

    void* cuda_stream = nullptr;
    bool owns_stream = false;
    uint32_t cuda_device = 0;

    magik::aov::context aov_context;
    magik::cqs::context cqs_context;

    magik::render_manager::context render_context;

    // magik::render_manager::render_context dcc_render_context;
    // magik::render_manager::render_context api_render_context;
    // std::unique_ptr<magik::render_manager::render_context> dcc_render_context_history;
    // std::unique_ptr<magik::render_manager::render_context> api_render_context_history;
};
