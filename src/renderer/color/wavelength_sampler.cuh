#pragma once

#include "internal_math.h"
#include <curand_kernel.h>

namespace magik
{
    __device__ __inline__ static void draw_random_wavelength_uniform(float* wavelength_out, float* monte_carlo_weight_out, float max_wavelength_nm, float min_wavelength_nm, curandState_t* random_state)
    {
        *wavelength_out = magik::lerp(min_wavelength_nm, max_wavelength_nm, curand_uniform(random_state));
        *monte_carlo_weight_out = 1.0f / (max_wavelength_nm - min_wavelength_nm);
    }
}
