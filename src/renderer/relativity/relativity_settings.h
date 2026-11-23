#pragma once

#include "magik.h"
#include "internal_math.h"
#include <cstdint>

namespace magik
{
    struct relativity_settings_t
    {
        e_magik_spacetime_metric_types metric_type = KERR;
        float integrator_absolute_error_tolerance = 1e-3f;
        float integrator_relative_error_tolerance = 1e-10f;
        uint32_t n_integrator_max_substep = 56;

        vec3f observer_local_proper_velocity;

        float celestial_sphere_radius = 1000.0f;

        float schwarzschild_event_horizon_scalar = 1.01f;
        float schwarzschild_mass_parameter = 6.7329546075E26f;

        float kerr_event_horizon_scalar = 1.01f;
        float kerr_mass_parameter = 6.7329546075E26f;
        float kerr_dimensionless_spin_parameter = 0.999f;
    };
}
