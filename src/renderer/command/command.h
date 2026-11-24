#pragma once

#include "magik.h"
#include "magik_error.h"

#include <atomic>
#include <memory>

namespace magik
{
    typedef enum e_magik_command_update_policy : uint32_t // The idea, obviously, is that each successive policy does the work the lower ones as well 
    {
        MAGIK_COMMAND_UPDATE_POLICY_NONE = 0u,
        MAGIK_COMMAND_UPDATE_POLICY_RESET_ISI = 1u,
        MAGIK_COMMAND_UPDATE_POLICY_REBUILD_COLOR_PIPELINE = 2u,
        MAGIK_COMMAND_UPDATE_POLICY_REBUILD_TLAS = 3u,
        MAGIK_COMMAND_UPDATE_POLICY_REBUILD_BLAS = 4u,
        MAGIK_COMMAND_UPDATE_POLICY_REALLOC_WAVEFRONT_BUFFER = 5u,
        MAGIK_COMMAND_UPDATE_POLICY_REALLOC_ALL = 6u
    } e_magik_command_update_policy;

    struct command_result_t
    {
        e_magik_result_severity_types severity = MAGIK_RESULT_SEVERITY_NONE;
        e_magik_result_types result = MAGIK_SUCCESS;
    };

    struct command_element_t
    {
        uint32_t id;
        uint32_t size;
        e_magik_command_update_policy update_policy;
        command_result_t (*apply)(magik_render_manager_t, const void*);
    };

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

    e_magik_result_types push_command(magik_render_manager_t manager, const void* command);

    e_magik_result_types dispatch_command_buffer(magik_render_manager_t manager, bool* is_dispatched);

    e_magik_result_types consume_command_buffer(magik_render_manager_t manager, command_buffer_t* command_buffer); 

    e_magik_result_types consume_back_command_buffer(magik_render_manager_t manager);
}
