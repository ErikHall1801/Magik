#pragma once

#include "internal_math.h"
#include <cstdint>
#include "cuda_runtime.h"
#include <curand_kernel.h>
#include "curand.h"

namespace magik
{
    struct ray_queue_t
    {
        uint32_t* d_count = nullptr; 
        uint32_t* d_id = nullptr;
    };

    struct ray_pool_t
    {
        // Geodesic

        // bxdf
        float* d_sensor_wavelength_nm = nullptr;
        float* d_monte_carlo_weight = nullptr;
        float* d_spectral_radiance = nullptr;
        float* d_intrinsic_spectral_irradiance = nullptr;

        // Hit

        // Info 

        // Random
        curandState* d_random_device = nullptr;

        // All of the below will be replaced

        vec3f* d_pos = nullptr;
        vec3f* d_dir = nullptr;
        float* d_step_distance = nullptr;

        // All of these need to be re-initalized each sample to sensible values. 
        uint32_t* n_step = nullptr;
        uint32_t* hit_id = nullptr;
        vec3f* hit_normal = nullptr;
    };
}
