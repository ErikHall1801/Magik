#pragma once
#include <atomic>
#include <memory>
#include "magik.h" 

namespace magik::aov
{
    struct internal_buffer
    {
        /*
        So, what is the problem ? Well, we need 2 buffers. A Magik
        internal representation for the AOV, and a user defined 
        output. 
        */

        uint32_t x_resolution;
        uint32_t y_resolution;

        float* albedo = nullptr; //RGB, no alpha !
    };

    struct context
    {
        /*
            What is the idea here ? 
            -   Magik renders to the back buffer. When it is done, it atomically swaps it with the 
                ready buffer. This way we never have to wait for the DCC. 
            -   it sets the atomic bool "is_ready_buffer_updated" to true.  
            -   The DCC calls magik_aov_fetch()
            -   This function checks if the ready buffer has been updated since the last check 
            -   If yes, it atomically swaps the Front and Ready buffers. 

            How does this work in practice ? 
            The critical aspect is the ready buffer. The front and back buffers are owned by the 
            DCC and API respectively. 

            So, for the API the idea is that at the end of the render operation, when we have 
            written to the back buffer, we do two things. 
            1. ready.exchange(back). This atomically swaps the back and ready buffers.
            2. is_ready_updated.store(true, std::memory_order_release); This signals to the DCC that the ready buffer has changed

            On the DCC side the following happens;
            1. if(!is_ready_updated.load(), std::memory_order_acqire) return
            2. ready.exchange(front). This swaps the ready and front buffers
            3. is_ready_updated.store(false, std::memory_order_release);
        */

        internal_buffer buffers[3];

        internal_buffer* front = nullptr; //buffers[0]
        internal_buffer* back = nullptr; //buffers[1]

        std::atomic<internal_buffer*> ready{nullptr}; //buffers[2]
        std::atomic<bool> is_ready_updated = false;
    };
}

struct magik_aov_buffer_external
{
    e_magik_aov_config_types type; 
    uint32_t x_resolution = 0;
    uint32_t y_resolution = 0; 
};
