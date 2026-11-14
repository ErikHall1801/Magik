#pragma once

#include "magik.h"
#include "cuda_host_device_utilities.h"
#include "internal_math.h"
#include <cstdint>
#include <curand_kernel.h>
#include "curand.h"

#include "relativity_utilities.cuh"
#include "metric_minkowski.cuh"
#include "metric_schwarzschild.cuh"
#include "metric_kerr.cuh"

namespace magik
{
    typedef enum e_magik_bxdf_result_types
    {
        REFLECTED = 0,
        ABSORBED = 1
    } e_magik_bxdf_result_types;

    struct bxdf_result
    {
        e_magik_bxdf_result_types type = ABSORBED;
        float spectral_radiance = 0.0f;
        float monte_carlo_weight_adjustment = 0.0f;
        vec3f outgoing_rest_frame_direction;
    };

    struct bxdf_velocity_context
    {
        float sensor_wavelength_nm;
        float length_scale;
        float initial_four_vector_contraction;
        float affine_parameter;
        float delta_affine_parameter;
        float monte_carlo_weight;
        vec4f current_dimensionless_four_position;
        vec4f current_dimensionless_four_momentum;
        vec4f next_dimensionless_four_position;
        vec4f next_dimensionless_four_momentum;
        vec4f momentum_derivative_start;
        vec4f momentum_derivative_end;
        vec3f global_frame_incoming_direction;
        vec3f si_position;
        vec3f global_frame_geometric_normal;
        vec3f global_frame_facing_normal;

        curandState_t* random_device;
    };

    static __device__ __inline__ bxdf_velocity_context generate_velocity_context(float sensor_wavelength_nm, float length_scale, float initial_four_vector_contraction, float affine_parameter, float delta_affine_parameter, float monte_carlo_weight, vec4f current_dimensionless_four_position, vec4f current_dimensionless_four_momentum, vec4f next_dimensionless_four_position, vec4f next_dimensionless_four_momentum, vec4f momentum_derivative_start, vec4f momentum_derivative_end, vec3f global_frame_geometric_normal, curandState_t* random_device)
    {
        bxdf_velocity_context result;
        result.sensor_wavelength_nm = sensor_wavelength_nm;
        result.length_scale = length_scale;
        result.initial_four_vector_contraction = initial_four_vector_contraction;
        result.affine_parameter = affine_parameter;
        result.delta_affine_parameter = delta_affine_parameter;
        result.monte_carlo_weight = monte_carlo_weight;
        result.current_dimensionless_four_position = current_dimensionless_four_position;
        result.current_dimensionless_four_momentum = current_dimensionless_four_momentum;
        result.next_dimensionless_four_position = next_dimensionless_four_position;
        result.next_dimensionless_four_momentum = next_dimensionless_four_momentum;
        result.momentum_derivative_start = momentum_derivative_start;
        result.momentum_derivative_end = momentum_derivative_end;
        result.global_frame_incoming_direction = vec3f{next_dimensionless_four_position.x - current_dimensionless_four_position.x, next_dimensionless_four_position.y - current_dimensionless_four_position.y, next_dimensionless_four_position.z - current_dimensionless_four_position.z}.norm();
        result.si_position = vec3f{next_dimensionless_four_position.x, next_dimensionless_four_position.y, next_dimensionless_four_position.z}*length_scale;
        result.global_frame_geometric_normal = global_frame_geometric_normal;
        result.global_frame_facing_normal = (vector_dot_product(global_frame_geometric_normal, result.global_frame_incoming_direction)) > 0.0f ? -global_frame_geometric_normal : global_frame_geometric_normal;

        result.random_device = random_device;
        return result;
    }

    struct bxdf_material_context : bxdf_velocity_context
    {
        vec3f dimensionless_three_velocity;
        vec4f dimensionless_four_velocity;
        vec4f next_dimensionless_rest_frame_four_momentum;
        vec3f rest_frame_incoming_direction;
        float redshift_factor;
        float redshifted_wavelength_nm;
        vec3f rest_frame_geometric_normal;
        vec3f rest_frame_facing_normal;
    };

