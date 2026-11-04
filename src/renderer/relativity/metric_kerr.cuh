#pragma once

#include "relativity_utilities.cuh"

namespace magik
{
    /* Metric - Components */
    MAGIK_DEVICE_HOST static constexpr float kerr_schild_r(float dimensionless_x, float dimensionless_y, float dimensionless_z, float dimensionless_spin_parameter)
    {
        float R = (dimensionless_x*dimensionless_x + dimensionless_y*dimensionless_y + dimensionless_z*dimensionless_z - dimensionless_spin_parameter*dimensionless_spin_parameter);
        float r_squared = 0.5f*R + 0.5f*sqrtf(R*R + 4.0f*dimensionless_spin_parameter*dimensionless_spin_parameter*dimensionless_y*dimensionless_y);
        return sqrtf(r_squared);
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_schild_f(float dimensionless_y, float r, float dimensionless_spin_parameter)
    {
        return 2.0f*r*r*r / (r*r*r*r + dimensionless_spin_parameter*dimensionless_spin_parameter*dimensionless_y*dimensionless_y);
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_schild_k_x(float null_congruence_k_x, float null_congruence_k_z, float r, float dimensionless_spin_parameter)
    {
        return (r*null_congruence_k_x - dimensionless_spin_parameter*null_congruence_k_z)/(r*r + dimensionless_spin_parameter*dimensionless_spin_parameter);
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_schild_k_y(float null_congruence_k_y, float r)
    {
        return null_congruence_k_y/r;
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_schild_k_z(float null_congruence_k_x, float null_congruence_k_z, float r, float dimensionless_spin_parameter)
    {
        return (r*null_congruence_k_z + dimensionless_spin_parameter*null_congruence_k_x)/(r*r + dimensionless_spin_parameter*dimensionless_spin_parameter);
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_g_tt(float f)
    {
        return -1.0f+f;
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_g_txyz(float f, float null_congruence_k_x)
    {
        return f*null_congruence_k_x;
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_g_xx(float f, float null_congruence_k_x)
    {
        return 1.0f+f*null_congruence_k_x*null_congruence_k_x;
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_g_xy(float f, float null_congruence_k_x, float null_congruence_k_y)
    {
        return f*null_congruence_k_x*null_congruence_k_y;
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_g_xz(float f, float null_congruence_k_x, float null_congruence_k_z)
    {
        return f*null_congruence_k_x*null_congruence_k_z;
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_g_yy(float f, float null_congruence_k_y)
    {
        return 1.0f+f*null_congruence_k_y*null_congruence_k_y;
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_g_yz(float f, float null_congruence_k_y, float null_congruence_k_z)
    {
        return f*null_congruence_k_y*null_congruence_k_z;
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_g_zz(float f, float null_congruence_k_z)
    {
        return 1.0f+f*null_congruence_k_z*null_congruence_k_z;
    }

    /* Metric - Inverse components */
    MAGIK_DEVICE_HOST static constexpr float kerr_g_inv_tt(float f)
    {
        return -1.0f-f;
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_g_inv_txyz(float f, float null_congruence_k_x)
    {
        return f*null_congruence_k_x;
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_g_inv_xx(float f, float null_congruence_k_x)
    {
        return 1.0f-f*null_congruence_k_x*null_congruence_k_x;
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_g_inv_xy(float f, float null_congruence_k_x, float null_congruence_k_y)
    {
        return -f*null_congruence_k_x*null_congruence_k_y;
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_g_inv_xz(float f, float null_congruence_k_x, float null_congruence_k_z)
    {
        return -f*null_congruence_k_x*null_congruence_k_z;
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_g_inv_yy(float f, float null_congruence_k_y)
    {
        return 1.0f-f*null_congruence_k_y*null_congruence_k_y;
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_g_inv_yz(float f, float null_congruence_k_y, float null_congruence_k_z)
    {
        return -f*null_congruence_k_y*null_congruence_k_z;
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_g_inv_zz(float f, float null_congruence_k_z)
    {
        return 1.0f-f*null_congruence_k_z*null_congruence_k_z;
    }

    /* Metric - Index */
    MAGIK_DEVICE_HOST static constexpr vec4f kerr_lower_index(vec4f dimensionless_four_position, vec4f contravariant_vector, float dimensionless_spin_parameter)
    {
        vec4f output;

        float r = kerr_schild_r(dimensionless_four_position.x, dimensionless_four_position.y, dimensionless_four_position.z, dimensionless_spin_parameter);
        float f = kerr_schild_f(dimensionless_four_position.y, r, dimensionless_spin_parameter);
        float k_x = kerr_schild_k_x(dimensionless_four_position.x, dimensionless_four_position.z, r, dimensionless_spin_parameter);
        float k_y = kerr_schild_k_y(dimensionless_four_position.y, r);
        float k_z = kerr_schild_k_z(dimensionless_four_position.x, dimensionless_four_position.z, r, dimensionless_spin_parameter);

        output.t = kerr_g_tt(f)*contravariant_vector.t + kerr_g_txyz(f, k_x)*contravariant_vector.x + kerr_g_txyz(f, k_y)*contravariant_vector.y + kerr_g_txyz(f, k_z)*contravariant_vector.z;
        output.x = kerr_g_txyz(f, k_x)*contravariant_vector.t + kerr_g_xx(f, k_x)*contravariant_vector.x + kerr_g_xy(f, k_x, k_y)*contravariant_vector.y + kerr_g_xz(f, k_x, k_z)*contravariant_vector.z;
        output.y = kerr_g_txyz(f, k_y)*contravariant_vector.t + kerr_g_xy(f, k_x, k_y)*contravariant_vector.x + kerr_g_yy(f, k_y)*contravariant_vector.y + kerr_g_yz(f, k_y, k_z)*contravariant_vector.z;
        output.z = kerr_g_txyz(f, k_z)*contravariant_vector.t + kerr_g_xz(f, k_x, k_z)*contravariant_vector.x + kerr_g_yz(f, k_y, k_z)*contravariant_vector.y + kerr_g_zz(f, k_z)*contravariant_vector.z;
    
        return output;
    }

    MAGIK_DEVICE_HOST static constexpr vec4f kerr_raise_index(vec4f dimensionless_four_position, vec4f covariant_vector, float dimensionless_spin_parameter)
    {
        vec4f output;

        float r = kerr_schild_r(dimensionless_four_position.x, dimensionless_four_position.y, dimensionless_four_position.z, dimensionless_spin_parameter);
        float f = kerr_schild_f(dimensionless_four_position.y, r, dimensionless_spin_parameter);
        float k_x = kerr_schild_k_x(dimensionless_four_position.x, dimensionless_four_position.z, r, dimensionless_spin_parameter);
        float k_y = kerr_schild_k_y(dimensionless_four_position.y, r);
        float k_z = kerr_schild_k_z(dimensionless_four_position.x, dimensionless_four_position.z, r, dimensionless_spin_parameter);
            
        output.t = kerr_g_inv_tt(f)*covariant_vector.t + kerr_g_inv_txyz(f, k_x)*covariant_vector.x + kerr_g_inv_txyz(f, k_y)*covariant_vector.y + kerr_g_inv_txyz(f, k_z)*covariant_vector.z;
        output.x = kerr_g_inv_txyz(f, k_x)*covariant_vector.t + kerr_g_inv_xx(f, k_x)*covariant_vector.x + kerr_g_inv_xy(f, k_x, k_y)*covariant_vector.y + kerr_g_inv_xz(f, k_x, k_z)*covariant_vector.z;
        output.y = kerr_g_inv_txyz(f, k_y)*covariant_vector.t + kerr_g_inv_xy(f, k_x, k_y)*covariant_vector.x + kerr_g_inv_yy(f, k_y)*covariant_vector.y + kerr_g_inv_yz(f, k_y, k_z)*covariant_vector.z;
        output.z = kerr_g_inv_txyz(f, k_z)*covariant_vector.t + kerr_g_inv_xz(f, k_x, k_z)*covariant_vector.x + kerr_g_inv_yz(f, k_y, k_z)*covariant_vector.y + kerr_g_inv_zz(f, k_z)*covariant_vector.z;
            
        return output;
    }



    /* Rest frame to global */
    MAGIK_DEVICE_HOST static constexpr float kerr_inner_product_contravariant(vec4f dimensionless_four_position, vec4f u_contravariant, vec4f v_contravariant, float dimensionless_spin_parameter)
    {
        float r = kerr_schild_r(dimensionless_four_position.x, dimensionless_four_position.y, dimensionless_four_position.z, dimensionless_spin_parameter);
        float f = kerr_schild_f(dimensionless_four_position.y, r, dimensionless_spin_parameter);
        float k_x = kerr_schild_k_x(dimensionless_four_position.x, dimensionless_four_position.z, r, dimensionless_spin_parameter);
        float k_y = kerr_schild_k_y(dimensionless_four_position.y, r);
        float k_z = kerr_schild_k_z(dimensionless_four_position.x, dimensionless_four_position.z, r, dimensionless_spin_parameter);

        return kerr_g_tt(f)*u_contravariant.t*v_contravariant.t \
             + kerr_g_txyz(f, k_x)*(u_contravariant.t*v_contravariant.x + u_contravariant.x*v_contravariant.t) \
             + kerr_g_txyz(f, k_y)*(u_contravariant.t*v_contravariant.y + u_contravariant.y*v_contravariant.t) \
             + kerr_g_txyz(f, k_z)*(u_contravariant.t*v_contravariant.z + u_contravariant.z*v_contravariant.t) \
             + kerr_g_xx(f, k_x)*u_contravariant.x*v_contravariant.x \
             + kerr_g_xy(f, k_x, k_y)*(u_contravariant.x*v_contravariant.y + u_contravariant.y*v_contravariant.x) \
             + kerr_g_xz(f, k_x, k_z)*(u_contravariant.x*v_contravariant.z + u_contravariant.z*v_contravariant.x) \
             + kerr_g_yy(f, k_y)*u_contravariant.y*v_contravariant.y \
             + kerr_g_yz(f, k_y, k_z)*(u_contravariant.y*v_contravariant.z + u_contravariant.z*v_contravariant.y) \
             + kerr_g_zz(f, k_z)*u_contravariant.z*v_contravariant.z;
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_inner_product_covariant(vec4f dimensionless_four_position, vec4f u_covariant, vec4f v_covariant, float dimensionless_spin_parameter)
    {
        float r = kerr_schild_r(dimensionless_four_position.x, dimensionless_four_position.y, dimensionless_four_position.z, dimensionless_spin_parameter);
        float f = kerr_schild_f(dimensionless_four_position.y, r, dimensionless_spin_parameter);
        float k_x = kerr_schild_k_x(dimensionless_four_position.x, dimensionless_four_position.z, r, dimensionless_spin_parameter);
        float k_y = kerr_schild_k_y(dimensionless_four_position.y, r);
        float k_z = kerr_schild_k_z(dimensionless_four_position.x, dimensionless_four_position.z, r, dimensionless_spin_parameter);

        return kerr_g_inv_tt(f)*u_covariant.t*v_covariant.t \
             + kerr_g_inv_txyz(f, k_x)*(u_covariant.t*v_covariant.x + u_covariant.x*v_covariant.t) \
             + kerr_g_inv_txyz(f, k_y)*(u_covariant.t*v_covariant.y + u_covariant.y*v_covariant.t) \
             + kerr_g_inv_txyz(f, k_z)*(u_covariant.t*v_covariant.z + u_covariant.z*v_covariant.t) \
             + kerr_g_inv_xx(f, k_x)*u_covariant.x*v_covariant.x \
             + kerr_g_inv_xy(f, k_x, k_y)*(u_covariant.x*v_covariant.y + u_covariant.y*v_covariant.x) \
             + kerr_g_inv_xz(f, k_x, k_z)*(u_covariant.x*v_covariant.z + u_covariant.z*v_covariant.x) \
             + kerr_g_inv_yy(f, k_y)*u_covariant.y*v_covariant.y \
             + kerr_g_inv_yz(f, k_y, k_z)*(u_covariant.y*v_covariant.z + u_covariant.z*v_covariant.y) \
             + kerr_g_inv_zz(f, k_z)*u_covariant.z*v_covariant.z;
    }

    MAGIK_DEVICE_HOST static constexpr vec4f kerr_observer_rest_frame_to_global(vec4f dimensionless_four_position, contravariant_seed_vectors_t seed_vectors, vec3f dimensionless_spatial_vector, vec4f dimensionless_observer_four_velocity, float dimensionless_spin_parameter, float squared_norm)
    {
        vec4f four_momentum = vec4f{dimensionless_spatial_vector.x, dimensionless_spatial_vector.y, dimensionless_spatial_vector.z, compute_local_timelike_component(dimensionless_spatial_vector, squared_norm)};

        vec4f e_t = dimensionless_observer_four_velocity;

        vec4f e_z = seed_vectors.Z + kerr_inner_product_contravariant(dimensionless_four_position, seed_vectors.Z, e_t, dimensionless_spin_parameter)*e_t;
        e_z = e_z / sqrtf(kerr_inner_product_contravariant(dimensionless_four_position, e_z, e_z, dimensionless_spin_parameter));

        vec4f e_x = seed_vectors.X + kerr_inner_product_contravariant(dimensionless_four_position, seed_vectors.X, e_t, dimensionless_spin_parameter)*e_t \
                                                - kerr_inner_product_contravariant(dimensionless_four_position, seed_vectors.X, e_z, dimensionless_spin_parameter)*e_z;
        e_x = e_x / sqrtf(kerr_inner_product_contravariant(dimensionless_four_position, e_x, e_x, dimensionless_spin_parameter));

        vec4f e_y = seed_vectors.Y + kerr_inner_product_contravariant(dimensionless_four_position, seed_vectors.Y, e_t, dimensionless_spin_parameter)*e_t \
                                                - kerr_inner_product_contravariant(dimensionless_four_position, seed_vectors.Y, e_z, dimensionless_spin_parameter)*e_z \
                                                - kerr_inner_product_contravariant(dimensionless_four_position, seed_vectors.Y, e_x, dimensionless_spin_parameter)*e_x;
        e_y = e_y / sqrtf(kerr_inner_product_contravariant(dimensionless_four_position, e_y, e_y, dimensionless_spin_parameter));

        vec4f result;

        result.t = e_t.t*four_momentum.t + e_x.t*four_momentum.x + e_y.t*four_momentum.y + e_z.t*four_momentum.z;
        result.x = e_t.x*four_momentum.t + e_x.x*four_momentum.x + e_y.x*four_momentum.y + e_z.x*four_momentum.z;
        result.y = e_t.y*four_momentum.t + e_x.y*four_momentum.x + e_y.y*four_momentum.y + e_z.y*four_momentum.z;
        result.z = e_t.z*four_momentum.t + e_x.z*four_momentum.x + e_y.z*four_momentum.y + e_z.z*four_momentum.z;

        return result;
    }



    /* Rest frame velocity */
    MAGIK_DEVICE_HOST static constexpr float kerr_compute_timelike_component_contravariant(vec4f dimensionless_four_position, vec3f dimensionless_observer_three_vector, float dimensionless_spin_parameter, float squared_norm)
    {
        float r = kerr_schild_r(dimensionless_four_position.x, dimensionless_four_position.y, dimensionless_four_position.z, dimensionless_spin_parameter);
        float f = kerr_schild_f(dimensionless_four_position.y, r, dimensionless_spin_parameter);
        float k_x = kerr_schild_k_x(dimensionless_four_position.x, dimensionless_four_position.z, r, dimensionless_spin_parameter);
        float k_y = kerr_schild_k_y(dimensionless_four_position.y, r);
        float k_z = kerr_schild_k_z(dimensionless_four_position.x, dimensionless_four_position.z, r, dimensionless_spin_parameter);

        float A = kerr_g_tt(f);
        float B = 2.0f*(kerr_g_txyz(f, k_x)*dimensionless_observer_three_vector.x + kerr_g_txyz(f, k_y)*dimensionless_observer_three_vector.y + kerr_g_txyz(f, k_z)*dimensionless_observer_three_vector.z);
        float C = kerr_g_xx(f, k_x)*dimensionless_observer_three_vector.x*dimensionless_observer_three_vector.x \
              + 2.0f*kerr_g_xy(f, k_x, k_y)*dimensionless_observer_three_vector.x*dimensionless_observer_three_vector.y \
              + 2.0f*kerr_g_xz(f, k_x, k_z)*dimensionless_observer_three_vector.x*dimensionless_observer_three_vector.z \
              + kerr_g_yy(f, k_y)*dimensionless_observer_three_vector.y*dimensionless_observer_three_vector.y \
              + 2.0f*kerr_g_yz(f, k_y, k_z)*dimensionless_observer_three_vector.y*dimensionless_observer_three_vector.z \
              + kerr_g_zz(f, k_z)*dimensionless_observer_three_vector.z*dimensionless_observer_three_vector.z \
              - squared_norm;

        return (-B - sqrtf(B*B - 4.0f*A*C))/(2.0f*A);
    }

    MAGIK_DEVICE_HOST static constexpr float kerr_compute_timelike_component_covariant(vec4f dimensionless_four_position, vec3f dimensionless_observer_three_vector, float dimensionless_spin_parameter, float squared_norm)
    {
        float r = kerr_schild_r(dimensionless_four_position.x, dimensionless_four_position.y, dimensionless_four_position.z, dimensionless_spin_parameter);
        float f = kerr_schild_f(dimensionless_four_position.y, r, dimensionless_spin_parameter);
        float k_x = kerr_schild_k_x(dimensionless_four_position.x, dimensionless_four_position.z, r, dimensionless_spin_parameter);
        float k_y = kerr_schild_k_y(dimensionless_four_position.y, r);
        float k_z = kerr_schild_k_z(dimensionless_four_position.x, dimensionless_four_position.z, r, dimensionless_spin_parameter);

        float A = kerr_g_inv_tt(f);
        float B = 2.0f*(kerr_g_inv_txyz(f, k_x)*dimensionless_observer_three_vector.x + kerr_g_inv_txyz(f, k_y)*dimensionless_observer_three_vector.y + kerr_g_inv_txyz(f, k_z)*dimensionless_observer_three_vector.z);
        float C = kerr_g_inv_xx(f, k_x)*dimensionless_observer_three_vector.x*dimensionless_observer_three_vector.x \
              + 2.0f*kerr_g_inv_xy(f, k_x, k_y)*dimensionless_observer_three_vector.x*dimensionless_observer_three_vector.y \
              + 2.0f*kerr_g_inv_xz(f, k_x, k_z)*dimensionless_observer_three_vector.x*dimensionless_observer_three_vector.z \
              + kerr_g_inv_yy(f, k_y)*dimensionless_observer_three_vector.y*dimensionless_observer_three_vector.y \
              + 2.0f*kerr_g_inv_yz(f, k_y, k_z)*dimensionless_observer_three_vector.y*dimensionless_observer_three_vector.z \
              + kerr_g_inv_zz(f, k_z)*dimensionless_observer_three_vector.z*dimensionless_observer_three_vector.z \
              - squared_norm;

        return (-B - sqrtf(B*B - 4.0f*A*C))/(2.0f*A);
    }

    MAGIK_DEVICE_HOST static constexpr vec4f kerr_object_velocity_from_ZAMO_to_global(vec4f dimensionless_four_position, contravariant_seed_vectors_t seed_vectors, vec3f dimensionless_three_velocity, float dimensionless_spin_parameter)
    {
        float r = kerr_schild_r(dimensionless_four_position.x, dimensionless_four_position.y, dimensionless_four_position.z, dimensionless_spin_parameter);
        float r_sq = r * r;
        float a_sq = dimensionless_spin_parameter * dimensionless_spin_parameter;

        float cos_theta = dimensionless_four_position.y/r;
        float sin2_theta = 1.0f - cos_theta*cos_theta;
        float sigma = r_sq + a_sq*cos_theta*cos_theta;
        float delta = r_sq - 2.0f*r + a_sq;
        float Lambda = (r_sq + a_sq)*(r_sq + a_sq) - a_sq*delta*sin2_theta;
        float u_t = sqrtf(Lambda/(delta*sigma));
        float u_phi = 2.0f*dimensionless_spin_parameter*r/sqrtf(Lambda*delta*sigma);

        float u_x = dimensionless_four_position.z*u_phi;
        float u_y = 0.0f;
        float u_z = -dimensionless_four_position.x*u_phi;

        float squared_norm = -1.0f;
        vec4f ZAMO_four_velocity = vec4f{u_x, u_y, u_z, u_t};

        return kerr_observer_rest_frame_to_global(dimensionless_four_position, seed_vectors, dimensionless_three_velocity, ZAMO_four_velocity, dimensionless_spin_parameter, squared_norm);
    }



    /* Global to rest frame */
    MAGIK_DEVICE_HOST static constexpr vec4f kerr_global_to_observer_rest_frame(vec4f dimensionless_four_position, contravariant_seed_vectors_t seed_vectors, vec4f dimensionless_four_vector, vec4f dimensionless_observer_four_velocity, float dimensionless_spin_parameter)
    {
        vec4f covariant_seed_vectors_x = kerr_lower_index(dimensionless_four_position, seed_vectors.X, dimensionless_spin_parameter);
        vec4f covariant_seed_vectors_y = kerr_lower_index(dimensionless_four_position, seed_vectors.Y, dimensionless_spin_parameter);
        vec4f covariant_seed_vectors_z = kerr_lower_index(dimensionless_four_position, seed_vectors.Z, dimensionless_spin_parameter);

        vec4f e_t = -kerr_lower_index(dimensionless_four_position, dimensionless_observer_four_velocity, dimensionless_spin_parameter);

        vec4f e_z = covariant_seed_vectors_z + kerr_inner_product_covariant(dimensionless_four_position, covariant_seed_vectors_z, e_t, dimensionless_spin_parameter)*e_t;
        e_z = e_z / sqrtf(kerr_inner_product_covariant(dimensionless_four_position, e_z, e_z, dimensionless_spin_parameter));

        vec4f e_x = covariant_seed_vectors_x + kerr_inner_product_covariant(dimensionless_four_position, covariant_seed_vectors_x, e_t, dimensionless_spin_parameter)*e_t \
                                             - kerr_inner_product_covariant(dimensionless_four_position, covariant_seed_vectors_x, e_z, dimensionless_spin_parameter)*e_z;
        e_x = e_x / sqrtf(kerr_inner_product_covariant(dimensionless_four_position, e_x, e_x, dimensionless_spin_parameter));

        vec4f e_y = covariant_seed_vectors_y + kerr_inner_product_covariant(dimensionless_four_position, covariant_seed_vectors_y, e_t, dimensionless_spin_parameter)*e_t \
                                             - kerr_inner_product_covariant(dimensionless_four_position, covariant_seed_vectors_y, e_z, dimensionless_spin_parameter)*e_z \
                                             - kerr_inner_product_covariant(dimensionless_four_position, covariant_seed_vectors_y, e_x, dimensionless_spin_parameter)*e_x;
        e_y = e_y / sqrtf(kerr_inner_product_covariant(dimensionless_four_position, e_y, e_y, dimensionless_spin_parameter));

        vec4f result;
        result.t = e_t.t*dimensionless_four_position.t + e_t.x*dimensionless_four_position.x + e_t.y*dimensionless_four_position.y + e_t.z*dimensionless_four_position.z;
        result.x = e_x.t*dimensionless_four_position.t + e_x.x*dimensionless_four_position.x + e_x.y*dimensionless_four_position.y + e_x.z*dimensionless_four_position.z;
        result.y = e_y.t*dimensionless_four_position.t + e_y.x*dimensionless_four_position.x + e_y.y*dimensionless_four_position.y + e_y.z*dimensionless_four_position.z;
        result.z = e_z.t*dimensionless_four_position.t + e_z.x*dimensionless_four_position.x + e_z.y*dimensionless_four_position.y + e_z.z*dimensionless_four_position.z;
        return result;
    }



    /* Step function */
    MAGIK_DEVICE_HOST static constexpr geodesic_step_values kerr_geodesic_eq_rhs(const geodesic_step_values y0, const float dimensionless_spin_parameter)
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

        vec4f dqdt_lambda{ px - f_kTp * kx, py - f_kTp * ky, pz - f_kTp * kz, -pt - f_kTp };

        vec4f dpdt_lambda{ half_kTp_sq * dfdq_.x + f_kTp * beta.x, half_kTp_sq * dfdq_.y + f_kTp * beta.y, half_kTp_sq * dfdq_.z + f_kTp * beta.z, 0.0f };

        return geodesic_step_values{dqdt_lambda, dpdt_lambda};
    }



    /* Specialization */
    using kerr_metric = metric<e_magik_spacetime_metric_types::KERR>;

    template<> struct kerr_metric::params_t
    {
        float mass_parameter;
        float dimensionless_spin_parameter;
        float event_horizon_scalar;
    };

    template<> inline MAGIK_DEVICE_HOST float kerr_metric::length_scale(params_t p)
    {
        return magik::gravitational_constant * p.mass_parameter / (magik::speed_of_light*magik::speed_of_light);
    }

    template<> inline MAGIK_DEVICE_HOST geodesic_step_values kerr_metric::solve_step(geodesic_step_values y0, params_t p)
    {
        return kerr_geodesic_eq_rhs(y0, p.dimensionless_spin_parameter);
    }

    template<> inline MAGIK_DEVICE_HOST bool kerr_metric::in_domain(vec4f dimensionless_four_position, params_t p)
    {
        if(fabsf(p.dimensionless_spin_parameter) > 1.0f) return false;
        float r = kerr_schild_r(dimensionless_four_position.x, dimensionless_four_position.y, dimensionless_four_position.z, p.dimensionless_spin_parameter);
        if(((1.0f + sqrtf(1.0f - p.dimensionless_spin_parameter*p.dimensionless_spin_parameter)) * p.event_horizon_scalar) < r) return false;
        return true;
    }

    template<> inline MAGIK_DEVICE_HOST float kerr_metric::contravariant_timelike_component(vec4f dimensionless_four_position, vec3f dimensionless_observer_three_vector, float squared_norm, params_t p)
    {
        return kerr_compute_timelike_component_contravariant(dimensionless_four_position, dimensionless_observer_three_vector, p.dimensionless_spin_parameter, squared_norm);
    }

    template<> inline MAGIK_DEVICE_HOST vec4f kerr_metric::raise_index(vec4f dimensionless_four_position, vec4f covariant_vector, params_t p)
    {
        return kerr_raise_index(dimensionless_four_position, covariant_vector, p.dimensionless_spin_parameter);
    }

    template<> inline MAGIK_DEVICE_HOST vec4f kerr_metric::rest_frame_four_velocity(vec4f dimensionless_four_position, contravariant_seed_vectors_t seed_vectors, vec3f dimensionless_three_velocity, params_t p)
    {
        return kerr_object_velocity_from_ZAMO_to_global(dimensionless_four_position, seed_vectors, dimensionless_three_velocity, p.dimensionless_spin_parameter);
    }

    template<> inline MAGIK_DEVICE_HOST vec4f kerr_metric::global_to_observer_rest_frame(vec4f dimensionless_four_position, contravariant_seed_vectors_t seed_vectors, vec4f dimensionless_four_vector, vec4f dimensionless_observer_four_velocity, params_t p)
    {
        return kerr_global_to_observer_rest_frame(dimensionless_four_position, seed_vectors, dimensionless_four_vector, dimensionless_observer_four_velocity, p.dimensionless_spin_parameter);
    }

    template<> inline MAGIK_DEVICE_HOST vec4f kerr_metric::rest_frame_direction_to_global_four_momentum(vec4f dimensionless_four_position, contravariant_seed_vectors_t seed_vectors, vec3f dimensionless_spatial_vector, vec4f dimensionless_observer_four_velocity, float squared_norm, params_t p)
    {
        vec4f vector = kerr_observer_rest_frame_to_global(dimensionless_four_position, seed_vectors, dimensionless_spatial_vector, dimensionless_observer_four_velocity, p.dimensionless_spin_parameter, squared_norm);
        return kerr_raise_index(dimensionless_four_position, vector, p.dimensionless_spin_parameter);
    }
}
