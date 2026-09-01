#pragma once
#include <atomic>
#include <memory>

namespace magik::cqs
{
    struct context
    {
        std::atomic<bool> is_swap_ready = false;

        uint32_t n_history = 16;
        uint32_t history_index = 0;
        uint32_t n_command_buffer_element = 500;

        uint32_t dcc_buffer_offset_chunks = 0;
        uint32_t api_consume_size_chunks = 0;

        std::unique_ptr<uint32_t> A;
        std::unique_ptr<uint32_t> B;
    };
}
