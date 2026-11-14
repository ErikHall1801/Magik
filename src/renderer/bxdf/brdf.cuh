#pragma once

#include "internal_math.h"
#include <cstdint>
#include <curand_kernel.h>
#include "curand.h"

#include "bxdf_utilities.cuh"

namespace magik
{
    static __device__ __inline__ void sample_lambertian_brdf(vec3f* new_direction, float* monte_carlo_weight_adjustment, curandState_t* random_device, vec3f n)
    {
        using ::sin;
        using ::cos;
        using ::acos;

        float u = curand_uniform(random_device);
        float theta = acos(1.0f - 2.0f*u);
        float phi = 2.0f*magik::pi*curand_uniform(random_device);

        vec3f p;
        p.x = cos(phi) * sin(theta);
        p.y = sin(phi) * sin(theta);
        p.z = cos(theta);

        *new_direction = (p+n).norm();
        *monte_carlo_weight_adjustment = 1.0f;
    }
}
