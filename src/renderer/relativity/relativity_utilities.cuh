#pragma once

#include "magik.h"
#include "cuda_host_device_utilities.h"
#include "internal_math.h"
#include <cuda_runtime.h>

namespace magik
{
    struct geodesic_step_values_t
    {
        vec4f four_position{};
        vec4f four_momentum{};

        MAGIK_DEVICE_HOST float compute_rms_error(geodesic_step_values_t error, geodesic_step_values_t y0, geodesic_step_values_t y1, float abs_tol, float rel_tol)
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

    MAGIK_DEVICE_HOST static geodesic_step_values_t operator+(geodesic_step_values_t v0, geodesic_step_values_t v1)
	{
		return geodesic_step_values_t{ v0.four_position + v1.four_position, v0.four_momentum + v1.four_momentum };
	}

    MAGIK_DEVICE_HOST static geodesic_step_values_t operator-(geodesic_step_values_t v0, geodesic_step_values_t v1)
	{
		return geodesic_step_values_t{ v0.four_position - v1.four_position, v0.four_momentum - v1.four_momentum };
	}

    MAGIK_DEVICE_HOST static geodesic_step_values_t operator*(float scalar, geodesic_step_values_t v0)
	{
		return geodesic_step_values_t{ scalar * v0.four_position, scalar * v0.four_momentum };
	}

    MAGIK_DEVICE_HOST static geodesic_step_values_t operator*(geodesic_step_values_t v0, float scalar)
	{
		return geodesic_step_values_t{ scalar * v0.four_position, scalar * v0.four_momentum };
	}

    MAGIK_DEVICE_HOST static geodesic_step_values_t operator/(geodesic_step_values_t v0, float scalar)
	{
		return geodesic_step_values_t{ v0.four_position / scalar, v0.four_momentum / scalar };
	}

    MAGIK_DEVICE_HOST static float compute_local_timelike_component(vec3f vector, float input_vector_norm)
    {
        return sqrtf(vector.length2() - input_vector_norm);
    }

    MAGIK_DEVICE_HOST static float compute_redshift_factor(float initial_four_vector_contraction, vec4f four_velocity, vec4f four_momentum)
    {
        float z = initial_four_vector_contraction / vector_dot_product(four_velocity, four_momentum);
        if(isnan(z) || isinf(z)) z = 1e-10f;
        return z;
    }

    MAGIK_DEVICE_HOST static vec4f convert_si_position_to_dimensionless_coordinate_system(vec4f spatial_si_coordinates, float global_time, float length_scale, float time_scale)
    {
        return vec4f{spatial_si_coordinates.x / length_scale, spatial_si_coordinates.y / length_scale, spatial_si_coordinates.z / length_scale, global_time / time_scale};
    }

    struct contravariant_seed_vectors_t
    {
        vec4f X{1.0f, 0.0f, 0.0f, 0.0f};
        vec4f Y{0.0f, 1.0f, 0.0f, 0.0f};
        vec4f Z{0.0f, 0.0f, 1.0f, 0.0f};
    };

    struct sym4_t
    {
        float tt, tx, ty, tz;
        float xx, xy, xz;
        float yy, yz;
        float zz;
    };

    struct tetrad_t
    {
        vec4f t;
        vec4f x;
        vec4f y;
        vec4f z;
    };

    template<e_magik_spacetime_metric_types T_metric> struct metric
    {
        struct params_t;

        static params_t make_params(magik_render_manager* manager, bool time_reversed);

        static params_t make_params(magik_trace_geodesic_metric_parameters_t metric_parameters, magik_trace_geodesic_integrator_parameters_t integrator_parameters, bool time_reversed);

        static MAGIK_DEVICE_HOST float initial_h_step();

        static MAGIK_DEVICE_HOST float length_scale(params_t p);

        static MAGIK_DEVICE_HOST geodesic_step_values_t solve_step(geodesic_step_values_t y0, params_t p, float* h_step, float* h_taken);

        static MAGIK_DEVICE_HOST geodesic_step_values_t geodesic_rhs(geodesic_step_values_t y0, params_t p);

        static MAGIK_DEVICE_HOST bool in_domain(vec4f dimensionless_four_position, params_t p);

        static MAGIK_DEVICE_HOST sym4_t compute_g(vec4f dimensionless_four_position, params_t p); // -> g

        static MAGIK_DEVICE_HOST sym4_t compute_inv_g(vec4f dimensionless_four_position, params_t p); // g_inv

        static MAGIK_DEVICE_HOST vec4f reference_observer(vec4f dimensionless_four_position, params_t p);
    };

    static MAGIK_DEVICE_HOST float inner_product(const sym4_t& metric_tensor, vec4f u, vec4f v)
    {
        // T = g -> contravariant | T = g_inv -> covariant
        return { metric_tensor.tt * u.t * v.t
               + metric_tensor.tx * (u.t * v.x + u.x * v.t) + metric_tensor.ty * (u.t * v.y + u.y * v.t) + metric_tensor.tz * (u.t * v.z + u.z * v.t)
               + metric_tensor.xx * u.x * v.x + metric_tensor.xy * (u.x * v.y + u.y * v.x) + metric_tensor.xz * (u.x * v.z + u.z * v.x)
               + metric_tensor.yy * u.y * v.y + metric_tensor.yz * (u.y * v.z + u.z * v.y)
               + metric_tensor.zz * u.z * v.z };
    }

