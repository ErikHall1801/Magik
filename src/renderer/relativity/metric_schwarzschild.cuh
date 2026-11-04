#pragma once

#include "relativity_utilities.cuh"

namespace magik
{
    /* Metric - Components */
    MAGIK_DEVICE_HOST static constexpr float schwarzschild_r(float dimensionless_x, float dimensionless_y, float dimensionless_z)
    {
        return sqrtf(dimensionless_x*dimensionless_x + dimensionless_y*dimensionless_y + dimensionless_z*dimensionless_z);
    }

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_f(float dimensionless_y, float r)
    {
        return 2.0f/r;
    }

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_k_xyz(float null_congruence_k_xyz, float r)
    {
        return null_congruence_k_xyz/r;
    }

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_g_tt(float f)
    {
        return -1.0f+f;
    }

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_g_txyz(float f, float null_congruence_k_xyz)
    {
        return f*null_congruence_k_xyz;
    }

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_g_xx(float f, float null_congruence_k_x)
    {
        return 1.0f+f*null_congruence_k_x*null_congruence_k_x;
    }

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_g_xy(float f, float null_congruence_k_x, float null_congruence_k_y)
    {
        return f*null_congruence_k_x*null_congruence_k_y;
    }

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_g_xz(float f, float null_congruence_k_x, float null_congruence_k_z)
    {
        return f*null_congruence_k_x*null_congruence_k_z;
    }

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_g_yy(float f, float null_congruence_k_y)
    {
        return 1.0f+f*null_congruence_k_y*null_congruence_k_y;
    }

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_g_yz(float f, float null_congruence_k_y, float null_congruence_k_z)
    {
        return f*null_congruence_k_y*null_congruence_k_z;
    }

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_g_zz(float f, float null_congruence_k_z)
    {
        return 1.0f+f*null_congruence_k_z*null_congruence_k_z;
    }

    /* Metric - Inverse components */
    MAGIK_DEVICE_HOST static constexpr float schwarzschild_g_inv_tt(float f)
    {
        return -1.0f-f;
    }

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_g_inv_txyz(float f, float null_congruence_k_xyz)
    {
        return f*null_congruence_k_xyz;
    }

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_g_inv_xx(float f, float null_congruence_k_x)
    {
        return 1.0f - f*null_congruence_k_x*null_congruence_k_x;
    }

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_g_inv_xy(float f, float null_congruence_k_x, float null_congruence_k_y)
    {
        return -f*null_congruence_k_x*null_congruence_k_y;
    }

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_g_inv_xz(float f, float null_congruence_k_x, float null_congruence_k_z)
    {
        return -f*null_congruence_k_x*null_congruence_k_z;
    }

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_g_inv_yy(float f, float null_congruence_k_y)
    {
        return 1.0f-f*null_congruence_k_y*null_congruence_k_y;
    }

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_g_inv_yz(float f, float null_congruence_k_y, float null_congruence_k_z)
    {
        return -f*null_congruence_k_y*null_congruence_k_z;
    }

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_g_inv_zz(float f, float null_congruence_k_z)
    {
        return 1.0f-f*null_congruence_k_z*null_congruence_k_z;
    }

