#pragma once

#include "relativity_utilities.cuh"

namespace magik
{
    /* Metric - Components */
    MAGIK_DEVICE_HOST static float minkowski_g_tt()
    {
        return -1.0f;
    }

    MAGIK_DEVICE_HOST static float minkowski_g_xxyyzz()
    {
        return 1.0f;
    }

    /* Metric - Inverse components */
    MAGIK_DEVICE_HOST static float minkowski_g_inv_tt()
    {
        return -1.0f;
    }

    MAGIK_DEVICE_HOST static float minkowski_g_inv_xxyyzz()
    {
        return 1.0f;
    }

    /* Metric - Index */
    MAGIK_DEVICE_HOST static vec4f minkowski_lower_index(vec4f contravariant_vector)
    {
        vec4f output;
        output.t = minkowski_g_tt()*contravariant_vector.t;
        output.x = minkowski_g_xxyyzz()*contravariant_vector.x;
        output.y = minkowski_g_xxyyzz()*contravariant_vector.y;
        output.z = minkowski_g_xxyyzz()*contravariant_vector.z;
        return output;
    }

    MAGIK_DEVICE_HOST static vec4f minkowski_raise_index(vec4f covariant_vector)
    {
        vec4f output;
        output.t = minkowski_g_inv_tt()*covariant_vector.t;
        output.x = minkowski_g_inv_xxyyzz()*covariant_vector.x;
        output.y = minkowski_g_inv_xxyyzz()*covariant_vector.y;
        output.z = minkowski_g_inv_xxyyzz()*covariant_vector.z;
        return output;
    }



    /* Rest frame to global frame */
    MAGIK_DEVICE_HOST static float minkowski_inner_product_contravariant(vec4f u_contravariant, vec4f v_contravariant)
    {
        return minkowski_g_tt()*u_contravariant.t*v_contravariant.t \
             + minkowski_g_xxyyzz()*u_contravariant.x*v_contravariant.x \
             + minkowski_g_xxyyzz()*u_contravariant.y*v_contravariant.y \
             + minkowski_g_xxyyzz()*u_contravariant.z*v_contravariant.z;
    }

    MAGIK_DEVICE_HOST static float minkowski_inner_product_covariant(vec4f u_covariant, vec4f v_covariant)
    {
        return minkowski_g_inv_tt()*u_covariant.t*v_covariant.t \
             + minkowski_g_inv_xxyyzz()*u_covariant.x*v_covariant.x \
             + minkowski_g_inv_xxyyzz()*u_covariant.y*v_covariant.y \
             + minkowski_g_inv_xxyyzz()*u_covariant.z*v_covariant.z;
    }
    
    MAGIK_DEVICE_HOST static vec4f minkowski_observer_rest_frame_to_global(contravariant_seed_vectors_t seed_vectors, vec3f dimensionless_spatial_vector, vec4f dimensionless_observer_four_velocity, float squared_norm)
    {
        vec4f four_momentum = vec4f{dimensionless_spatial_vector.x, dimensionless_spatial_vector.y, dimensionless_spatial_vector.z, compute_local_timelike_component(dimensionless_spatial_vector, squared_norm)};
        
        vec4f e_t = dimensionless_observer_four_velocity;
        
        vec4f e_z = seed_vectors.Z + minkowski_inner_product_contravariant(seed_vectors.Z, e_t)*e_t;
        e_z = e_z / sqrtf(minkowski_inner_product_contravariant(e_z, e_z));
            
        vec4f e_x = seed_vectors.X + minkowski_inner_product_contravariant(seed_vectors.X, e_t)*e_t \
                                   - minkowski_inner_product_contravariant(seed_vectors.X, e_z)*e_z;
        e_x = e_x / sqrtf(minkowski_inner_product_contravariant(e_x, e_x));
            
        vec4f e_y = seed_vectors.Y + minkowski_inner_product_contravariant(seed_vectors.Y, e_t)*e_t \
                                   - minkowski_inner_product_contravariant(seed_vectors.Y, e_z)*e_z \
                                   - minkowski_inner_product_contravariant(seed_vectors.Y, e_x)*e_x;
        e_y = e_y / sqrtf(minkowski_inner_product_contravariant(e_y, e_y));
            
        vec4f result;
        result.t = e_t.t*four_momentum.t + e_x.t*four_momentum.x + e_y.t*four_momentum.y + e_z.t*four_momentum.z;
        result.x = e_t.x*four_momentum.t + e_x.x*four_momentum.x + e_y.x*four_momentum.y + e_z.x*four_momentum.z;
        result.y = e_t.y*four_momentum.t + e_x.y*four_momentum.x + e_y.y*four_momentum.y + e_z.y*four_momentum.z;
        result.z = e_t.z*four_momentum.t + e_x.z*four_momentum.x + e_y.z*four_momentum.y + e_z.z*four_momentum.z;
        return result;
    }



