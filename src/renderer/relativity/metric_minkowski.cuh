#pragma once

#include "relativity_utilities.cuh"

namespace magik
{
    /* Step function */
    MAGIK_DEVICE_HOST static geodesic_step_values_t minkowski_geodesic_eq_rhs(geodesic_step_values_t y0)
    {
        vec4f d_four_momentum = vec4f{0.0f, 0.0f, 0.0f, 0.0f};
        vec4f d_four_position = vec4f{y0.four_momentum.x, y0.four_momentum.y, y0.four_momentum.z, -y0.four_momentum.t}; // Equivilant to raising the index
        return geodesic_step_values_t{d_four_position, d_four_momentum};
    }



    /* Specialization */
    using minkowski_metric = metric<e_magik_spacetime_metric_types::MINKOWSKI>;

    template<> struct minkowski_metric::params_t 
    {
        bool time_reversed;
    };

    template<> inline MAGIK_DEVICE_HOST float minkowski_metric::initial_h_step()
    {
        return 1000.0f;
    }

    template<> inline minkowski_metric::params_t minkowski_metric::make_params(magik_render_manager* manager, bool time_reversed)
    {
        minkowski_metric::params_t p;
        p.time_reversed = time_reversed;
        return p;
    }

    template<> inline minkowski_metric::params_t minkowski_metric::make_params(magik_trace_geodesic_metric_parameters_t metric_parameters, magik_trace_geodesic_integrator_parameters_t integrator_parameters, bool time_reversed)
    {
        minkowski_metric::params_t p;
        p.time_reversed = time_reversed;
        return p;
    }

    template<> inline MAGIK_DEVICE_HOST float minkowski_metric::length_scale(params_t p)
    {
        return 1.0f;
    }

    template<> inline MAGIK_DEVICE_HOST geodesic_step_values_t minkowski_metric::solve_step(geodesic_step_values_t y0, params_t p, float* h_step, float* h_taken)
    {
        *h_taken = *h_step;
        return solve_explicit_euler_step(minkowski_geodesic_eq_rhs, y0, *h_step);
    }

    template<> inline MAGIK_DEVICE_HOST geodesic_step_values_t minkowski_metric::geodesic_rhs(geodesic_step_values_t y0, params_t p)
    {
        return minkowski_geodesic_eq_rhs(y0);
    }

    template<> inline MAGIK_DEVICE_HOST bool minkowski_metric::in_domain(vec4f dimensionless_four_position, params_t p)
    {
        return false;
    }

    template<> inline MAGIK_DEVICE_HOST sym4_t minkowski_metric::compute_g(vec4f dimensionless_four_position, params_t p)
    {
        return { -1.0f, 0.0f, 0.0f, 0.0f,
                  1.0f, 0.0f, 0.0f,
                  1.0f, 0.0f,
                  1.0f, };
    }

    template<> inline MAGIK_DEVICE_HOST sym4_t minkowski_metric::compute_inv_g(vec4f dimensionless_four_position, params_t p)
    {
        return { -1.0f, 0.0f, 0.0f, 0.0f,
                  1.0f, 0.0f, 0.0f,
                  1.0f, 0.0f,
                  1.0f, };
    }

    template<> inline MAGIK_DEVICE_HOST vec4f minkowski_metric::reference_observer(vec4f dimensionless_four_position, params_t p)
    {
        return vec4f{ 0.0f, 0.0f, 0.0f, 1.0f };
    }
}
