#pragma once
#include <thread>
#include <atomic>
#include <memory>
#include <variant>
#include "magik.h" 

namespace magik::render_manager
{
    struct render_context
    {
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
    std::atomic<bool> is_running = true;
    std::thread worker_thread;
    uint32_t cuda_device = 0;

    // magik::render_manager::aov_context aov;
    // magik::render_manager::cqs_context cqs;

    // magik::render_manager::render_context dcc_render_context;
    // magik::render_manager::render_context api_render_context;
    // std::unique_ptr<magik::render_manager::render_context> dcc_render_context_history;
    // std::unique_ptr<magik::render_manager::render_context> api_render_context_history;
};
