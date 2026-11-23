#pragma once

#include "relativity_utilities.cuh"

namespace magik
{
    /* Metric - Components */
    MAGIK_DEVICE_HOST static float kerr_schild_r(float dimensionless_x, float dimensionless_y, float dimensionless_z, float dimensionless_spin_parameter)
    {
        float R = (dimensionless_x*dimensionless_x + dimensionless_y*dimensionless_y + dimensionless_z*dimensionless_z - dimensionless_spin_parameter*dimensionless_spin_parameter);
        float r_squared = 0.5f*R + 0.5f*sqrtf(R*R + 4.0f*dimensionless_spin_parameter*dimensionless_spin_parameter*dimensionless_y*dimensionless_y);
        return sqrtf(r_squared);
    }

    MAGIK_DEVICE_HOST static float kerr_schild_f(float dimensionless_y, float r, float dimensionless_spin_parameter)
    {
        return 2.0f*r*r*r / (r*r*r*r + dimensionless_spin_parameter*dimensionless_spin_parameter*dimensionless_y*dimensionless_y);
    }

    MAGIK_DEVICE_HOST static float kerr_schild_k_x(float null_congruence_k_x, float null_congruence_k_z, float r, float dimensionless_spin_parameter)
    {
        return (r*null_congruence_k_x - dimensionless_spin_parameter*null_congruence_k_z)/(r*r + dimensionless_spin_parameter*dimensionless_spin_parameter);
    }

    MAGIK_DEVICE_HOST static float kerr_schild_k_y(float null_congruence_k_y, float r)
    {
        return null_congruence_k_y/r;
    }

    MAGIK_DEVICE_HOST static float kerr_schild_k_z(float null_congruence_k_x, float null_congruence_k_z, float r, float dimensionless_spin_parameter)
    {
        return (r*null_congruence_k_z + dimensionless_spin_parameter*null_congruence_k_x)/(r*r + dimensionless_spin_parameter*dimensionless_spin_parameter);
    }