    template<e_magik_spacetime_metric_types T> static __device__ __inline__ bxdf_material_context generate_material_context(typename metric<T>::params_t metric_parameters, bxdf_velocity_context v_context, vec3f dimensionless_three_velocity)
    {
        bxdf_material_context result;
        static_cast<bxdf_velocity_context&>(result) = v_context;
        result.dimensionless_three_velocity = dimensionless_three_velocity;
        result.dimensionless_four_velocity = rest_frame_four_velocity<T>(result.next_dimensionless_four_position, contravariant_seed_vectors_t{}, dimensionless_three_velocity, metric_parameters);

        vec4f next_four_momentum_contravariant = contract(metric<T>::compute_inv_g(v_context.next_dimensionless_four_position, metric_parameters), result.next_dimensionless_four_momentum);
        result.next_dimensionless_rest_frame_four_momentum = global_to_observer_rest_frame<T>(result.next_dimensionless_four_position, contravariant_seed_vectors_t{}, next_four_momentum_contravariant, result.dimensionless_four_velocity, metric_parameters);

        result.rest_frame_incoming_direction = vec3f{result.next_dimensionless_rest_frame_four_momentum.x, result.next_dimensionless_rest_frame_four_momentum.y, result.next_dimensionless_rest_frame_four_momentum.z}.norm();
        result.redshift_factor = compute_redshift_factor(result.initial_four_vector_contraction, result.dimensionless_four_velocity, result.next_dimensionless_four_momentum);
        result.redshifted_wavelength_nm = v_context.sensor_wavelength_nm * result.redshift_factor;

        vec4f geometric_normal_contravarient = contract(metric<T>::compute_inv_g(v_context.next_dimensionless_four_position, metric_parameters), vec4f{result.global_frame_geometric_normal.x, result.global_frame_geometric_normal.y, result.global_frame_geometric_normal.z, 0.0f});
        vec4f four_vector_rest_frame_geometric_normal = global_to_observer_rest_frame<T>(result.next_dimensionless_four_position, contravariant_seed_vectors_t{}, geometric_normal_contravarient, result.dimensionless_four_velocity, metric_parameters);
        result.rest_frame_geometric_normal = vec3f{four_vector_rest_frame_geometric_normal.x, four_vector_rest_frame_geometric_normal.y, four_vector_rest_frame_geometric_normal.z}.norm();

        result.rest_frame_facing_normal = vector_dot_product(result.rest_frame_geometric_normal, result.rest_frame_incoming_direction) > 0.0f ? -result.rest_frame_geometric_normal : result.rest_frame_geometric_normal;
        return result;
    }

    __device__ __inline__ static vec4f offset_geodesic(const vec4f x, const vec3f n)
    {
        /*
        CREDITS;
        https://github.com/Apress/ray-tracing-gems/blob/master/Ch_06_A_Fast_and_Robust_Method_for_Avoiding_Self-Intersection/offset_ray.cu
        To make the function transform the offset into the surface, simply negate the normal
        assuming the convention that the passed in normal always opposes the geodesics direction ! 
        */

        const float offset_scale = 4.0f;
        const float int_scale = 256.0f * offset_scale;
        const float float_scale = (1.0f / 65536.0f) * offset_scale;
        const float origin = 1.0f / 32.0f;

        int of_ix = int_scale*n.x;
        int of_iy = int_scale*n.y;
        int of_iz = int_scale*n.z;

        float p_ix = __int_as_float(__float_as_int(x.x) + ((x.x < 0) ? -of_ix : of_ix));
        float p_iy = __int_as_float(__float_as_int(x.y) + ((x.y < 0) ? -of_iy : of_iy));
        float p_iz = __int_as_float(__float_as_int(x.z) + ((x.z < 0) ? -of_iz : of_iz));

        return vec4f{   fabsf(x.x) < origin ? x.x+float_scale*n.x : p_ix,
                        fabsf(x.y) < origin ? x.y+float_scale*n.y : p_iy,
                        fabsf(x.z) < origin ? x.z+float_scale*n.z : p_iz,
                        x.t };
    }