    /* Rest frame velocity */
    MAGIK_DEVICE_HOST static float minkowski_compute_timelike_component_contravariant(vec3f dimensionless_observer_three_vector, float squard_norm)
    {
        float A = minkowski_g_tt();
        float C = minkowski_g_xxyyzz()*dimensionless_observer_three_vector.x*dimensionless_observer_three_vector.x \
                + minkowski_g_xxyyzz()*dimensionless_observer_three_vector.y*dimensionless_observer_three_vector.y \
                + minkowski_g_xxyyzz()*dimensionless_observer_three_vector.z*dimensionless_observer_three_vector.z \
                - squard_norm;

        return (-sqrtf(-4.0f*A*C))/(2.0f*A);
    }

    MAGIK_DEVICE_HOST static float minkowski_compute_timelike_component_covariant(vec3f dimensionless_observer_three_vector, float squard_norm)
    { 
        float A = minkowski_g_inv_tt();
        float C = minkowski_g_inv_xxyyzz()*dimensionless_observer_three_vector.x*dimensionless_observer_three_vector.x \
                + minkowski_g_inv_xxyyzz()*dimensionless_observer_three_vector.y*dimensionless_observer_three_vector.y \
                + minkowski_g_inv_xxyyzz()*dimensionless_observer_three_vector.z*dimensionless_observer_three_vector.z \
                - squard_norm;

        return (-sqrtf(-4.0f*A*C))/(2.0f*A);
    }

    MAGIK_DEVICE_HOST static vec4f minkowski_object_velocity_from_ZAMO_to_global(contravariant_seed_vectors_t seed_vectors, vec3f dimensionless_three_velocity)
    {
        float squared_norm = -1.0f;
        vec4f ZAMO_four_velocity = vec4f{0.0f, 0.0f, 0.0f, 1.0f};
        return minkowski_observer_rest_frame_to_global(seed_vectors, dimensionless_three_velocity, ZAMO_four_velocity, squared_norm);
    }



    /* Global to rest frame */
    MAGIK_DEVICE_HOST static vec4f minkowski_global_to_observer_rest_frame(contravariant_seed_vectors_t seed_vectors, vec4f dimensionless_four_vector, vec4f dimensionless_observer_four_velocity)
    {
        vec4f covariant_seed_vectors_x = minkowski_lower_index(seed_vectors.X);
        vec4f covariant_seed_vectors_y = minkowski_lower_index(seed_vectors.Y);
        vec4f covariant_seed_vectors_z = minkowski_lower_index(seed_vectors.Z);

        vec4f e_t = -minkowski_lower_index(dimensionless_observer_four_velocity);

        vec4f e_z = covariant_seed_vectors_z + minkowski_inner_product_covariant(covariant_seed_vectors_z, e_t)*e_t;
        e_z = e_z / sqrtf(minkowski_inner_product_covariant(e_z, e_z));

        vec4f e_x = covariant_seed_vectors_x + minkowski_inner_product_covariant(covariant_seed_vectors_x, e_t)*e_t \
        - minkowski_inner_product_covariant(covariant_seed_vectors_x, e_z)*e_z;
        e_x = e_x / sqrtf(minkowski_inner_product_covariant(e_x, e_x));

        vec4f e_y = covariant_seed_vectors_y + minkowski_inner_product_covariant(covariant_seed_vectors_y, e_t)*e_t \
        - minkowski_inner_product_covariant(covariant_seed_vectors_y, e_z)*e_z \
        - minkowski_inner_product_covariant(covariant_seed_vectors_y, e_x)*e_x;
        e_y = e_y / sqrtf(minkowski_inner_product_covariant(e_y, e_y));

        vec4f result;
        result.t = e_t.t*dimensionless_four_vector.t + e_t.x*dimensionless_four_vector.x + e_t.y*dimensionless_four_vector.y + e_t.z*dimensionless_four_vector.z;
        result.x = e_x.t*dimensionless_four_vector.t + e_x.x*dimensionless_four_vector.x + e_x.y*dimensionless_four_vector.y + e_x.z*dimensionless_four_vector.z;
        result.y = e_y.t*dimensionless_four_vector.t + e_y.x*dimensionless_four_vector.x + e_y.y*dimensionless_four_vector.y + e_y.z*dimensionless_four_vector.z;
        result.z = e_z.t*dimensionless_four_vector.t + e_z.x*dimensionless_four_vector.x + e_z.y*dimensionless_four_vector.y + e_z.z*dimensionless_four_vector.z;
        return result;
    }