    /* Metric - Index */
    MAGIK_DEVICE_HOST static constexpr vec4f schwarzschild_lower_index(float dimensionless_x, float dimensionless_y, float dimensionless_z, vec4f contravariant_vector)
    {
        vec4f output;

        float r = schwarzschild_r(dimensionless_x, dimensionless_y, dimensionless_z);
        float f = schwarzschild_f(dimensionless_y, r);
        float k_x = schwarzschild_k_xyz(dimensionless_x, r);
        float k_y = schwarzschild_k_xyz(dimensionless_y, r);
        float k_z = schwarzschild_k_xyz(dimensionless_z, r);

        output.t = schwarzschild_g_tt(f)*contravariant_vector.t + schwarzschild_g_txyz(f, k_x)*contravariant_vector.x + schwarzschild_g_txyz(f, k_y)*contravariant_vector.y + schwarzschild_g_txyz(f, k_z)*contravariant_vector.z;
        output.x = schwarzschild_g_txyz(f, k_x)*contravariant_vector.t + schwarzschild_g_xx(f, k_x)*contravariant_vector.x + schwarzschild_g_xy(f, k_x, k_y)*contravariant_vector.y + schwarzschild_g_xz(f, k_x, k_z)*contravariant_vector.z;
        output.y = schwarzschild_g_txyz(f, k_y)*contravariant_vector.t + schwarzschild_g_xy(f, k_x, k_y)*contravariant_vector.x + schwarzschild_g_yy(f, k_y)*contravariant_vector.y + schwarzschild_g_yz(f, k_y, k_z)*contravariant_vector.z;
        output.z = schwarzschild_g_txyz(f, k_z)*contravariant_vector.t + schwarzschild_g_xz(f, k_x, k_z)*contravariant_vector.x + schwarzschild_g_yz(f, k_y, k_z)*contravariant_vector.y + schwarzschild_g_zz(f, k_z)*contravariant_vector.z;

        return output;
    }

    MAGIK_DEVICE_HOST static constexpr vec4f schwarzschild_raise_index(float dimensionless_x, float dimensionless_y, float dimensionless_z, vec4f covariant_vector)
    {
        vec4f output;

        float r = schwarzschild_r(dimensionless_x, dimensionless_y, dimensionless_z);
        float f = schwarzschild_f(dimensionless_y, r);
        float k_x = schwarzschild_g_txyz(dimensionless_x, r);
        float k_y = schwarzschild_g_txyz(dimensionless_y, r);
        float k_z = schwarzschild_g_txyz(dimensionless_z, r);
            
        output.t = schwarzschild_g_inv_tt(f)*covariant_vector.t + schwarzschild_g_inv_txyz(f, k_x)*covariant_vector.x + schwarzschild_g_inv_txyz(f, k_y)*covariant_vector.y + schwarzschild_g_inv_txyz(f, k_z)*covariant_vector.z;
        output.x = schwarzschild_g_inv_txyz(f, k_x)*covariant_vector.t + schwarzschild_g_inv_xx(f, k_x)*covariant_vector.x + schwarzschild_g_inv_xy(f, k_x, k_y)*covariant_vector.y + schwarzschild_g_inv_xz(f, k_x, k_z)*covariant_vector.z;
        output.y = schwarzschild_g_inv_txyz(f, k_y)*covariant_vector.t + schwarzschild_g_inv_xy(f, k_x, k_y)*covariant_vector.x + schwarzschild_g_inv_yy(f, k_y)*covariant_vector.y + schwarzschild_g_inv_yz(f, k_y, k_z)*covariant_vector.z;
        output.z = schwarzschild_g_inv_txyz(f, k_z)*covariant_vector.t + schwarzschild_g_inv_xz(f, k_x, k_z)*covariant_vector.x + schwarzschild_g_inv_yz(f, k_y, k_z)*covariant_vector.y + schwarzschild_g_inv_zz(f, k_z)*covariant_vector.z;
        
        return output;
    }



