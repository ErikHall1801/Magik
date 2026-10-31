#pragma once

#include <cstdint>
#include "internal_math.h"
#include "cuda_device_utilities.cuh"
#include "cuda_runtime.h"
#include <curand_kernel.h>
#include "curand.h"

namespace magik
{
    /*
    This header file consolidates the various spectral functions Magik 
    needs to operate. I have put it under "color" because, realistically
    , once we add the OCIO logic an independent directory will be needed. 
    And it seems like spectral and color are closely enough related to 
    validate this. 
    */

    __device__ __inline__ static float compute_random_wavelength(float max_wavelength_nm, float min_wavelength_nm, curandState_t* random_state)
    {
        return magik::lerp(min_wavelength_nm, max_wavelength_nm, curand_uniform(random_state));
    }

    __device__ __inline__ static float radiance_to_irradiance(float spectral_radiance, float monte_carlo_weight, float sensor_width_mm, float sensor_height_mm, float iso, float fps, float shutter_angle, uint32_t sensor_resolution_x, uint32_t sensor_resolution_y)
    {
        float sensor_area = (sensor_width_mm * sensor_height_mm) / 1e6f;
        float n_pixel = static_cast<float>(sensor_resolution_x * sensor_resolution_y);
        float numerator = spectral_radiance * monte_carlo_weight * (sensor_area / n_pixel) * iso * 2.0f * magik::pi;
        float denominator = (360.0f * fps) / shutter_angle;
        return numerator / denominator;
    }

    struct redistribute_spectral_radiance_t
    {
        float* d_spectral_irradiance;
        float spectral_radiance; 
        float monte_carlo_weight; 
        float sensor_wavelength_nm; 
        float max_wavelength_nm; 
        float min_wavelength_nm; 
        float redistribution_standard_deviation;
        float sensor_width_mm;
        float sensor_height_mm;
        float iso = 1.0f; 
        float fps = 24.0f; 
        float shutter_angle = 180.0f;
        uint32_t ray_id;
        uint32_t sensor_resolution_x; 
        uint32_t sensor_resolution_y; 
        uint32_t n_spectral_irradiance_bin;
    };

    __device__ __inline__ static void redistribute_spectral_radiance(redistribute_spectral_radiance_t* args)
    {
        size_t spectral_irradiance_id = (size_t)args->ray_id * args->n_spectral_irradiance_bin;

        float wavelength_range_in_bin_nm = (args->max_wavelength_nm - args->min_wavelength_nm) / static_cast<float>(args->n_spectral_irradiance_bin);
        float x1 = args->min_wavelength_nm;
        float x2 = args->min_wavelength_nm + wavelength_range_in_bin_nm;
        float sampled_irradiance = radiance_to_irradiance(args->spectral_radiance, args->monte_carlo_weight, args->sensor_width_mm, args->sensor_height_mm, args->iso, args->fps, args->shutter_angle, args->sensor_resolution_x, args->sensor_resolution_y);
        float x_stored_irradiance = 0.0f;

        for(size_t i = 0; i < args->n_spectral_irradiance_bin; i++)
        {
            x_stored_irradiance = args->d_spectral_irradiance[spectral_irradiance_id + i];
            x_stored_irradiance += sampled_irradiance * (magik::norm_gaussian_cdf(args->sensor_wavelength_nm, x2, args->redistribution_standard_deviation) - magik::norm_gaussian_cdf(args->sensor_wavelength_nm, x1, args->redistribution_standard_deviation));
            // Do note, we are missing the intrinisc sensor response here !!! 
            args->d_spectral_irradiance[spectral_irradiance_id + i] = x_stored_irradiance;

            x1 += wavelength_range_in_bin_nm;
            x2 += wavelength_range_in_bin_nm;
        }
    }

