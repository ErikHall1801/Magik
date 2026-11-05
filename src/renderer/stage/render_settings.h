#pragma once

#include "internal_math.h"
#include <cstdint>

namespace magik
{
    struct render_settings_t
    {
        // CUDA Specific
        uint32_t threads_per_block_x = 16;
        uint32_t threads_per_block_y = 16;
        uint32_t wavefront_threads_per_block = 256;

        // Spectral integration
        uint32_t n_spectral_irradiance_bin = 12;
        float max_wavelength_nm = 830.0f;
        float min_wavelength_nm = 360.0f;
        float redistribution_standard_deviation = 10.0f;

        // Relativistic integration
        e_magik_spacetime_metric_types metric_type = e_magik_spacetime_metric_types::MINKOWSKI;
        float integrator_absolute_error_tolerance = 1e-2f;
        float integrator_relative_error_tolerance = 1e-10f;
        uint32_t n_integrator_max_substep = 56;

        // Ray limits
        uint32_t n_geodesic_step_limit = 512;
        uint32_t n_bounces_limit = 10; // Once the bxdf is re-integrated we have to include a sub-section for the layered bounces ! 
    };
}
