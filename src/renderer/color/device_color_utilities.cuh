#pragma once

#include "internal_math.h"
#include <curand_kernel.h>
#include "color_pipeline.cuh"

namespace magik
{
    struct radiance_to_irradiance_args_t
    {
        float spectral_radiance;
        float monte_carlo_weight;
        float sensor_width_mm;
        float sensor_height_mm;
        float iso;
        float fps;
        float shutter_angle;
        uint32_t sensor_resolution_x;
        uint32_t sensor_resolution_y;
    };

    __device__ __inline__ static float radiance_to_irradiance(radiance_to_irradiance_args_t args)
    {
        float sensor_area = (args.sensor_width_mm * args.sensor_height_mm) / 1e6f;
        float n_pixel = static_cast<float>(args.sensor_resolution_x * args.sensor_resolution_y);
        float numerator = args.spectral_radiance * args.monte_carlo_weight * (sensor_area / n_pixel) * args.iso * 2.0f * magik::pi;
        float denominator = (360.0f * args.fps) / args.shutter_angle;
        return numerator / denominator;
    }

    struct redistribute_spectral_radiance_args_t
    {
        float* d_intrinsic_spectral_irradiance;
        float spectral_radiance; 
        float monte_carlo_weight; 
        float sensor_wavelength_nm; 
        float isi_max_wavelength_nm; 
        float isi_min_wavelength_nm; 
        float redistribution_standard_deviation;
        float sensor_width_mm;
        float sensor_height_mm;
        float iso = 1000.0f; 
        float fps = 24.0f; 
        float shutter_angle = 180.0f;
        uint32_t ray_id;
        uint32_t sensor_resolution_x; 
        uint32_t sensor_resolution_y; 
        uint32_t n_isi_bin;
    };

    __device__ __inline__ static void redistribute_spectral_radiance(redistribute_spectral_radiance_args_t args)
    {
        size_t spectral_irradiance_id = (size_t)args.ray_id * args.n_isi_bin;

        float wavelength_range_in_bin_nm = (args.isi_max_wavelength_nm - args.isi_min_wavelength_nm) / static_cast<float>(args.n_isi_bin);
        float x1 = args.isi_min_wavelength_nm;
        float x2 = args.isi_min_wavelength_nm + wavelength_range_in_bin_nm;
        float sampled_irradiance = radiance_to_irradiance({args.spectral_radiance, args.monte_carlo_weight, args.sensor_width_mm, args.sensor_height_mm, args.iso, args.fps, args.shutter_angle, args.sensor_resolution_x, args.sensor_resolution_y});
        float x_stored_irradiance = 0.0f;

        for(size_t i = 0; i < args.n_isi_bin; i++)
        {
            x_stored_irradiance = args.d_intrinsic_spectral_irradiance[spectral_irradiance_id + i];
            x_stored_irradiance += sampled_irradiance * (magik::norm_gaussian_cdf(args.sensor_wavelength_nm, x2, args.redistribution_standard_deviation) - magik::norm_gaussian_cdf(args.sensor_wavelength_nm, x1, args.redistribution_standard_deviation));
            /* Intrinsic sensor response function goes here */ 
            args.d_intrinsic_spectral_irradiance[spectral_irradiance_id + i] = x_stored_irradiance;

            x1 += wavelength_range_in_bin_nm;
            x2 += wavelength_range_in_bin_nm;
        }
    }

    struct intrinsic_spectral_irradiance_to_color_args_t
    {
        uint32_t n_isi_bin;
        uint32_t ray_id;
        float* d_intrinsic_spectral_irradiance;
        const vec3f* isi_to_scene_referred_weights;
        uint32_t x_sample;
    };

    __device__ __inline__ static vec3f intrinsic_spectral_irradiance_to_scene_color(intrinsic_spectral_irradiance_to_color_args_t args)
    {
        size_t spectral_irradiance_id = (size_t)args.ray_id * args.n_isi_bin;
        vec3f result_color = vec3f{0.0f, 0.0f, 0.0f}, cmf_weights = vec3f{0.0f, 0.0f, 0.0f};
        float x_intrinsic_spectral_irradiance = 0.0f;
        
        for(uint32_t i = 0; i < args.n_isi_bin; i++)
        {
            x_intrinsic_spectral_irradiance = args.d_intrinsic_spectral_irradiance[spectral_irradiance_id + i];
            cmf_weights = args.isi_to_scene_referred_weights[i];
            result_color += vec3f{x_intrinsic_spectral_irradiance, x_intrinsic_spectral_irradiance, x_intrinsic_spectral_irradiance} * cmf_weights;
        }

        return result_color / static_cast<float>(args.x_sample + 1);
    }

    __device__ __inline__ static vec3f scene_to_display_referred_color(vec3f scene_color, const color_pipeline_descriptor_t& descriptor)
    {
        vec3f display_color = {0.0f, 0.0f, 0.0f};

        bool successful_tonemapper = dispatch_list(supported_view_transforms{}, descriptor.view_transform_descriptor.type, [&](auto tag)
        {
            constexpr auto T = decltype(tag)::value;
            display_color = generic_view_transform_t<T>::apply(scene_color, descriptor.view_transform_descriptor.params);
        });

        display_color = descriptor.scene_to_display_referred * display_color;

        bool successful_encode = dispatch_list(supported_display_colorspaces{}, descriptor.display_colorspace_type, [&](auto tag)
        {
            constexpr auto T = decltype(tag)::value;
            display_color = generic_display_colorspace_t<T>::encode(display_color);
        });

        return display_color;
    }

    // Quantization 
}