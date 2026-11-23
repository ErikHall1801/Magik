#pragma once

#include "magik.h"
#include "internal_math.h"
#include <cstdint>

/*
* Whats the idea ? 
* This file combines the various sub-components of Magiks optical logic. 
* It also defines various structs and enums. The big question here is 
* how we handle functions. The thin lens has a lot of device functions, 
* where do they go ? Well, of course, a cuh file. 
*/

namespace magik
{
    struct optical_system_settings_t
    {
        // Lens
        float focal_length = 12.0f;

        float iso = 500.0f;
        float fps = 24.0f;
        // Shutter type
        // motion blur
        float shutter_angle = 180.0f;
        float sensor_diagonal_mm = 24.0f;
        uint32_t x_resolution = 2195;
        uint32_t y_resolution = 1860;

        // Body (Parasitic heat etc.)

        vec3f position = vec3f{2.0f, 0.0f, 9.0f};
        mat3f orientation = {1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 1.0f};
    };
}
