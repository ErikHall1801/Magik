#pragma once
#include <atomic>
#include <memory>
#include "magik_error.h"
#include "magik.h"

namespace magik::cqs
{
    struct buffer_object
    {
        uint32_t n_occupied_chunk = 0;
        std::unique_ptr<uint32_t[]> data;
    };

    struct context
    {
        std::atomic<bool> is_swap_ready = false;
        uint32_t n_reserved_chunk = 0;
        bool drop_overflows = false;

        std::unique_ptr<buffer_object> front;
        std::unique_ptr<buffer_object> back;
    };

    void fetch_command_info(e_magik_cqs_command_types type, bool* is_valid_command, size_t* command_size);

    e_magik_result_types push_command(magik_render_manager_t manager, const void* command);

    e_magik_result_types dispatch_command_buffer(magik_render_manager_t manager, bool* is_dispatched);

    e_magik_result_types consume_command_buffer(magik_render_manager_t manager, buffer_object* buffer);

    e_magik_result_types consume_back_command_buffer(magik_render_manager_t manager);
}
