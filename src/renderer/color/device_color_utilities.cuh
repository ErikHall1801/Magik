#pragma once

#include "internal_math.h"
#include <curand_kernel.h>
#include "color_pipeline.h"

namespace magik
{
    struct radiance_to_irradiance_args_t
    {
        float spectral_radiance;
        float throughput;
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
        float numerator = args.spectral_radiance * args.throughput * (sensor_area / n_pixel) * args.iso * 2.0f * magik::pi;
        float denominator = (360.0f * args.fps) / args.shutter_angle;
        return numerator / denominator;
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

    template<e_magik_view_transform_types T> __device__ __inline__ static vec3f scene_to_display_referred_color(typename generic_view_transform_t<T>::params_t view_transform_params, vec3f scene_color, const color_pipeline_descriptor_t& descriptor)
    {
        vec3f display_color = {0.0f, 0.0f, 0.0f};

        display_color = generic_view_transform_t<T>::apply(scene_color, view_transform_params);

        display_color = descriptor.scene_to_display_referred * display_color;

        bool successful_encode = dispatch_list(supported_display_colorspaces{}, descriptor.display_colorspace_type, [&](auto tag)
        {
            constexpr auto D = decltype(tag)::value;
            display_color = generic_display_colorspace_t<D>::encode(display_color);
        });

        return display_color;
    }

    // Quantization 
}