#pragma once

#include <cstdint>
#include "internal_math.h"
#include "wavefront.h"

namespace magik
{
    void launch_kernel_tmp_advance_async(magik_render_manager* manager, wavefront_ray_buffer_t* buffer);
}
