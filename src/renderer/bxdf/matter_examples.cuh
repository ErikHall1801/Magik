#pragma once

#include "internal_math.h"
#include <cstdint>
#include <curand_kernel.h>

#include "bxdf_utilities.cuh"
#include "brdf.cuh"

namespace magik
{
    /*
    The idea is to give each bxdf matter instance its own type
    The host can then define a list with these types, which the
    compiler uses to make specalizations of the bxdf kernel. 
    The matter type holds a contract with the kernel. It must 
    have these two member functions. 
    */

    struct bxdf_null_matter_t
    {
        static __device__ vec3f local_proper_velocity_function(const bxdf_velocity_context& v_context)
        {
            return vec3f{0.0f, 0.0f, 0.0f};
        }

        static __device__ bxdf_result material_function(const bxdf_material_context& m_context)
        {
            return bxdf_result{};
        }
    };

    struct bxdf_diffuse_matter_t
    {
        static __device__ vec3f local_proper_velocity_function(const bxdf_velocity_context& v_context)
        {
            return vec3f{0.0f, 0.0f, 0.0f};
        }

        static __device__ bxdf_result material_function(const bxdf_material_context& m_context)
        {
            bxdf_result result;

            if((m_context.global_frame_geometric_normal.x*m_context.global_frame_geometric_normal.x) > 0.0f)
            {
                result.outgoing_rest_frame_direction = vector_reflect(m_context.rest_frame_incoming_direction, m_context.rest_frame_facing_normal).make_norm();
                result.monte_carlo_weight_adjustment = 1.0f;
            }
            else
            {
                sample_lambertian_brdf(&result.outgoing_rest_frame_direction, &result.monte_carlo_weight_adjustment, m_context.random_device, m_context.rest_frame_facing_normal);
            }

            result.type = REFLECTED;

            return result;
        }
    };

    struct bxdf_illuminant_matter_t
    {
        static __device__ vec3f local_proper_velocity_function(const bxdf_velocity_context& v_context)
        {
            return vec3f{0.0f, 0.0f, 0.0f};
        }

        static __device__ bxdf_result material_function(const bxdf_material_context& m_context)
        {
            bxdf_result result;

            result.spectral_radiance = evaluate_white_led_spectrum(m_context.redshifted_wavelength_nm) * 4000000000.0f; // sample_plancks_law(m_context.redshifted_wavelength_nm, 5600.0f) * 0.02f;
            result.monte_carlo_weight_adjustment = 1.0f;
            result.type = ABSORBED;

            return result;
        }
    };

    struct bxdf_horizon_matter_t
    {
        static __device__ vec3f local_proper_velocity_function(const bxdf_velocity_context& v_context)
        {
            return vec3f{0.0f, 0.0f, 0.0f};
        }

        static __device__ bxdf_result material_function(const bxdf_material_context& m_context)
        {
            bxdf_result result;

            result.spectral_radiance = 0.0f; //sample_plancks_law(m_context.sensor_wavelength_nm, 2600.0f) * 0.1f * (m_context.redshift_factor*m_context.redshift_factor*m_context.redshift_factor*m_context.redshift_factor*m_context.redshift_factor);
            result.monte_carlo_weight_adjustment = 0.0f;
            result.type = ABSORBED;

            return result;
        }
    };
}
