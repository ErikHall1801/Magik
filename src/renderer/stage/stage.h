#pragma once

#include "optics.h"

namespace magik
{
    struct stage_t
    {
        magik::optical_system_t optical_systen;

        float c0 = 0.0f; 
        float c1 = 0.0f; 
        float c2 = 0.0f;
        float real = 0.0f;
        float imag = 0.0f;
    };
}
