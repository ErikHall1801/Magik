#pragma once

#include <cstdint>
#include "internal_math.h"
#include "wavefront.h"

namespace magik 
{
    void launch_kernel_swap_queues_async(magik_render_manager* manager, ray_queue_t queue_A, ray_queue_t queue_B);
}