    /* Step function */
    MAGIK_DEVICE_HOST static geodesic_step_values_t kerr_geodesic_eq_rhs(const geodesic_step_values_t y0, const float dimensionless_spin_parameter)
    {
        float x = y0.four_position.x;
        float y = y0.four_position.y;
        float z = y0.four_position.z;

        float pt = y0.four_momentum.t;
        float px = y0.four_momentum.x;
        float py = y0.four_momentum.y;
        float pz = y0.four_momentum.z;

        float a_sq = dimensionless_spin_parameter * dimensionless_spin_parameter;
        float y_sq = y * y;

        float w_sq = (x*x + y*y + z*z) - a_sq;
        float sigma = std::sqrt(4.0f * a_sq * y_sq + w_sq * w_sq);
        float r = std::sqrt(0.5f * (w_sq + sigma));
        float r_sq = r * r;
        float r_cu = r_sq * r;
        float r_quad = r_sq * r_sq;
        float r_six = r_cu * r_cu;

        float inv_r = 1.0f / r;
        float inv_rsq = inv_r * inv_r;
        float inv_sigma = 1.0f / sigma;
        float scale_xz = 0.5f * inv_r * (1.0f + w_sq * inv_sigma);
        float scale_y = 0.5f * inv_r * (1.0f + (w_sq + 2.0f * a_sq) * inv_sigma);
        vec4f drdq{x * scale_xz, y * scale_y, z * scale_xz, 0.0f};

        float d = r_sq + a_sq;
        float inv_d = 1.0f / d;
        float inv_dsq = inv_d * inv_d;
        float kx_num = r * x - dimensionless_spin_parameter * z;
        float kz_num = r * z + dimensionless_spin_parameter * x;
        float kx = kx_num * inv_d;
        float kz = kz_num * inv_d;
        float ky = y * inv_r;

        float f_den = r_quad + a_sq * y_sq;
        float inv_f_den_sq = 1.0f / (f_den * f_den);
        float f_ = 2.0f * r_cu / f_den;

        float dfdq_scale = 2.0f * (3.0f * a_sq * r_sq * y_sq - r_six) * inv_f_den_sq;
        vec4f dfdq_{ dfdq_scale * drdq.x, dfdq_scale * drdq.y - 4.0f * a_sq * r_cu * y * inv_f_den_sq, dfdq_scale * drdq.z, 0.0f };

        float dkx_dx = ((x * drdq.x + r) * d - 2.0f * r * drdq.x * kx_num) * inv_dsq;
        float dkx_dy = ((x * drdq.y) * d - 2.0f * r * drdq.y * kx_num) * inv_dsq;
        float dkx_dz = ((x * drdq.z - dimensionless_spin_parameter) * d - 2.0f * r * drdq.z * kx_num) * inv_dsq;

        float dky_dx = -y * drdq.x * inv_rsq;
        float dky_dy = (r - y * drdq.y) * inv_rsq;
        float dky_dz = -y * drdq.z * inv_rsq;

        float dkz_dx = ((dimensionless_spin_parameter + z * drdq.x) * d - 2.0f * r * drdq.x * kz_num) * inv_dsq;
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
    using kerr_metric = metric<e_magik_spacetime_metric_types::KERR>;

    template<> struct kerr_metric::params_t
    {
        bool time_reversed;
        float mass_parameter;
        float dimensionless_spin_parameter;
        float event_horizon_scalar;

        float h_max;
        float abs_tol;
        float rel_tol;
        uint32_t n_max;
    };

    template<> inline kerr_metric::params_t kerr_metric::make_params(magik_render_manager* manager, bool time_reversed)
    {
        return {    time_reversed,
                    manager->stage.relativity_settings.kerr_mass_parameter, 
                    time_reversed ? -manager->stage.relativity_settings.kerr_dimensionless_spin_parameter : manager->stage.relativity_settings.kerr_dimensionless_spin_parameter, 
                    manager->stage.relativity_settings.kerr_event_horizon_scalar, 
                    1000.0f, 
                    manager->stage.relativity_settings.integrator_absolute_error_tolerance, 
                    manager->stage.relativity_settings.integrator_relative_error_tolerance, 
                    manager->stage.relativity_settings.n_integrator_max_substep}; 
    }

    template<> inline kerr_metric::params_t kerr_metric::make_params(magik_trace_geodesic_metric_parameters_t metric_parameters, magik_trace_geodesic_integrator_parameters_t integrator_parameters, bool time_reversed)
    {
        return {    time_reversed,
                    metric_parameters.kerr_mass, 
                    time_reversed ? -metric_parameters.kerr_spin : metric_parameters.kerr_spin, 
                    metric_parameters.event_horizon_scalar, 
                    1000.0f, 
                    integrator_parameters.integrator_absolute_error_tolerance, 
                    integrator_parameters.integrator_relative_error_tolerance, 
                    integrator_parameters.n_integrator_max_substep}; 
    }

    template<> MAGIK_DEVICE_HOST float kerr_metric::initial_h_step()
    {
        return 1.0f;
    }

    template<> MAGIK_DEVICE_HOST float kerr_metric::length_scale(params_t p)
    {
        return magik::gravitational_constant * p.mass_parameter / (magik::speed_of_light*magik::speed_of_light);
    }

    template<> MAGIK_DEVICE_HOST geodesic_step_values_t kerr_metric::solve_step(geodesic_step_values_t y0, params_t p, float* h_step, float* h_taken)
    {
        return solve_runge_kutta_fehlberg_45_step(kerr_geodesic_eq_rhs, y0, h_step, h_taken, p.h_max, p.n_max, p.abs_tol, p.rel_tol, p.dimensionless_spin_parameter);
    }

    template<> MAGIK_DEVICE_HOST geodesic_step_values_t kerr_metric::geodesic_rhs(geodesic_step_values_t y0, params_t p)
    {
        return kerr_geodesic_eq_rhs(y0, p.dimensionless_spin_parameter);
    }

    template<> MAGIK_DEVICE_HOST bool kerr_metric::in_domain(vec4f dimensionless_four_position, params_t p)
    {
        if(fabsf(p.dimensionless_spin_parameter) > 1.0f) return false;
        float r = kerr_schild_r(dimensionless_four_position.x, dimensionless_four_position.y, dimensionless_four_position.z, p.dimensionless_spin_parameter);
        if(((1.0f + sqrtf(1.0f - p.dimensionless_spin_parameter*p.dimensionless_spin_parameter)) * p.event_horizon_scalar) < r) return false;
        return true;
    }

    template<> MAGIK_DEVICE_HOST sym4_t kerr_metric::compute_g(vec4f dimensionless_four_position, params_t p)
    {
        const float a  = p.dimensionless_spin_parameter;
        const float r  = kerr_schild_r(dimensionless_four_position.x, dimensionless_four_position.y, dimensionless_four_position.z, a);
        const float f  = kerr_schild_f(dimensionless_four_position.y, r, a);
        const float kx = kerr_schild_k_x(dimensionless_four_position.x, dimensionless_four_position.z, r, a);
        const float ky = kerr_schild_k_y(dimensionless_four_position.y, r);
        const float kz = kerr_schild_k_z(dimensionless_four_position.x, dimensionless_four_position.z, r, a);

        return { -1.0f + f, f * kx, f * ky, f * kz,
                  1.0f + f * kx * kx, f * kx * ky, f * kx * kz,
                  1.0f + f * ky * ky, f * ky * kz,
                  1.0f + f * kz * kz };
    }

    template<> MAGIK_DEVICE_HOST sym4_t kerr_metric::compute_inv_g(vec4f dimensionless_four_position, params_t p)
    {
        const float a  = p.dimensionless_spin_parameter;
        const float r  = kerr_schild_r(dimensionless_four_position.x, dimensionless_four_position.y, dimensionless_four_position.z, a);
        const float f  = kerr_schild_f(dimensionless_four_position.y, r, a);
        const float kx = kerr_schild_k_x(dimensionless_four_position.x, dimensionless_four_position.z, r, a);
        const float ky = kerr_schild_k_y(dimensionless_four_position.y, r);
        const float kz = kerr_schild_k_z(dimensionless_four_position.x, dimensionless_four_position.z, r, a);

        return { -1.0f - f, f * kx, f * ky, f * kz,
                1.0f - f * kx * kx, -f * kx * ky, -f * kx * kz,
                1.0f - f * ky * ky, -f * ky * kz,
                1.0f - f * kz * kz };
    }

    template<> MAGIK_DEVICE_HOST vec4f kerr_metric::reference_observer(vec4f dimensionless_four_position, params_t p)
    {
        float r = kerr_schild_r(dimensionless_four_position.x, dimensionless_four_position.y, dimensionless_four_position.z, p.dimensionless_spin_parameter);
        float r_sq = r * r;
        float a_sq = p.dimensionless_spin_parameter * p.dimensionless_spin_parameter;

        float cos_theta = dimensionless_four_position.y/r;
        float sin2_theta = 1.0f - cos_theta*cos_theta;
        float sigma = r_sq + a_sq*cos_theta*cos_theta;
        float delta = r_sq - 2.0f*r + a_sq;
        float Lambda = (r_sq + a_sq)*(r_sq + a_sq) - a_sq*delta*sin2_theta;
        float u_t = sqrtf(Lambda/(delta*sigma));
        float u_phi = 2.0f*p.dimensionless_spin_parameter*r/sqrtf(Lambda*delta*sigma);

        float u_x = dimensionless_four_position.z*u_phi;
        float u_y = 0.0f;
        float u_z = -dimensionless_four_position.x*u_phi;

        return vec4f{u_x, u_y, u_z, u_t};
    }
}