    /* Rest frame to global frame */
    struct schwarzschild_inner_product_contravariant_t
    {
        float dimensionless_x{}; 
        float dimensionless_y{};
        float dimensionless_z{}; 
        vec4f u_contravariant{}; 
        vec4f v_contravariant{};
    };

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_inner_product_contravariant(schwarzschild_inner_product_contravariant_t args)
    {
        float r = schwarzschild_r(args.dimensionless_x, args.dimensionless_y, args.dimensionless_z);
        float f = schwarzschild_f(args.dimensionless_y, r);
        float k_x = schwarzschild_k_xyz(args.dimensionless_x, r);
        float k_y = schwarzschild_k_xyz(args.dimensionless_y, r);
        float k_z = schwarzschild_k_xyz(args.dimensionless_z, r);

        return schwarzschild_g_tt(f)*args.u_contravariant.t*args.v_contravariant.t \
             + schwarzschild_g_txyz(f, k_x)*(args.u_contravariant.t*args.v_contravariant.x + args.u_contravariant.x*args.v_contravariant.t) \
             + schwarzschild_g_txyz(f, k_y)*(args.u_contravariant.t*args.v_contravariant.y + args.u_contravariant.y*args.v_contravariant.t) \
             + schwarzschild_g_txyz(f, k_z)*(args.u_contravariant.t*args.v_contravariant.z + args.u_contravariant.z*args.v_contravariant.t) \
             + schwarzschild_g_xx(f, k_x)*args.u_contravariant.x*args.v_contravariant.x \
             + schwarzschild_g_xy(f, k_x, k_y)*(args.u_contravariant.x*args.v_contravariant.y + args.u_contravariant.y*args.v_contravariant.x) \
             + schwarzschild_g_xz(f, k_x, k_z)*(args.u_contravariant.x*args.v_contravariant.z + args.u_contravariant.z*args.v_contravariant.x) \
             + schwarzschild_g_yy(f, k_y)*args.u_contravariant.y*args.v_contravariant.y \
             + schwarzschild_g_yz(f, k_y, k_z)*(args.u_contravariant.y*args.v_contravariant.z + args.u_contravariant.z*args.v_contravariant.y) \
             + schwarzschild_g_zz(f, k_z)*args.u_contravariant.z*args.v_contravariant.z;
    }

    struct schwarzschild_inner_product_covariant_t
    {
        float dimensionless_x{}; 
        float dimensionless_y{}; 
        float dimensionless_z{};
        vec4f u_covariant{};
        vec4f v_covariant{};
    };

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_inner_product_covariant(schwarzschild_inner_product_covariant_t args)
    {
        float r = schwarzschild_r(args.dimensionless_x, args.dimensionless_y, args.dimensionless_z);
        float f = schwarzschild_f(args.dimensionless_y, r);
        float k_x = schwarzschild_k_xyz(args.dimensionless_x, r);
        float k_y = schwarzschild_k_xyz(args.dimensionless_y, r);
        float k_z = schwarzschild_k_xyz(args.dimensionless_z, r);

        return schwarzschild_g_inv_tt(f)*args.u_covariant.t*args.v_covariant.t \
             + schwarzschild_g_inv_txyz(f, k_x)*(args.u_covariant.t*args.v_covariant.x + args.u_covariant.x*args.v_covariant.t) \
             + schwarzschild_g_inv_txyz(f, k_y)*(args.u_covariant.t*args.v_covariant.y + args.u_covariant.y*args.v_covariant.t) \
             + schwarzschild_g_inv_txyz(f, k_z)*(args.u_covariant.t*args.v_covariant.z + args.u_covariant.z*args.v_covariant.t) \
             + schwarzschild_g_inv_xx(f, k_x)*args.u_covariant.x*args.v_covariant.x \
             + schwarzschild_g_inv_xy(f, k_x, k_y)*(args.u_covariant.x*args.v_covariant.y + args.u_covariant.y*args.v_covariant.x) \
             + schwarzschild_g_inv_xz(f, k_x, k_z)*(args.u_covariant.x*args.v_covariant.z + args.u_covariant.z*args.v_covariant.x) \
             + schwarzschild_g_inv_yy(f, k_y)*args.u_covariant.y*args.v_covariant.y \
             + schwarzschild_g_inv_yz(f, k_y, k_z)*(args.u_covariant.y*args.v_covariant.z + args.u_covariant.z*args.v_covariant.y) \
             + schwarzschild_g_inv_zz(f, k_z)*args.u_covariant.z*args.v_covariant.z;
    }

    struct schwarzschild_observer_rest_frame_to_global_t
    {
        float dimensionless_x{}; 
        float dimensionless_y{}; 
        float dimensionless_z{}; 
        vec4f contravariant_seed_vector_x{}; 
        vec4f contravariant_seed_vector_y{}; 
        vec4f contravariant_seed_vector_z{}; 
        vec3f dimensionless_spatial_vector{}; 
        vec4f dimensionless_observer_four_velocity{}; 
        float input_vector_norm{}; 
    };