    static MAGIK_DEVICE_HOST vec4f contract(const sym4_t& metric_tensor, vec4f u)
    {
        // T = g -> lower index | T = g_inv -> raise index
        return { metric_tensor.tx * u.t + metric_tensor.xx * u.x + metric_tensor.xy * u.y + metric_tensor.xz * u.z,
                 metric_tensor.ty * u.t + metric_tensor.xy * u.x + metric_tensor.yy * u.y + metric_tensor.yz * u.z,
                 metric_tensor.tz * u.t + metric_tensor.xz * u.x + metric_tensor.yz * u.y + metric_tensor.zz * u.z,
                 metric_tensor.tt * u.t + metric_tensor.tx * u.x + metric_tensor.ty * u.y + metric_tensor.tz * u.z };
    }

    static MAGIK_DEVICE_HOST tetrad_t build_tetrad(const sym4_t& g, contravariant_seed_vectors_t seed_vectors, vec4f u)
    {
        tetrad_t e;
        e.t = u;

        e.z = seed_vectors.Z + inner_product(g, seed_vectors.Z, u) * u;
        e.z = e.z / sqrtf(inner_product(g, e.z, e.z));

        e.x = seed_vectors.X + inner_product(g, seed_vectors.X, u) * u - inner_product(g, seed_vectors.X, e.z) * e.z;
        e.x = e.x / sqrtf(inner_product(g, e.x, e.x));

        e.y = seed_vectors.Y + inner_product(g, seed_vectors.Y, u) * u - inner_product(g, seed_vectors.Y, e.z) * e.z - inner_product(g, seed_vectors.Y, e.x) * e.x;
        e.y = e.y / sqrtf(inner_product(g, e.y, e.y));

        return e;
    }

    static MAGIK_DEVICE_HOST vec4f local_to_global(const tetrad_t& e, vec4f local)
    {
        return e.t * local.t + e.x * local.x + e.y * local.y + e.z * local.z;
    }

    template<e_magik_spacetime_metric_types T_metric> static MAGIK_DEVICE_HOST vec4f rest_frame_four_velocity(vec4f dimensionless_four_position, contravariant_seed_vectors_t seed_vectors, vec3f dimensionless_three_velocity, typename metric<T_metric>::params_t p)
    {
        const sym4_t g = metric<T_metric>::compute_g(dimensionless_four_position, p);
        const vec4f u_ref = metric<T_metric>::reference_observer(dimensionless_four_position, p);
        const tetrad_t e = build_tetrad(g, seed_vectors, u_ref);

        vec3f w = p.time_reversed ? -dimensionless_three_velocity : dimensionless_three_velocity;
        vec4f local{w.x, w.y, w.z, compute_local_timelike_component(w, -1.0f)};

        return local_to_global(e, local);
    }

    template<e_magik_spacetime_metric_types T_metric> static MAGIK_DEVICE_HOST vec4f global_to_observer_rest_frame(vec4f dimensionless_four_position, contravariant_seed_vectors_t seed_vectors, vec4f dimensionless_four_vector, vec4f dimensionless_observer_four_velocity, typename metric<T_metric>::params_t p)
    {
        const sym4_t g = metric<T_metric>::compute_g(dimensionless_four_position, p);
        const tetrad_t e = build_tetrad(g, seed_vectors, dimensionless_observer_four_velocity);

        return vec4f{ inner_product(g, e.x, dimensionless_four_vector),
                      inner_product(g, e.y, dimensionless_four_vector),
                      inner_product(g, e.z, dimensionless_four_vector),
                     -inner_product(g, e.t, dimensionless_four_vector) };
    }

    template<e_magik_spacetime_metric_types T_metric> static MAGIK_DEVICE_HOST vec4f rest_frame_direction_to_global_four_momentum(vec4f dimensionless_four_position, contravariant_seed_vectors_t seed_vectors, vec3f dimensionless_spatial_vector, vec4f dimensionless_observer_four_velocity, float squared_norm, typename metric<T_metric>::params_t p)
    {
        const sym4_t g = metric<T_metric>::compute_g(dimensionless_four_position, p);
        const tetrad_t e = build_tetrad(g, seed_vectors, dimensionless_observer_four_velocity);

        vec4f local{dimensionless_spatial_vector.x, dimensionless_spatial_vector.y, dimensionless_spatial_vector.z, compute_local_timelike_component(dimensionless_spatial_vector, squared_norm)};
        vec4f p_up = local_to_global(e, local);

        return contract(g, p_up);
    }

    template<e_magik_spacetime_metric_types... Ts> struct metric_list {};

    using supported_metrics = metric_list
    <
    e_magik_spacetime_metric_types::MINKOWSKI,
    e_magik_spacetime_metric_types::SCHWARZSCHILD,
    e_magik_spacetime_metric_types::KERR
    >;

    template<class F, e_magik_spacetime_metric_types... Ts> bool match_metric(e_magik_spacetime_metric_types type, F&& f, metric_list<Ts...>)
    {
        return ((type == Ts ? (f(std::integral_constant<e_magik_spacetime_metric_types, Ts>{}), true) : false) || ...);
    }

    template<class F> bool dispatch_metric(e_magik_spacetime_metric_types type, F&& f)
    {
        return match_metric(type, std::forward<F>(f), supported_metrics{});
    }
}
