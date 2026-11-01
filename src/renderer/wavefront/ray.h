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

    struct sensor_wavelength_nm_t { using type = float; uint32_t dimension = 1; };

    struct monte_carlo_weight_t { using type = float; uint32_t dimension = 1; };

    struct spectral_radiance { using type = float; uint32_t dimension = 1; };

    struct intrinsic_spectral_irradiance_t { using type = float; uint32_t dimension = 1; }; // This then needs to be set by the settings

    struct random_device_t { using type = curandState_t; uint32_t dimension = 1; };

    struct position_t { using type = vec3f; uint32_t dimension = 1; };

    struct direction_t { using type = vec3f; uint32_t dimension = 1; };

    struct step_distance_t { using type = float; uint32_t dimension = 1; };

    struct n_step_t { using type = uint32_t; uint32_t dimension = 1; };

    struct hit_id_t { using type = uint32_t; uint32_t dimension = 1; };

    struct hit_normal_t { using type = vec3f; uint32_t dimension = 1; }; 

    struct ray_pool_t
    {
        /*
        Some ideas; 

        - We need the device arena.  
        - We can use variadic templates, so each member is a type 
        - We have to loop over the members at compile time, compute the total size
          and allocate an arena of that size. 
        - Then we just push buffers to the arena and store the pointers. 
        - Instead of feeding n_bin to the allocate, we should access the specific 
          element and change the dimension member. 

        allocate(uint32_t x_resolution, uint32_t y_resolution);
        free();

        - We can aim to remove internal_memory.h and just make device_arena.h
          for all our memory needs. Since, realistically, everything happens in 
          arenas anyways. 
        */

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
