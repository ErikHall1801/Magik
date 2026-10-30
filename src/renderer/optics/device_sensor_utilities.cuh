#pragma once

#include <cstdint>
#include "internal_math.h"
#include "cuda_runtime.h"
#include <curand_kernel.h>
#include "curand.h"

namespace magik
{
    /*
    * The idea of this header file is to consolidate the sensor generation logic
    * in order to eliminate the kernel which would ordinarily do so. Instead, we
    * simply include this header in whichever lens system is being used. 
    * Naturally this header is device only. 
    */

    __device__ static vec2f generate_screen_uv_coordinates(uint32_t x_resolution, uint32_t y_resolution)
    {
        int x_abs = threadIdx.x + blockIdx.x * blockDim.x;
        int y_abs = threadIdx.y + blockIdx.y * blockDim.y;

        float x_norm = -((float(x_abs) / float(x_resolution)) - 0.5f);
        float y_norm = -(float(y_abs) / float(y_resolution) - 0.5f);

        float u = x_norm;
        float v = y_norm;
        float ratio = float(y_resolution) / float(x_resolution);

        if (ratio < 1.0f)
        {
            v *= ratio;
        }
        else
        {
            u /= ratio;
        }

        return vec2f{u, v};
    }

    __device__ static float compute_inv_b(float sensor_diagonal_mm, uint32_t y_resolution, uint32_t x_resolution)
    {
        return sensor_diagonal_mm / sqrtf(static_cast<float>(x_resolution * x_resolution + y_resolution * y_resolution));
    }

    __device__ static vec3f generate_z_aligned_sensor_position(float sensor_diagonal_mm, uint32_t x_resolution, uint32_t y_resolution, curandState_t* random_device)
    {
        float inv_s = compute_inv_b(sensor_diagonal_mm, x_resolution, y_resolution);
        float width_mm = x_resolution * inv_s;
        float height_mm = y_resolution * inv_s;

        float num_of_pixels = static_cast<float>(x_resolution * y_resolution);
        float area_of_sensor = (width_mm * height_mm) / 1E6f;
        float pixel_side_length = sqrtf(area_of_sensor / num_of_pixels);
        float ju = (curand_uniform(random_device) - 0.5f) * pixel_side_length;
        float jv = (curand_uniform(random_device) - 0.5f) * pixel_side_length;

        vec2f uv = generate_screen_uv_coordinates(x_resolution, y_resolution);

        // The UV coordinates are flipped because all lens models naturally do so as well, thus the render is correctly orientated.
        return vec3f{ ((-uv.x * sensor_diagonal_mm) / 1000.0f) + ju, ((-uv.y * sensor_diagonal_mm) / 1000.0f) + jv, 0.0f };
    }
}
