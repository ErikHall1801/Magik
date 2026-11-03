#pragma once

#include "relativity_utilities.cuh"

namespace magik
{
    /* Metric - Components */
    MAGIK_DEVICE_HOST static constexpr float minkowski_g_tt()
    {
        return -1.0f;
    }

    MAGIK_DEVICE_HOST static constexpr float minkowski_g_xxyyzz()
    {
        return 1.0f;
    }

    /* Metric - Inverse components */
    MAGIK_DEVICE_HOST static constexpr float minkowski_g_inv_tt()
    {
        -1.0f;
    }

    MAGIK_DEVICE_HOST static constexpr float minkowski_g_inv_xxyyzz()
    {
        return 1.0f;
    }

    /* Metric - Index */
    MAGIK_DEVICE_HOST static constexpr vec4f minkowski_lower_index(vec4f contravariant_vector)
    {
        vec4f output;
        output.t = minkowski_g_tt()*contravariant_vector.t;
        output.x = minkowski_g_xxyyzz()*contravariant_vector.x;
        output.y = minkowski_g_xxyyzz()*contravariant_vector.y;
        output.z = minkowski_g_xxyyzz()*contravariant_vector.z;
        return output;
    }

    MAGIK_DEVICE_HOST static constexpr vec4f minkowski_raise_index(vec4f covariant_vector)
    {
        vec4f output;
        output.t = minkowski_g_inv_tt()*covariant_vector.t;
        output.x = minkowski_g_inv_xxyyzz()*covariant_vector.x;
        output.y = minkowski_g_inv_xxyyzz()*covariant_vector.y;
        output.z = minkowski_g_inv_xxyyzz()*covariant_vector.z;
        return output;
    }



    /* Rest frame to global frame */
    MAGIK_DEVICE_HOST static constexpr float minkowski_inner_product_contravariant(vec4f u_contravariant, vec4f v_contravariant)
    {
        return minkowski_g_tt()*u_contravariant.t*v_contravariant.t \
             + minkowski_g_xxyyzz()*u_contravariant.x*v_contravariant.x \
             + minkowski_g_xxyyzz()*u_contravariant.y*v_contravariant.y \
             + minkowski_g_xxyyzz()*u_contravariant.z*v_contravariant.z;
    }

    MAGIK_DEVICE_HOST static constexpr float minkowski_inner_product_covariant(vec4f u_covariant, vec4f v_covariant)
    {
        return minkowski_g_inv_tt()*u_covariant.t*v_covariant.t \
             + minkowski_g_inv_xxyyzz()*u_covariant.x*v_covariant.x \
             + minkowski_g_inv_xxyyzz()*u_covariant.y*v_covariant.y \
             + minkowski_g_inv_xxyyzz()*u_covariant.z*v_covariant.z;
    }

    struct minkowski_observer_rest_frame_to_global_t
    {
        vec4f contravariant_seed_vector_x{}; 
        vec4f contravariant_seed_vector_y{};
        vec4f contravariant_seed_vector_z{};
        vec3f dimensionless_spatial_vector{};
        vec4f dimensionless_observer_four_velocity{}; 
        float input_vector_norm{};
    };
    
    MAGIK_DEVICE_HOST static constexpr vec4f minkowski_observer_rest_frame_to_global(minkowski_observer_rest_frame_to_global_t args)
    {
        vec4f four_momentum = vec4f{args.dimensionless_spatial_vector.x, args.dimensionless_spatial_vector.y, args.dimensionless_spatial_vector.z, compute_metric_agnostic_local_timelike_component(args.dimensionless_spatial_vector, args.input_vector_norm)};
        
        vec4f e_t = args.dimensionless_observer_four_velocity;
        
        vec4f e_z = args.contravariant_seed_vector_z + minkowski_inner_product_contravariant(args.contravariant_seed_vector_z, e_t)*e_t;
        e_z = e_z / sqrtf(minkowski_inner_product_contravariant(e_z, e_z));
            
        vec4f e_x = args.contravariant_seed_vector_x + minkowski_inner_product_contravariant(args.contravariant_seed_vector_x, e_t)*e_t \
                                                     - minkowski_inner_product_contravariant(args.contravariant_seed_vector_x, e_z)*e_z;
        e_x = e_x / sqrtf(minkowski_inner_product_contravariant(e_x, e_x));
            
        vec4f e_y = args.contravariant_seed_vector_y + minkowski_inner_product_contravariant(args.contravariant_seed_vector_y, e_t)*e_t \
                                                     - minkowski_inner_product_contravariant(args.contravariant_seed_vector_y, e_z)*e_z \
                                                     - minkowski_inner_product_contravariant(args.contravariant_seed_vector_y, e_x)*e_x;
        e_y = e_y / sqrtf(minkowski_inner_product_contravariant(e_y, e_y));
            
        vec4f result;
        result.t = e_t.t*four_momentum.t + e_x.t*four_momentum.x + e_y.t*four_momentum.y + e_z.t*four_momentum.z;
        result.x = e_t.x*four_momentum.t + e_x.x*four_momentum.x + e_y.x*four_momentum.y + e_z.x*four_momentum.z;
        result.y = e_t.y*four_momentum.t + e_x.y*four_momentum.x + e_y.y*four_momentum.y + e_z.y*four_momentum.z;
        result.z = e_t.z*four_momentum.t + e_x.z*four_momentum.x + e_y.z*four_momentum.y + e_z.z*four_momentum.z;
        return result;
    }



