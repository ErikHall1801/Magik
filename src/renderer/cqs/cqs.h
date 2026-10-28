#pragma once

#include "magik.h"
#include "magik_error.h"

#include <atomic>
#include <memory>

namespace magik
{
    struct command_buffer_t
    {
        uint32_t n_occupied_chunk = 0;
        std::unique_ptr<uint32_t[]> data;
    };

    struct command_context_t
    {
        std::atomic<bool> is_swap_ready = false;
        uint32_t n_reserved_chunk = 0;
        bool drop_overflows = false;

        std::unique_ptr<command_buffer_t> front;
        std::unique_ptr<command_buffer_t> back;
    };

    void fetch_command_info(e_magik_cqs_command_types type, bool* is_valid_command, size_t* command_size);

    e_magik_result_types push_command(magik_render_manager_t manager, const void* command);

    e_magik_result_types dispatch_command_buffer(magik_render_manager_t manager, bool* is_dispatched);

    e_magik_result_types consume_command_buffer(magik_render_manager_t manager, command_buffer_t* command_buffer); 

    e_magik_result_types consume_back_command_buffer(magik_render_manager_t manager);
}