    MAGIK_DEVICE_HOST static constexpr vec4f schwarzschild_observer_rest_frame_to_global(schwarzschild_observer_rest_frame_to_global_t args)
    {
        vec4f four_momentum = vec4f{args.dimensionless_spatial_vector.x, args.dimensionless_spatial_vector.y, args.dimensionless_spatial_vector.z, compute_local_timelike_component(args.dimensionless_spatial_vector, args.input_vector_norm)};

        vec4f e_t = args.dimensionless_observer_four_velocity;

        vec4f e_z = args.contravariant_seed_vector_z + schwarzschild_inner_product_contravariant({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.contravariant_seed_vector_z, e_t})*e_t; 
        e_z = e_z / sqrtf(schwarzschild_inner_product_contravariant({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, e_z, e_z}));

        vec4f e_x = args.contravariant_seed_vector_x + schwarzschild_inner_product_contravariant({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.contravariant_seed_vector_x, e_t})*e_t \
                                                     - schwarzschild_inner_product_contravariant({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.contravariant_seed_vector_x, e_z})*e_z;
        e_x = e_x / sqrtf(schwarzschild_inner_product_contravariant({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, e_x, e_x}));

        vec4f e_y = args.contravariant_seed_vector_y + schwarzschild_inner_product_contravariant({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.contravariant_seed_vector_y, e_t})*e_t \
                                                     - schwarzschild_inner_product_contravariant({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.contravariant_seed_vector_y, e_z})*e_z \
                                                     - schwarzschild_inner_product_contravariant({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.contravariant_seed_vector_y, e_x})*e_x;
        e_y = e_y / sqrtf(schwarzschild_inner_product_contravariant({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, e_y, e_y}));

        vec4f result;
        result.t = e_t.t*four_momentum.t + e_x.t*four_momentum.x + e_y.t*four_momentum.y + e_z.t*four_momentum.z;
        result.x = e_t.x*four_momentum.t + e_x.x*four_momentum.x + e_y.x*four_momentum.y + e_z.x*four_momentum.z;
        result.y = e_t.y*four_momentum.t + e_x.y*four_momentum.x + e_y.y*four_momentum.y + e_z.y*four_momentum.z;
        result.z = e_t.z*four_momentum.t + e_x.z*four_momentum.x + e_y.z*four_momentum.y + e_z.z*four_momentum.z;
        return result;
    }



    /* Rest frame velocity */
    struct schwarzschild_compute_timelike_component_t
    {
        float dimensionless_x{};
        float dimensionless_y{};
        float dimensionless_z{};
        vec3f dimensionless_observer_three_vector{};
        float squard_norm{};
    };

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_compute_timelike_component_contravariant(schwarzschild_compute_timelike_component_t args)
    {
        float r = schwarzschild_r(args.dimensionless_x, args.dimensionless_y, args.dimensionless_z);
        float f = schwarzschild_f(args.dimensionless_y, r);
        float k_x = schwarzschild_k_xyz(args.dimensionless_x, r);
        float k_y = schwarzschild_k_xyz(args.dimensionless_y, r);
        float k_z = schwarzschild_k_xyz(args.dimensionless_z, r);

        float A = schwarzschild_g_tt(f);
        float B = 2.0f*(schwarzschild_g_txyz(f, k_x)*args.dimensionless_observer_three_vector.x + schwarzschild_g_txyz(f, k_y)*args.dimensionless_observer_three_vector.y + schwarzschild_g_txyz(f, k_z)*args.dimensionless_observer_three_vector.z);
        float C = schwarzschild_g_xx(f, k_x)*args.dimensionless_observer_three_vector.x*args.dimensionless_observer_three_vector.x \
              + 2.0f*schwarzschild_g_xy(f, k_x, k_y)*args.dimensionless_observer_three_vector.x*args.dimensionless_observer_three_vector.y \
              + 2.0f*schwarzschild_g_xz(f, k_x, k_z)*args.dimensionless_observer_three_vector.x*args.dimensionless_observer_three_vector.z \
              + schwarzschild_g_yy(f, k_y)*args.dimensionless_observer_three_vector.y*args.dimensionless_observer_three_vector.y \
              + 2.0f*schwarzschild_g_yz(f, k_y, k_z)*args.dimensionless_observer_three_vector.y*args.dimensionless_observer_three_vector.z \
              + schwarzschild_g_zz(f, k_z)*args.dimensionless_observer_three_vector.z*args.dimensionless_observer_three_vector.z \
              - args.squard_norm;

        return (-B - sqrtf(B*B - 4.0f*A*C))/(2.0f*A);
    }

