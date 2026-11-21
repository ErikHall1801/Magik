#pragma once

#include "relativity_utilities.cuh"

namespace magik
{
    /* Step function */
    MAGIK_DEVICE_HOST static geodesic_step_values_t schwarzschild_geodesic_eq_rhs(geodesic_step_values_t y0, float mass_sign)
    {
        float x = y0.four_position.x;
        float y = y0.four_position.y;
        float z = y0.four_position.z;

        float pt = y0.four_momentum.t;
        float px = y0.four_momentum.x;
        float py = y0.four_momentum.y;
        float pz = y0.four_momentum.z;

        float w_sq = (x*x + y*y + z*z);
        float sigma = w_sq;
        float r = std::sqrt(0.5f * (w_sq + sigma));
        float r_sq = r * r;
        float r_cu = r_sq * r;
        float r_quad = r_sq * r_sq;
        float r_six = r_cu * r_cu;

        float inv_r = 1.0f / r;
        float inv_rsq = inv_r * inv_r;
        float inv_sigma = 1.0f / sigma;
        float scale_xz = 0.5f * inv_r * (1.0f + w_sq * inv_sigma);
        float scale_y = 0.5f * inv_r * (1.0f + w_sq * inv_sigma);
        vec4f drdq{x * scale_xz, y * scale_y, z * scale_xz, 0.0f};

        float d = r_sq;
        float inv_d = 1.0f / d;
        float inv_dsq = inv_d * inv_d;
        float kx_num = r * x;
        float kz_num = r * z;
        float kx = kx_num * inv_d;
        float kz = kz_num * inv_d;
        float ky = y * inv_r;

        float f_den = r_quad;
        float inv_f_den_sq = 1.0f / (f_den * f_den);
        float f_ = mass_sign * 2.0f * r_cu / f_den;

        float dfdq_scale = mass_sign * 2.0f * -r_six * inv_f_den_sq;
        vec4f dfdq_{ dfdq_scale * drdq.x, dfdq_scale * drdq.y, dfdq_scale * drdq.z, 0.0f };

        float dkx_dx = ((x * drdq.x + r) * d - 2.0f * r * drdq.x * kx_num) * inv_dsq;
        float dkx_dy = ((x * drdq.y) * d - 2.0f * r * drdq.y * kx_num) * inv_dsq;
        float dkx_dz = ((x * drdq.z) * d - 2.0f * r * drdq.z * kx_num) * inv_dsq;

        float dky_dx = -y * drdq.x * inv_rsq;
        float dky_dy = (r - y * drdq.y) * inv_rsq;
        float dky_dz = -y * drdq.z * inv_rsq;

        float dkz_dx = ((z * drdq.x) * d - 2.0f * r * drdq.x * kz_num) * inv_dsq;
        float dkz_dy = ((z * drdq.y) * d - 2.0f * r * drdq.y * kz_num) * inv_dsq;
        float dkz_dz = ((r + z * drdq.z) * d - 2.0f * r * drdq.z * kz_num) * inv_dsq;

        float kTp = px * kx + py * ky + pz * kz - pt;
        float f_kTp = f_ * kTp;
        float half_kTp_sq = 0.5f * kTp * kTp;
        vec4f beta{ px * dkx_dx + py * dky_dx + pz * dkz_dx, px * dkx_dy + py * dky_dy + pz * dkz_dy, px * dkx_dz + py * dky_dz + pz * dkz_dz, 0.0f };
        
        vec4f dqdt_lambda{ px - f_kTp * kx, py - f_kTp * ky, pz - f_kTp * kz, -pt + f_kTp };

        vec4f dpdt_lambda{ half_kTp_sq * dfdq_.x + f_kTp * beta.x, half_kTp_sq * dfdq_.y + f_kTp * beta.y, half_kTp_sq * dfdq_.z + f_kTp * beta.z, 0.0f };

        return geodesic_step_values_t{dqdt_lambda, dpdt_lambda};
    }



    /* Specialization */
    using schwarzschild_metric = metric<e_magik_spacetime_metric_types::SCHWARZSCHILD>;

    template<> struct schwarzschild_metric::params_t
    {
        bool time_reversed;
        float mass_parameter;
        float mass_sign;
        float event_horizon_scalar;

        float h_max;
        float abs_tol;
        float rel_tol;
        uint32_t n_max; 
    };

