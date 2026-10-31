#pragma once

#include <cstdint>
#include "internal_math.h"
#include "wavefront.h"

namespace magik
{
    void launch_kernel_splat_to_render_buffer_sync(magik_render_manager* manager, wavefront_ray_buffer_t* buffer, float* d_data);
}
