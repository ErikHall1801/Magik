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
        float iso; 
        float fps; 
        float shutter_angle;
        uint32_t sensor_resolution_x; 
        uint32_t sensor_resolution_y; 
        uint32_t n_spectral_irradiance_bin;
    };

    __device__ __inline__ static void redistribute_spectral_radiance(redistribute_spectral_radiance_t* args)
    {
        uint32_t thread_id = get_thread_id(args->sensor_resolution_x);
        uint32_t spectral_irradiance_id = get_n_dimensional_thread_id(args->sensor_resolution_x, args->n_spectral_irradiance_bin);

        float wavelength_range_in_bin_nm = (args->max_wavelength_nm - args->min_wavelength_nm) / static_cast<float>(args->n_spectral_irradiance_bin);
        float x1 = args->min_wavelength_nm;
        float x2 = args->min_wavelength_nm + wavelength_range_in_bin_nm;

        float redistribution_weight = 0.0f;

        for(size_t i = 0; i < args->n_spectral_irradiance_bin; i++)
        {
            redistribution_weight = magik::norm_gaussian_cdf(args->sensor_wavelength_nm, x2, args->redistribution_standard_deviation) - magik::norm_gaussian_cdf(args->sensor_wavelength_nm, x1, args->redistribution_standard_deviation);

            // Do note, we are missing the intrinisc sensor response here !!! 
            args->d_spectral_irradiance[spectral_irradiance_id + i] += radiance_to_irradiance(args->spectral_radiance, args->monte_carlo_weight, args->sensor_width_mm, args->sensor_height_mm, args->iso, args->fps, args->shutter_angle, args->sensor_resolution_x, args->sensor_resolution_y);

            x1 += wavelength_range_in_bin_nm;
            x2 += wavelength_range_in_bin_nm;
        }
    }

    __device__ float tmp_cie_data[95] = { 46.6383f, 49.3637f, 52.0891f, 51.0323f, 49.9755f, 52.3118f, 54.6482f, 68.7015f, 2.7549f, 87.1204f, 91.486f, 92.4589f, 93.4318f, 90.057f, 86.6823f, 95.7736f, 104.865f, 110.936f, 117.008f, 117.41f, 117.812f, 116.336f, 114.861f, 115.392f, 115.923f, 112.367f, 108.811f, 109.082f, 109.354f, 108.578f, 107.802f, 106.296f, 104.79f, 106.239f, 107.689f, 106.047f, 104.405f, 104.225f, 104.046f, 102.023f, 100.0f, 98.1671f, 96.3342f, 96.0611f, 95.788f, 92.2368f, 88.6856f, 89.3459f, 90.0062f, 89.8026f, 89.5991f, 88.6489f, 87.6987f, 85.4936f, 83.2886f, 83.4939f, 83.6992f, 81.863f, 80.0268f, 80.1207f, 80.2146f, 81.2462f, 82.2778f, 80.281f, 78.2842f, 74.0027f, 69.7213f, 70.6652f, 71.6091f, 72.979f, 74.349f, 67.9765f, 61.604f, 65.7448f, 69.8856f, 72.4863f, 75.087f, 69.3398f, 63.5927f, 55.0054f, 46.4182f, 56.6118f, 66.8054f, 65.0941f, 63.3828f, 63.8434f, 64.304f, 61.8779f, 59.4519f, 55.7054f, 51.959f,  54.6998f, 57.4406f, 58.8765f, 60.3125f };

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

    __device__ __inline__ static vec3f spectral_irradiance_to_cie_xyz(float* d_intrinsic_spectral_irradiance, uint32_t n_spectral_irradiance_bin, float wavelength_nm, float max_wavelength_nm, float min_wavelength_nm, uint32_t x_sample)
    {
        vec3f linear_color, cie_color_matching_function_values;
        float x_intrinsic_spectral_irradiance = 0.0f;

        for(size_t i = 0; i < n_spectral_irradiance_bin; i++)
        {
            x_intrinsic_spectral_irradiance = d_intrinsic_spectral_irradiance[i];
            cie_color_matching_function_values = sample_cie_data(wavelength_nm, max_wavelength_nm, min_wavelength_nm, 95, 3);

            linear_color.x += x_intrinsic_spectral_irradiance * cie_color_matching_function_values.x;
            linear_color.y += x_intrinsic_spectral_irradiance * cie_color_matching_function_values.y;
            linear_color.z += x_intrinsic_spectral_irradiance * cie_color_matching_function_values.z;
        }

        return linear_color / static_cast<float>(x_sample + 1);
    }
}