    MAGIK_DEVICE_HOST static constexpr float schwarzschild_compute_timelike_component_covariant(schwarzschild_compute_timelike_component_t args)
    {
        float r = schwarzschild_r(args.dimensionless_x, args.dimensionless_y, args.dimensionless_z);
        float f = schwarzschild_f(args.dimensionless_y, r);
        float k_x = schwarzschild_k_xyz(args.dimensionless_x, r);
        float k_y = schwarzschild_k_xyz(args.dimensionless_y, r);
        float k_z = schwarzschild_k_xyz(args.dimensionless_z, r);
                        
        float A = schwarzschild_g_inv_tt(f);
        float B = 2.0f*(schwarzschild_g_inv_txyz(f, k_x)*args.dimensionless_observer_three_vector.x + schwarzschild_g_inv_txyz(f, k_y)*args.dimensionless_observer_three_vector.y + schwarzschild_g_inv_txyz(f, k_z)*args.dimensionless_observer_three_vector.z);
        float C = schwarzschild_g_inv_xx(f, k_x)*args.dimensionless_observer_three_vector.x*args.dimensionless_observer_three_vector.x \
              + 2.0f*schwarzschild_g_inv_xy(f, k_x, k_y)*args.dimensionless_observer_three_vector.x*args.dimensionless_observer_three_vector.y \
              + 2.0f*schwarzschild_g_inv_xz(f, k_x, k_z)*args.dimensionless_observer_three_vector.x*args.dimensionless_observer_three_vector.z \
              + schwarzschild_g_inv_yy(f, k_y)*args.dimensionless_observer_three_vector.y*args.dimensionless_observer_three_vector.y \
              + 2.0f*schwarzschild_g_inv_yz(f, k_y, k_z)*args.dimensionless_observer_three_vector.y*args.dimensionless_observer_three_vector.z \
              + schwarzschild_g_inv_zz(f, k_z)*args.dimensionless_observer_three_vector.z*args.dimensionless_observer_three_vector.z \
              - args.squard_norm;

        return (-B - sqrtf(B*B - 4.0f*A*C))/(2.0f*A);
    }

    struct schwarzschild_object_velocity_from_ZAMO_to_global_t
    {
        float dimensionless_x{}; 
        float dimensionless_y{};
        float dimensionless_z{};
        vec4f contravariant_seed_vector_x{};
        vec4f contravariant_seed_vector_y{};
        vec4f contravariant_seed_vector_z{};
        vec3f dimensionless_three_velocity{};
    };

    MAGIK_DEVICE_HOST static constexpr vec4f schwarzschild_object_velocity_from_ZAMO_to_global(schwarzschild_object_velocity_from_ZAMO_to_global_t args)
    {
        float r = schwarzschild_r(args.dimensionless_x, args.dimensionless_y, args.dimensionless_z);
        float r_sq = r * r;
            
        float sigma = r_sq;
        float delta = r_sq - 2.0f*r;
        float Lambda = (r_sq)*(r_sq);
        float u_t = sqrtf(Lambda/(delta*sigma));

        float squared_norm = -1.0f;
        vec4f ZAMO_four_velocity = vec4f{0.0f, 0.0f, 0.0f, u_t};

        return schwarzschild_observer_rest_frame_to_global({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.contravariant_seed_vector_x, args.contravariant_seed_vector_y, args.contravariant_seed_vector_z, args.dimensionless_three_velocity, ZAMO_four_velocity, squared_norm});
    }



