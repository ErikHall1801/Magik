#pragma once

#include "magik.h"
#include "cuda_host_device_utilities.h"
#include "internal_math.h"
#include <cuda_runtime.h>

namespace magik
{
    struct geodesic_step_values
    {
        vec4f four_position{};
        vec4f four_momentum{};
    };

    struct metric_scale_t
    {
        e_magik_spacetime_metric_types metric_type = MINKOWSKI;
        float schwarzschild_mass_parameter = 6.7329546075E26f;
        float kerr_mass_parameter = 6.7329546075E26f;
        float time_scale_scalar = 1.0f;
    };

    MAGIK_DEVICE_HOST static float get_metric_agnostic_length_scale(metric_scale_t metric_scale)
    {
        float result;

        switch(metric_scale.metric_type)
        {
            case MINKOWSKI:
            {
                result = 1.0f;
                break;
            };

            case SCHWARZSCHILD:
            {
                result = (magik::gravitational_constant * metric_scale.schwarzschild_mass_parameter) / (magik::speed_of_light*magik::speed_of_light);
                break;
            };

            case KERR:
            {
                result = (magik::gravitational_constant * metric_scale.kerr_mass_parameter) / (magik::speed_of_light*magik::speed_of_light);
                break;
            };

            default:
            {
                result = 1.0f;
                break;
            }
        }

        return result;
    }

    MAGIK_DEVICE_HOST static float get_metric_agnostic_time_scale(metric_scale_t metric_scale)
    {
        return (get_metric_agnostic_length_scale(metric_scale) / magik::speed_of_light)*metric_scale.time_scale_scalar;
    }

    MAGIK_DEVICE_HOST static float compute_metric_agnostic_local_timelike_component(vec3f vector, float input_vector_norm)
    {
        return sqrtf(vector.length2() - input_vector_norm);
    }

    MAGIK_DEVICE_HOST static vec4f convert_si_position_to_dimensionless_coordinate_system(vec3f spatial_si_coordinates, float global_time, float length_scale, float time_scale)
    {
        return vec4f{spatial_si_coordinates.x / length_scale, spatial_si_coordinates.y / length_scale, spatial_si_coordinates.z / length_scale, global_time / time_scale};
    }

    // MAGIK_DEVICE_HOST static float compute_metric_agnostic_contravariant_timelike_component();

    // MAGIK_DEVICE_HOST static float compute_metric_agnostic_redshift_factor();

    // MAGIK_DEVICE_HOST static vec4f compute_metric_agnostic_rest_frame_four_velocity();

    // MAGIK_DEVICE_HOST static vec4f convert_metric_agnostic_rest_frame_direction_to_global_four_momentum();

    // MAGIK_DEVICE_HOST static vec4f convert_metric_agnostic_global_to_rest_frame();

    // MAGIK_DEVICE_HOST static vec4f metric_agnostic_raise_index();
}
