#pragma once

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
    struct optical_system_t
    {
        // Lens
        // Shutter (Shutter angle, shutter type)
        // Sensor (As in type and properties)
        // Body
        // Video settings (FPS, motion blur) 
        // Physical properties (Position, velocity, orientation)
        
        // But for now, lets not make this more complicated than it has to be
        // We dont need anything else for a basic camera. We technically do not
        // even need the sensor diagonal. 

        float focal_length = 12.0f;

        float sensor_diagonal_mm = 24.0f;
        uint32_t x_resolution = 2195;
        uint32_t y_resolution = 1860;

        vec3f position = vec3f{2.0f, 5.0f, 9.0f};
        mat3f orientation;
    };
}
