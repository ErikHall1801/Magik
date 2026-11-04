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

        MAGIK_DEVICE_HOST float compute_rms_error(geodesic_step_values error, geodesic_step_values y0, geodesic_step_values y1, float abs_tol, float rel_tol)
        {
            float sum_x0 = error.four_position.t / (abs_tol + rel_tol * fmaxf(fabsf(y0.four_position.t), fabsf(y1.four_position.t)));
            float sum_x1 = error.four_position.x / (abs_tol + rel_tol * fmaxf(fabsf(y0.four_position.x), fabsf(y1.four_position.x)));
            float sum_x2 = error.four_position.y / (abs_tol + rel_tol * fmaxf(fabsf(y0.four_position.y), fabsf(y1.four_position.y)));
            float sum_x3 = error.four_position.z / (abs_tol + rel_tol * fmaxf(fabsf(y0.four_position.z), fabsf(y1.four_position.z)));

            float sum_p0 = error.four_momentum.t / (abs_tol + rel_tol * fmaxf(fabsf(y0.four_momentum.t), fabsf(y1.four_momentum.t)));
            float sum_p1 = error.four_momentum.x / (abs_tol + rel_tol * fmaxf(fabsf(y0.four_momentum.x), fabsf(y1.four_momentum.x)));
            float sum_p2 = error.four_momentum.y / (abs_tol + rel_tol * fmaxf(fabsf(y0.four_momentum.y), fabsf(y1.four_momentum.y)));
            float sum_p3 = error.four_momentum.z / (abs_tol + rel_tol * fmaxf(fabsf(y0.four_momentum.z), fabsf(y1.four_momentum.z)));

            float total_sum = (sum_x0*sum_x0 + sum_x1*sum_x1 + sum_x2*sum_x2 + sum_x3*sum_x3 + sum_p0*sum_p0 + sum_p1*sum_p1 + sum_p2*sum_p2 + sum_p3*sum_p3) / 8.0f;
            return sqrtf(total_sum);
        }
    };

    MAGIK_DEVICE_HOST static geodesic_step_values operator+(geodesic_step_values v0, geodesic_step_values v1)
	{
		return geodesic_step_values{ v0.four_position + v1.four_position, v0.four_momentum + v1.four_momentum };
	}

    MAGIK_DEVICE_HOST static geodesic_step_values operator-(geodesic_step_values v0, geodesic_step_values v1)
	{
		return geodesic_step_values{ v0.four_position - v1.four_position, v0.four_momentum - v1.four_momentum };
	}

    MAGIK_DEVICE_HOST static geodesic_step_values operator*(float scalar, geodesic_step_values v0)
	{
		return geodesic_step_values{ scalar * v0.four_position, scalar * v0.four_momentum };
	}

    MAGIK_DEVICE_HOST static geodesic_step_values operator*(geodesic_step_values v0, float scalar)
	{
		return geodesic_step_values{ scalar * v0.four_position, scalar * v0.four_momentum };
	}

    MAGIK_DEVICE_HOST static geodesic_step_values operator/(geodesic_step_values v0, float scalar)
	{
		return geodesic_step_values{ v0.four_position / scalar, v0.four_momentum / scalar };
	}

    struct metric_scale_t
    {
        e_magik_spacetime_metric_types metric_type = MINKOWSKI;
        float schwarzschild_mass_parameter = 6.7329546075E26f;
        float kerr_mass_parameter = 6.7329546075E26f;
        float time_scale_scalar = 1.0f;
    };

    MAGIK_DEVICE_HOST static float compute_length_scale(metric_scale_t metric_scale)
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
        }

        return result;
    }

    MAGIK_DEVICE_HOST static float compute_time_scale(metric_scale_t metric_scale)
    {
        return (compute_length_scale(metric_scale) / magik::speed_of_light)*metric_scale.time_scale_scalar;
    }

    MAGIK_DEVICE_HOST static float compute_local_timelike_component(vec3f vector, float input_vector_norm)
    {
        return sqrtf(vector.length2() - input_vector_norm);
    }

    MAGIK_DEVICE_HOST static float compute_redshift_factor(float initial_four_vector_contraction, vec4f four_velocity, vec4f four_momentum)
    {
        float z = initial_four_vector_contraction / vector_dot_product(four_velocity, four_momentum);
        if(isnan(z) || isinf(z)) z = 100000.0f;
        return z;
    }

    MAGIK_DEVICE_HOST static vec4f convert_si_position_to_dimensionless_coordinate_system(vec3f spatial_si_coordinates, float global_time, float length_scale, float time_scale)
    {
        return vec4f{spatial_si_coordinates.x / length_scale, spatial_si_coordinates.y / length_scale, spatial_si_coordinates.z / length_scale, global_time / time_scale};
    }
}
