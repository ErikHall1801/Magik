#pragma once

#include <cstdint>
#include "internal_math.h"
#include "cuda_runtime.h"
#include <curand_kernel.h>
#include "curand.h"

namespace magik
{
    // These are commented out because it makes little sense to add those functions until 
    // we have the proper camera type. Or rather thin lens properties. We just need to 
    // unfuck the camera rn. 

    /*__device__ static vec3f generate_position_on_ideal_z_aligned_polynomial_aperture(uint32_t n_aperture_blade, float focal_length, float f_number, curandState_t* random_device)
    {
        float n_blade = static_cast<float>(n_aperture_blade);
        int n_actual = static_cast<int>(curand_uniform(random_device) * (n_blade - 1.0f));
        float radius = 0.5f*(focal_length / 1000.0f) / f_number;

        float rect_height = radius * cosf(magik::pi / n_blade);
        float rect_width = radius * sinf(magik::pi / n_blade);

        float height_actual = curand_uniform(random_device) * rect_height;
        float width_actual = curand_uniform(random_device) * rect_width;

        float r_actual = 0.0f, theta_actual = 0.0f;

        if(height_actual == 0.0f || height_actual == rect_height)
        {
            r_actual = 0.0f;
            theta_actual = 0.0f;
        }
        else if(width_actual / height_actual > rect_width / rect_height)
        {
            r_actual= sqrtf((rect_height-height_actual)*(rect_height-height_actual)+(rect_width-width_actual)*(rect_width-width_actual));
            theta_actual = atanf((rect_width-width_actual)/(rect_height-height_actual));
        }
        else
        {
            r_actual = sqrtf(height_actual*height_actual+width_actual*width_actual);
            theta_actual = -atanf(width_actual/height_actual);
        }

        theta_actual += 2.0f * magik::pi * n_actual / n_blade;

        float x_actual = r_actual * cosf(theta_actual);
        float y_actual = r_actual * sinf(theta_actual);

        return vec3f{x_actual, y_actual, 0.0f};
    }

    __device__ static bool has_hit_petzval_focal_plane(float* t_focal_point, vec3f orig, vec3f dir, float focus_plane_z, float petzval_field_curvature_parameter)
    {
        // Case 1: Flat field

        // Case 2: Curved field
    }*/

    __device__ static void generate_thin_lens_ray(vec3f* dir_out, vec3f* orig_out, vec3f dir_in, vec3f orig_in, float focal_length_mm)
    {
        // Future additions; Coma

        vec3f position_on_sensor = orig_in, position_on_aperture;
        float focal_length_m = focal_length_mm / 1000.0f;

        vec3f dir_aperture_to_focus_plane, dir_sensor_to_aperture;
        vec3f lens_position = vec3f{0.0f, 0.0f, -focal_length_m};

        position_on_aperture = lens_position;
        dir_aperture_to_focus_plane =  (position_on_aperture - position_on_sensor).norm();
        dir_sensor_to_aperture = dir_aperture_to_focus_plane;

        *orig_out = position_on_aperture;
        *dir_out = dir_aperture_to_focus_plane;
    }
}
