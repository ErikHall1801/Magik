#pragma once
#include <thread>
#include <atomic>
#include <memory>
#include <variant>
#include "magik.h" 
#include "magik_arbitrary_output_variables.h" 
#include "magik_command_queue_system.h"
#include "magik_host_memory.h"
#include "magik_optics.h"

// Rename this to just "manager"
namespace magik::render_manager
{
    struct context
    {
        magik::optics::camera tmp_camera;

        /*
        We can, for the moment, just hard code the two pieces 
        of geometry to get on with things. 
        */
        float box_min_x = -10.0f;
        float box_min_y = 0.0f;
        float box_min_z = -10.0f;
        float box_max_x = 10.0f;
        float box_max_y = 20.0f;
        float box_max_z = 10.0f;

        float light_min_x = -4.0f;
        float light_min_y = 19.0f;
        float light_min_z = -4.0f;
        float light_max_x = 4.0f;
        float light_max_y = 21.0f;
        float light_max_z = 4.0f;
    };
}

struct magik_render_manager
{
    std::atomic<bool> is_running = false;
    std::thread worker_thread;

    std::atomic<e_magik_result_types> atomic_last_error_type = {MAGIK_SUCCESS};

    e_magik_manager_display_types display_type = MAGIK_DISPLAY_SWAPCHAIN;

    void* cuda_stream = nullptr;
    bool owns_stream = false;
    uint32_t cuda_device = 0;

    magik::aov::context aov_context;
    magik::cqs::context cqs_context;

    host_mem_reserve_function user_host_mem_reserve_func = nullptr;
    host_mem_commit_function user_host_mem_commit_func = nullptr;
    host_mem_decommit_function user_host_mem_decommit_func = nullptr;
    host_mem_release_function user_host_mem_release_func = nullptr;
    magik::host_memory::host_mem_arena* host_arena;

    std::atomic<uint64_t> host_mem_reserve {0};
    std::atomic<uint64_t> host_mem_commit {0};

    // This is tmp
    magik::render_manager::context render_context;
    // magik::render_manager::render_context dcc_render_context;
    // magik::render_manager::render_context api_render_context;
    // std::unique_ptr<magik::render_manager::render_context> dcc_render_context_history;
    // std::unique_ptr<magik::render_manager::render_context> api_render_context_history;
};