    /* Step function */
    MAGIK_DEVICE_HOST static geodesic_step_values minkowski_geodesic_eq_rhs(geodesic_step_values y0)
    {
        vec4f d_four_momentum = vec4f{0.0f, 0.0f, 0.0f, 0.0f};
        vec4f d_four_position = minkowski_raise_index(y0.four_momentum);
        return geodesic_step_values{d_four_position, d_four_momentum};
    }



    /* Specialization */
    using minkowski_metric = metric<e_magik_spacetime_metric_types::MINKOWSKI>;

    template<> struct minkowski_metric::params_t 
    { 

    };

    template<> inline MAGIK_DEVICE_HOST float minkowski_metric::initial_h_step()
    {
        return 1000.0f;
    }

    template<> inline minkowski_metric::params_t minkowski_metric::make_params(magik_render_manager* managerp)
    {
        return {};
    }

    template<> inline MAGIK_DEVICE_HOST float minkowski_metric::length_scale(params_t p)
    {
        return 1.0f;
    }

    template<> inline MAGIK_DEVICE_HOST geodesic_step_values minkowski_metric::solve_step(geodesic_step_values y0, params_t p, float* h_step)
    {
        return solve_explicit_euler_step(minkowski_geodesic_eq_rhs, y0, *h_step);
    }

    template<> inline MAGIK_DEVICE_HOST geodesic_step_values minkowski_metric::geodesic_rhs(geodesic_step_values y0, params_t p)
    {
        return minkowski_geodesic_eq_rhs(y0);
    }

    template<> inline MAGIK_DEVICE_HOST bool minkowski_metric::in_domain(vec4f dimensionless_four_position, params_t p)
    {
        return false;
    }

    template<> inline MAGIK_DEVICE_HOST float minkowski_metric::contravariant_timelike_component(vec4f dimensionless_four_position, vec3f dimensionless_observer_three_vector, float squared_norm, params_t p)
    {
        return minkowski_compute_timelike_component_contravariant(dimensionless_observer_three_vector, squared_norm);
    }

    template<> inline MAGIK_DEVICE_HOST vec4f minkowski_metric::raise_index(vec4f dimensionless_four_position, vec4f covariant_vector, params_t p)
    {
        return minkowski_raise_index(covariant_vector);
    }

    template<> inline MAGIK_DEVICE_HOST vec4f minkowski_metric::rest_frame_four_velocity(vec4f dimensionless_four_position, contravariant_seed_vectors_t seed_vectors, vec3f dimensionless_three_velocity, params_t p)
    {
        return minkowski_object_velocity_from_ZAMO_to_global(seed_vectors, dimensionless_three_velocity);
    }

    template<> inline MAGIK_DEVICE_HOST vec4f minkowski_metric::global_to_observer_rest_frame(vec4f dimensionless_four_position, contravariant_seed_vectors_t seed_vectors, vec4f dimensionless_four_vector, vec4f dimensionless_observer_four_velocity, params_t p)
    {
        return minkowski_global_to_observer_rest_frame(seed_vectors, dimensionless_four_vector, dimensionless_observer_four_velocity);
    }

    template<> inline MAGIK_DEVICE_HOST vec4f minkowski_metric::rest_frame_direction_to_global_four_momentum(vec4f dimensionless_four_position, contravariant_seed_vectors_t seed_vectors, vec3f dimensionless_spatial_vector, vec4f dimensionless_observer_four_velocity, float squared_norm, params_t p)
    {
        vec4f vector = minkowski_observer_rest_frame_to_global(seed_vectors, dimensionless_spatial_vector, dimensionless_observer_four_velocity, squared_norm);
        return minkowski_raise_index(vector);
    }
}
