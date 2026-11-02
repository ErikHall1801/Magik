#pragma once

#include <cstdint>
#include "internal_math.h"
#include "wavefront.h"

namespace magik
{
    void launch_kernel_redistribute_radiance_async(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer);
}