    /* Global to rest frame */
    struct schwarzschild_global_to_observer_rest_frame_t
    {
        float dimensionless_x{}; 
        float dimensionless_y{}; 
        float dimensionless_z{}; 
        vec4f contravariant_seed_vector_x{}; 
        vec4f contravariant_seed_vector_y{}; 
        vec4f contravariant_seed_vector_z{}; 
        vec4f dimensionless_four_vector{}; 
        vec4f dimensionless_observer_four_velocity{}; 
        float input_vector_norm{};
    };

    MAGIK_DEVICE_HOST static constexpr vec4f schwarzschild_global_to_observer_rest_frame(schwarzschild_global_to_observer_rest_frame_t args)
    {
        vec4f covariant_seed_vectors_x = schwarzschild_lower_index(args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.contravariant_seed_vector_x);
        vec4f covariant_seed_vectors_y = schwarzschild_lower_index(args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.contravariant_seed_vector_y);
        vec4f covariant_seed_vectors_z = schwarzschild_lower_index(args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.contravariant_seed_vector_z);

        vec4f e_t = -schwarzschild_lower_index(args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.dimensionless_observer_four_velocity);

        vec4f e_z = covariant_seed_vectors_z + schwarzschild_inner_product_covariant({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, covariant_seed_vectors_z, e_t})*e_t;
        e_z = e_z / sqrtf(schwarzschild_inner_product_covariant({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, e_z, e_z}));

        vec4f e_x = covariant_seed_vectors_x + schwarzschild_inner_product_covariant({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, covariant_seed_vectors_x, e_t})*e_t \
        - schwarzschild_inner_product_covariant({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, covariant_seed_vectors_x, e_z})*e_z;
        e_x = e_x / sqrtf(schwarzschild_inner_product_covariant({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, e_x, e_x}));

        vec4f e_y = covariant_seed_vectors_y + schwarzschild_inner_product_covariant({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, covariant_seed_vectors_y, e_t})*e_t \
        - schwarzschild_inner_product_covariant({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, covariant_seed_vectors_y, e_z})*e_z \
        - schwarzschild_inner_product_covariant({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, covariant_seed_vectors_y, e_x})*e_x;
        e_y = e_y / sqrtf(schwarzschild_inner_product_covariant({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, e_y, e_y}));

        vec4f result;
        result.t = e_t.t*args.dimensionless_four_vector.t + e_t.x*args.dimensionless_four_vector.x + e_t.y*args.dimensionless_four_vector.y + e_t.z*args.dimensionless_four_vector.z;
        result.x = e_x.t*args.dimensionless_four_vector.t + e_x.x*args.dimensionless_four_vector.x + e_x.y*args.dimensionless_four_vector.y + e_x.z*args.dimensionless_four_vector.z;
        result.y = e_y.t*args.dimensionless_four_vector.t + e_y.x*args.dimensionless_four_vector.x + e_y.y*args.dimensionless_four_vector.y + e_y.z*args.dimensionless_four_vector.z;
        result.z = e_z.t*args.dimensionless_four_vector.t + e_z.x*args.dimensionless_four_vector.x + e_z.y*args.dimensionless_four_vector.y + e_z.z*args.dimensionless_four_vector.z;
        return result;
    }



    /* Step function */
    MAGIK_DEVICE_HOST static constexpr geodesic_step_values schwarzschild_geodesic_eq_rhs(geodesic_step_values y0)
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
        float f_ = 2.0f * r_cu / f_den;

        float dfdq_scale = 2.0f * -r_six * inv_f_den_sq;
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
        
        vec4f dqdt_lambda{ px - f_kTp * kx, py - f_kTp * ky, pz - f_kTp * kz, -pt - f_kTp };

        vec4f dpdt_lambda{ half_kTp_sq * dfdq_.x + f_kTp * beta.x, half_kTp_sq * dfdq_.y + f_kTp * beta.y, half_kTp_sq * dfdq_.z + f_kTp * beta.z, 0.0f };

        return geodesic_step_values{dqdt_lambda, dpdt_lambda};
    }
}
