#pragma once

#include "magik.h"
#include "cuda_host_device_utilities.h"
#include "internal_math.h"
#include <cstdint>
#include <curand_kernel.h>
#include "curand.h"

namespace magik
{
    typedef enum e_magik_bxdf_result_types
    {
        REFLECTED = 0,
        TRANSMITTED = 1,
        EMITTED = 2,
        ABSORBED = 3,
        SCATTERED = 4
    } e_magik_bxdf_result_types;

    struct bxdf_result
    {
        e_magik_bxdf_result_types type = ABSORBED;
        float spectral_radiance = 0.0f;
        float monte_carlo_weight_adjustment = 0.0f;
        vec4f outgoing_rest_frame_direction;
    };

    struct bxdf_velocity_context
    {

    };

    struct bxdf_material_context : bxdf_velocity_context
    {
        vec3f normal;
        float wavelength_nm;
        curandState_t* random_device;
    };

    /*
    The idea is to give each bxdf matter instance its own type
    The host can then define a list with these types, which the
    compiler uses to make specalizations of the bxdf kernel. 
    The matter type holds a contract with the kernel. It must 
    have these two member functions. 
    */
    struct bxdf_null_matter
    {
        static __device__ vec3f velocity_function(const bxdf_velocity_context& v_context)
        {
            return vec3f{0.0f, 0.0f, 0.0f};
        }

        static __device__ bxdf_result material_function(const bxdf_material_context& m_context)
        {
            return bxdf_result{};
        }
    };
}
