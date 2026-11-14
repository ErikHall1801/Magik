#pragma once

#include <atomic>

namespace magik
{
    struct ready_slot_t
    {
        uint8_t index; 
        bool is_new;
    };

    template<typename T_payload> struct triple_swapchain_t
    {
        T_payload payload_collection[3];

        uint8_t front_index = 0;
        std::atomic<ready_slot_t> ready{ready_slot_t{1, false}};
        uint8_t work_index = 2;

        T_payload& get_work()
        {
            return payload_collection[work_index];
        }

        void swap_work_and_ready()
        {
            ready_slot_t previews = ready.exchange({work_index, true});
            work_index = previews.index;
        }

        void try_swap_ready_and_front()
        {
            if(!ready.load().is_new) return false;
            ready_slot_t previous = ready.exchange({front_index, false});
            front_index = previous.index;
            return true;
        }

        T_payload& get_front()
        {
            return payload_collection[front_index];
        }
    };
}
