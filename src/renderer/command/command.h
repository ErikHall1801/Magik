#pragma once

#include "magik.h"
#include "internal_error.h"
#include "stage.h"
#include "framebuffer.h"
#include "wavefront.h"
#include "color_pipeline.h"
#include <string> // ???
#include <array>
#include <cmath>
#include <cstring>
#include <type_traits>
#include <atomic>
#include <memory>

namespace magik
{
    struct command_buffer_t
    {
        uint32_t n_occupied_chunk = 0;
        std::unique_ptr<uint32_t[]> data;
    };

    struct command_swapchain_t
    {
        std::atomic<bool> is_swap_ready = false;
        uint32_t n_reserved_chunk = 0;
        bool drop_overflows = false;

        std::unique_ptr<command_buffer_t> front;
        std::unique_ptr<command_buffer_t> back;
    };

    struct command_context_t
    {
        e_magik_framebuffer_update_policy_types& framebuffer_update_policy;
        e_magik_wavefront_buffer_update_policy_types& wavefront_update_policy;
        e_magik_color_pipeline_update_policy_types& color_pipeline_update_policy;

        e_magik_manager_status_types& status;
        e_magik_result_types& status_reason;
        command_swapchain_t& command_swapchain;
        framebuffer_swapchain_t& framebuffer_swapchain;
        stage_t& stage;
    };

    struct command_result_t
    {
        e_magik_result_severity_types severity = MAGIK_RESULT_SEVERITY_NONE;
        e_magik_result_types error = MAGIK_SUCCESS;
    };

    struct command_element_t
    {
        uint32_t id;
        uint32_t size;
        command_result_t (*apply)(command_context_t, const void*);
    };

    e_magik_result_types push_command(command_buffer_t* front_command_buffer, uint32_t n_reserved_chunk, bool drop_overflows, const void* command);

    bool dispatch_command_buffer(command_swapchain_t& swpc);

    void consume_back_command_buffer(command_context_t ctx);
}