    /* Rest frame velocity */
    MAGIK_DEVICE_HOST static constexpr float minkowski_compute_timelike_component_contravariant(vec3f dimensionless_observer_three_vector, float squard_norm)
    {
        float A = minkowski_g_tt();
        float C = minkowski_g_xxyyzz()*dimensionless_observer_three_vector.x*dimensionless_observer_three_vector.x \
                + minkowski_g_xxyyzz()*dimensionless_observer_three_vector.y*dimensionless_observer_three_vector.y \
                + minkowski_g_xxyyzz()*dimensionless_observer_three_vector.z*dimensionless_observer_three_vector.z \
                - squard_norm;

        return (-sqrtf(-4.0f*A*C))/(2.0f*A);
    }

    MAGIK_DEVICE_HOST static constexpr float minkowski_compute_timelike_component_covariant(vec3f dimensionless_observer_three_vector, float squard_norm)
    { 
        float A = minkowski_g_inv_tt();
        float C = minkowski_g_inv_xxyyzz()*dimensionless_observer_three_vector.x*dimensionless_observer_three_vector.x \
                + minkowski_g_inv_xxyyzz()*dimensionless_observer_three_vector.y*dimensionless_observer_three_vector.y \
                + minkowski_g_inv_xxyyzz()*dimensionless_observer_three_vector.z*dimensionless_observer_three_vector.z \
                - squard_norm;

        return (-sqrtf(-4.0f*A*C))/(2.0f*A);
    }

    struct minkowski_object_velocity_from_ZAMO_to_global_t
    {
        vec4f contravariant_seed_vector_x{}; 
        vec4f contravariant_seed_vector_y{};
        vec4f contravariant_seed_vector_z{};
        vec3f dimensionless_three_velocity{};
    };

    MAGIK_DEVICE_HOST static constexpr vec4f minkowski_object_velocity_from_ZAMO_to_global(minkowski_object_velocity_from_ZAMO_to_global_t args)
    {
        minkowski_observer_rest_frame_to_global_t input;
        input.contravariant_seed_vector_x = args.contravariant_seed_vector_x;
        input.contravariant_seed_vector_y = args.contravariant_seed_vector_y;
        input.contravariant_seed_vector_z = args.contravariant_seed_vector_z;
        input.dimensionless_observer_four_velocity = vec4f{0.0f, 0.0f, 0.0f, 1.0f};
        input.dimensionless_spatial_vector = args.dimensionless_three_velocity;
        input.input_vector_norm = -1.0f;

        return minkowski_observer_rest_frame_to_global(input);
    }



    /* Global to rest frame */
    struct minkowski_global_to_observer_rest_frame_t
    {
        vec4f contravariant_seed_vector_x{};
        vec4f contravariant_seed_vector_y{};
        vec4f contravariant_seed_vector_z{};
        vec4f dimensionless_four_vector{};
        vec4f dimensionless_observer_four_velocity{};
        float input_vector_norm{};
    };

    MAGIK_DEVICE_HOST static constexpr vec4f minkowski_global_to_observer_rest_frame(minkowski_global_to_observer_rest_frame_t args)
    {
        vec4f covariant_seed_vectors_x = minkowski_lower_index(args.contravariant_seed_vector_x);
        vec4f covariant_seed_vectors_y = minkowski_lower_index(args.contravariant_seed_vector_y);
        vec4f covariant_seed_vectors_z = minkowski_lower_index(args.contravariant_seed_vector_z);

        vec4f e_t = -minkowski_lower_index(args.dimensionless_observer_four_velocity);

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
        result.t = e_t.t*args.dimensionless_four_vector.t + e_t.x*args.dimensionless_four_vector.x + e_t.y*args.dimensionless_four_vector.y + e_t.z*args.dimensionless_four_vector.z;
        result.x = e_x.t*args.dimensionless_four_vector.t + e_x.x*args.dimensionless_four_vector.x + e_x.y*args.dimensionless_four_vector.y + e_x.z*args.dimensionless_four_vector.z;
        result.y = e_y.t*args.dimensionless_four_vector.t + e_y.x*args.dimensionless_four_vector.x + e_y.y*args.dimensionless_four_vector.y + e_y.z*args.dimensionless_four_vector.z;
        result.z = e_z.t*args.dimensionless_four_vector.t + e_z.x*args.dimensionless_four_vector.x + e_z.y*args.dimensionless_four_vector.y + e_z.z*args.dimensionless_four_vector.z;
        return result;
    }



    /* Step function */
    MAGIK_DEVICE_HOST static constexpr geodesic_step_values minkowski_geodesic_eq_rhs(geodesic_step_values y0)
    {
        vec4f d_four_momentum = vec4f{0.0f, 0.0f, 0.0f, 0.0f};
        vec4f d_four_position = minkowski_raise_index(y0.four_momentum);
        return geodesic_step_values{d_four_position, d_four_momentum};
    }
}