    template<> schwarzschild_metric::params_t schwarzschild_metric::make_params(magik_render_manager* manager, bool time_reversed)
    {
        return {    time_reversed,
                    fabsf(manager->stage.schwarzschild_mass), 
                    manager->stage.schwarzschild_mass > 0.0f ? 1.0f : -1.0f,
                    manager->stage.event_horizon_scalar, 
                    1000.0f, 
                    manager->stage.settings.integrator_absolute_error_tolerance, 
                    manager->stage.settings.integrator_relative_error_tolerance, 
                    manager->stage.settings.n_integrator_max_substep};
    }

    template<> schwarzschild_metric::params_t schwarzschild_metric::make_params(magik_trace_geodesic_metric_parameters_t metric_parameters, magik_trace_geodesic_integrator_parameters_t integrator_parameters, bool time_reversed)
    {
        return {    time_reversed,
                    fabsf(metric_parameters.schwarzschild_mass), 
                    metric_parameters.schwarzschild_mass > 0.0f ? 1.0f : -1.0f,
                    metric_parameters.event_horizon_scalar, 
                    1000.0f, 
                    integrator_parameters.integrator_absolute_error_tolerance, 
                    integrator_parameters.integrator_relative_error_tolerance, 
                    integrator_parameters.n_integrator_max_substep};
    }

    template<> MAGIK_DEVICE_HOST float schwarzschild_metric::initial_h_step()
    {
        return 1.0f;
    }

    template<> MAGIK_DEVICE_HOST float schwarzschild_metric::length_scale(params_t p)
    {
        return magik::gravitational_constant * p.mass_parameter / (magik::speed_of_light*magik::speed_of_light);
    }

    template<> MAGIK_DEVICE_HOST geodesic_step_values_t schwarzschild_metric::solve_step(geodesic_step_values_t y0, params_t p, float* h_step, float* h_taken)
    {
        return solve_runge_kutta_fehlberg_45_step(schwarzschild_geodesic_eq_rhs, y0, h_step, h_taken, p.h_max, p.n_max, p.abs_tol, p.rel_tol, p.mass_sign);
    }

    template<> MAGIK_DEVICE_HOST geodesic_step_values_t schwarzschild_metric::geodesic_rhs(geodesic_step_values_t y0, params_t p)
    {
        return schwarzschild_geodesic_eq_rhs(y0, p.mass_sign);
    }

    template<> MAGIK_DEVICE_HOST bool schwarzschild_metric::in_domain(vec4f dimensionless_four_position, params_t p)
    {
        float r = sqrtf(dimensionless_four_position.x*dimensionless_four_position.x + dimensionless_four_position.y*dimensionless_four_position.y + dimensionless_four_position.z*dimensionless_four_position.z);
        if (p.mass_sign < 0.0f) return r < 1e-3f;
        return r <= 2.0f * p.event_horizon_scalar;
    }

    template<> MAGIK_DEVICE_HOST sym4_t schwarzschild_metric::compute_g(vec4f dimensionless_four_position, params_t p)
    {
        const float r  = sqrtf(dimensionless_four_position.x * dimensionless_four_position.x + dimensionless_four_position.y * dimensionless_four_position.y + dimensionless_four_position.z * dimensionless_four_position.z);
        const float f = 2.0f * p.mass_sign / r;
        const float kx = dimensionless_four_position.x / r, ky = dimensionless_four_position.y / r, kz = dimensionless_four_position.z / r;

        return { -1.0f + f, f * kx, f * ky, f * kz,
                  1.0f + f * kx * kx, f * kx * ky, f * kx * kz,
                  1.0f + f * ky * ky, f * ky * kz,
                  1.0f + f * kz * kz };
    }

    template<> MAGIK_DEVICE_HOST sym4_t schwarzschild_metric::compute_inv_g(vec4f dimensionless_four_position, params_t p)
    {
        const float r  = sqrtf(dimensionless_four_position.x * dimensionless_four_position.x + dimensionless_four_position.y * dimensionless_four_position.y + dimensionless_four_position.z * dimensionless_four_position.z);
        const float f = 2.0f * p.mass_sign / r;
        const float kx = dimensionless_four_position.x / r, ky = dimensionless_four_position.y / r, kz = dimensionless_four_position.z / r;

        return { -1.0f - f, f * kx, f * ky, f * kz,
                  1.0f - f * kx * kx, -f * kx * ky, -f * kx * kz,
                  1.0f - f * ky * ky, -f * ky * kz,
                  1.0f - f * kz * kz };
    }

    template<> MAGIK_DEVICE_HOST vec4f schwarzschild_metric::reference_observer(vec4f dimensionless_four_position, params_t p)
    {
        const sym4_t g = schwarzschild_metric::compute_g(dimensionless_four_position, p);
        return vec4f{ 0.0f, 0.0f, 0.0f, 1.0f / sqrtf(-g.tt) };
    }
}
