#pragma once

#include "optics.h"

namespace magik
{
    struct stage_t
    {
        magik::optical_system_t optical_systen;

        vec3f box_max = {10.0f, 10.0f, 10.0f};
        vec3f box_min = {-10.0f, 0.0f, -10.0f};
        vec3f light_max = {5.0f, 10.5f, 5.0f};
        vec3f light_min = {-5.0f, 9.5f, -5.0f};

        float c0 = 0.0f; 
        float c1 = 0.0f; 
        float c2 = 0.0f;
        float real = 0.0f;
        float imag = 0.0f;
    };
}