    __device__ float tmp_cie_data[285] = {0.000129900000f, 0.000003917000f, 0.000606100017f, 0.000232100007f, 0.000006965000f, 0.001086000004f, 0.000414899987f, 0.000012390000f, 0.001946000033f, 0.000741600001f, 0.000022020000f, 0.003486000001f, 0.001368000056f, 0.000038999999f, 0.006450001150f, 0.002236000029f, 0.000064000000f, 0.010549990460f, 0.004242999945f, 0.000119999997f, 0.020050009713f, 0.007650000043f, 0.000216999993f, 0.036210000515f, 0.014310000464f, 0.000395999989f, 0.067850008607f, 0.023189999163f, 0.000639999984f, 0.110200002789f, 0.043510001153f, 0.001210000017f, 0.207399994135f, 0.077629998326f, 0.002180000069f, 0.371300011873f, 0.134379997849f, 0.004000000190f, 0.645600020885f, 0.214770004153f, 0.007300000172f, 1.039050102234f, 0.283899992704f, 0.011599999852f, 1.385599970818f, 0.328500002623f, 0.016839999706f, 1.622959971428f, 0.348280012608f, 0.023000000045f, 1.747059941292f, 0.348060011864f, 0.029799999669f, 1.782600045204f, 0.336199998856f, 0.037999998778f, 1.772109985352f, 0.318699985743f, 0.048000000417f, 1.744099974632f, 0.290800005198f, 0.059999998659f, 1.669199943542f, 0.251100003719f, 0.073899999261f, 1.528100013733f, 0.195360004902f, 0.090980000794f, 1.287639975548f, 0.142100006342f, 0.112599998713f, 1.041900038719f, 0.095640003681f, 0.139019995928f, 0.812950074673f, 0.057950008661f, 0.169300004840f, 0.616199970245f, 0.032010000199f, 0.208020001650f, 0.465180009604f, 0.014700000174f, 0.258599996567f, 0.353300005198f, 0.004900000058f, 0.323000013828f, 0.272000014782f, 0.002400000114f, 0.407299995422f, 0.212300002575f, 0.009300000034f, 0.503000020981f, 0.158199995756f, 0.029100000858f, 0.608200013638f, 0.111699998379f, 0.063270002604f, 0.709999978542f, 0.078249990940f, 0.109600000083f, 0.793200016022f, 0.057250011712f, 0.165500000119f, 0.861999988556f, 0.042160000652f, 0.225749894977f, 0.914850115776f, 0.029839999974f, 0.290399998426f, 0.953999996185f, 0.020300000906f, 0.359699994326f, 0.980300009251f, 0.013399999589f, 0.433449894190f, 0.994950115681f, 0.008749999106f, 0.512050092220f, 1.000000000000f, 0.005749999080f, 0.594500005245f, 0.995000004768f, 0.003899999894f, 0.678399980068f, 0.978600025177f, 0.002749999054f, 0.762099981308f, 0.952000021935f, 0.002099999925f, 0.842499971390f, 0.915400028229f, 0.001799999969f, 0.916299998760f, 0.870000004768f, 0.001650001039f, 0.978600025177f, 0.816299974918f, 0.001399999950f, 1.026299953461f, 0.757000029087f, 0.001099999994f, 1.056699991226f, 0.694899976254f, 0.001000000047f, 1.062199950218f, 0.630999982357f, 0.000799999980f, 1.045600056648f, 0.566799998283f, 0.000600000028f, 1.002599954605f, 0.503000020981f, 0.000339999999f, 0.938399970531f, 0.441199988127f, 0.000239999994f, 0.854449927807f, 0.381000012159f, 0.000190000006f, 0.751399993896f, 0.321000009775f, 0.000099999997f, 0.642400026321f, 0.264999985695f, 0.000049999991f, 0.541899979115f, 0.216999992728f, 0.000029999999f, 0.447899997234f, 0.174999997020f, 0.000019999999f, 0.360799998045f, 0.138199999928f, 0.000010000000f, 0.283499985933f, 0.107000000775f, 0.000000000000f, 0.218700006604f, 0.081600002944f, 0.000000000000f, 0.164900004864f, 0.061000000685f, 0.000000000000f, 0.121200002730f, 0.044580001384f, 0.000000000000f, 0.087399996817f, 0.032000001520f, 0.000000000000f, 0.063600003719f, 0.023199999705f, 0.000000000000f, 0.046769998968f, 0.017000000924f, 0.000000000000f, 0.032900001854f, 0.011920000426f, 0.000000000000f, 0.022700000554f, 0.008209999651f, 0.000000000000f, 0.015839999542f, 0.005723000038f, 0.000000000000f, 0.011359159835f, 0.004102000035f, 0.000000000000f, 0.008110916242f, 0.002928999951f, 0.000000000000f, 0.005790345836f, 0.002091000089f, 0.000000000000f, 0.004109457135f, 0.001484000008f, 0.000000000000f, 0.002899327083f, 0.001047000056f, 0.000000000000f, 0.002049189992f, 0.000739999989f, 0.000000000000f, 0.001439971034f, 0.000520000001f, 0.000000000000f, 0.000999949290f, 0.000361100014f, 0.000000000000f, 0.000690078596f, 0.000249200006f, 0.000000000000f, 0.000476021291f, 0.000171899999f, 0.000000000000f, 0.000332301104f, 0.000119999997f, 0.000000000000f, 0.000234826104f, 0.000084799998f, 0.000000000000f, 0.000166150494f, 0.000059999998f, 0.000000000000f, 0.000117413001f, 0.000042399999f, 0.000000000000f, 0.000083075269f, 0.000029999999f, 0.000000000000f, 0.000058706519f, 0.000021200000f, 0.000000000000f, 0.000041509938f, 0.000014990000f, 0.000000000000f, 0.000029353259f, 0.000010600000f, 0.000000000000f, 0.000020673830f, 0.000007465700f, 0.000000000000f, 0.000014559770f, 0.000005257800f, 0.000000000000f, 0.000010253980f, 0.000003702900f, 0.000000000000f, 0.000007221456f, 0.000002607800f, 0.000000000000f, 0.000005085868f, 0.000001836600f, 0.000000000000f, 0.000003581652f, 0.000001293400f, 0.000000000000f, 0.000002522525f, 0.000000910930f, 0.000000000000f, 0.000001776509f, 0.000000641530f, 0.000000000000f, 0.000001251141f, 0.000000451810f, 0.000000000000f };