    template<e_magik_spacetime_metric_types T> static __device__ __inline__ void apply_reflected(typename metric<T>::params_t metric_parameters, uint32_t ray_id, uint32_t* d_n_reflected, vec4f* d_current_four_position, vec4f* d_current_four_momentum, vec4f* d_next_four_position, vec4f* d_next_four_momentum, float* d_initial_four_vector_contraction, float* d_monte_carlo_weight, float redshift_factor, vec4f four_velocity, vec3f facing_global_frame_normal, bxdf_result result)
    {
        contravariant_seed_vectors_t seed_vectors;
        vec4f next_four_position = d_next_four_position[ray_id];

        vec4f outgoing_global_frame_four_momentum = rest_frame_direction_to_global_four_momentum<T>(next_four_position, seed_vectors, result.outgoing_rest_frame_direction, four_velocity, 0.0f, metric_parameters);
        vec4f offset_next_four_position = offset_geodesic(next_four_position, facing_global_frame_normal);

        d_initial_four_vector_contraction[ray_id] = vector_dot_product(four_velocity, outgoing_global_frame_four_momentum) * redshift_factor;
        d_current_four_position[ray_id] = offset_next_four_position;
        d_current_four_momentum[ray_id] = outgoing_global_frame_four_momentum;
        d_next_four_position[ray_id] = offset_next_four_position;
        d_next_four_momentum[ray_id] = outgoing_global_frame_four_momentum;
        d_monte_carlo_weight[ray_id] *= result.monte_carlo_weight_adjustment;
        d_n_reflected[ray_id]++;
    }

    template<e_magik_spacetime_metric_types T> static __device__ __inline__ void apply_absorbed(uint32_t ray_id, float* d_spectral_radiance, float* d_monte_carlo_weight, float redshift_factor, bxdf_result result)
    {
        float boosted_spectral_radiance = result.spectral_radiance * (redshift_factor*redshift_factor*redshift_factor*redshift_factor*redshift_factor);
        if(isnan(boosted_spectral_radiance) || isinf(boosted_spectral_radiance) || boosted_spectral_radiance < 0.0f) boosted_spectral_radiance = 0.0f;

        d_spectral_radiance[ray_id] = boosted_spectral_radiance;
        d_monte_carlo_weight[ray_id] *= result.monte_carlo_weight_adjustment;
    }

    template<e_magik_spacetime_metric_types T> static __device__ __inline__ void apply_bxdf_result(typename metric<T>::params_t metric_parameters, bxdf_result result, uint32_t ray_id, uint32_t* d_n_reflected, float* d_spectral_radiance, vec4f* d_current_four_position, vec4f* d_current_four_momentum, vec4f* d_next_four_position, vec4f* d_next_four_momentum, float* d_initial_four_vector_contraction, float* d_monte_carlo_weight, float redshift_factor, vec4f four_velocity, vec3f facing_global_frame_normal)
    {
        switch(result.type)
        {
            case REFLECTED:
            {
                apply_reflected<T>(metric_parameters, ray_id, d_n_reflected, d_current_four_position, d_current_four_momentum, d_next_four_position, d_next_four_momentum, d_initial_four_vector_contraction, d_monte_carlo_weight, redshift_factor, four_velocity, facing_global_frame_normal, result);
                break;
            }

            case ABSORBED:
            {
                apply_absorbed<T>(ray_id, d_spectral_radiance, d_monte_carlo_weight, redshift_factor, result);
                break;
            }
        }
    }
}