    __device__ __inline__ static vec3f sample_cie_data(float sample_wavelength_nm, float max_wavelength_nm, float min_wavelength_nm, int n_entry, int n_dimension)
    {
        if(sample_wavelength_nm < min_wavelength_nm || sample_wavelength_nm > max_wavelength_nm) return vec3f{1e-5f, 1e-5f, 1e-5f};

        unsigned int effective_entries = (n_entry) / n_dimension;
        float wavelength_range_fraction = (sample_wavelength_nm - min_wavelength_nm) / (max_wavelength_nm - min_wavelength_nm);
        float float_idx = wavelength_range_fraction * static_cast<float>(effective_entries - 1);
        unsigned int i_group = static_cast<unsigned int>(floorf(float_idx));
        if (i_group >= effective_entries - 1) i_group = effective_entries - 2;

        vec3f r_near = vec3f{ tmp_cie_data[(i_group + 0) * (n_dimension) + 0], tmp_cie_data[(i_group + 0) * (n_dimension) + 1], tmp_cie_data[(i_group + 0) * (n_dimension) + 2]};
        vec3f r_far = vec3f{ tmp_cie_data[(i_group + 1) * (n_dimension) + 0], tmp_cie_data[(i_group + 1) * (n_dimension) + 1], tmp_cie_data[(i_group + 1) * (n_dimension) + 2]};

        float t = float_idx - static_cast<float>(i_group);

        return magik::lerp(r_near, r_far, t);
    }

    __device__ __inline__ static vec3f spectral_irradiance_to_cie_xyz(float* d_intrinsic_spectral_irradiance, uint32_t n_spectral_irradiance_bin, float max_wavelength_nm, float min_wavelength_nm, uint32_t x_sample)
    {
        vec3f linear_color, cie_color_matching_function_values;
        float wavelength_range_in_bin_nm = (max_wavelength_nm - min_wavelength_nm) / static_cast<float>(n_spectral_irradiance_bin);
        float x_intrinsic_spectral_irradiance = 0.0f, x_wavelength = min_wavelength_nm + wavelength_range_in_bin_nm * 0.5f;

        for(size_t i = 0; i < n_spectral_irradiance_bin; i++)
        {
            x_intrinsic_spectral_irradiance = d_intrinsic_spectral_irradiance[i];
            cie_color_matching_function_values = sample_cie_data(x_wavelength, max_wavelength_nm, min_wavelength_nm, 285, 3);

            linear_color.x += x_intrinsic_spectral_irradiance * cie_color_matching_function_values.x;
            linear_color.y += x_intrinsic_spectral_irradiance * cie_color_matching_function_values.y;
            linear_color.z += x_intrinsic_spectral_irradiance * cie_color_matching_function_values.z;

            x_wavelength += wavelength_range_in_bin_nm;
        }

        return linear_color / static_cast<float>(x_sample + 1);
    }
}
