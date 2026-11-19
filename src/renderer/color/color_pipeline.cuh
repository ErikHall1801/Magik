#pragma once

#include "magik.h"
#include "cuda_host_device_utilities.h"
#include "internal_math.h"
#include "colorspaces.cuh"
#include "view_transform.cuh"
#include "color_matching_functions.cuh"

#define MAGIK_N_MAX_SPECTRAL_BIN 64

namespace magik
{
    __host__ static inline vec3f cie_xy_to_cie_XYZ(vec2f cie_xy)
    {
        return {cie_xy.x / cie_xy.y, 1.0f, (1.0f - cie_xy.x - cie_xy.y) / cie_xy.y};
    }

    __host__ static inline vec2f cie_XYZ_to_cie_uv(vec3f cie_XYZ)
    {
        return { 4.0f*cie_XYZ.x / (cie_XYZ.x + 15.0f*cie_XYZ.y + 3.0f*cie_XYZ.z), 6.0f*cie_XYZ.y / (cie_XYZ.x + 15.0f*cie_XYZ.y + 3.0f*cie_XYZ.z) };
    }

    __host__ static inline vec2f cie_uv_to_cie_xy(vec2f cie_uv)
    {
        return { 3.0f*cie_uv.x / (2.0f*cie_uv.x - 8.0f*cie_uv.y + 4.0f), 2.0f*cie_uv.y / (2.0f*cie_uv.x - 8.0f*cie_uv.y + 4.0f) };
    }

    __host__ static vec3f compute_white_point_xyz(float temperature, float tint, uint32_t cmf_n_entries, float cmf_min_wavelength_nm, float cmf_max_wavelength_nm, const vec3f* cmf_values)
    {
        vec3f blackbody_xyz{}, blackbody_xyz_dT{};
        vec3f x_cmf_values; 
        float x_wavelength_nm = cmf_min_wavelength_nm;
        float x_wavelength_range = (cmf_max_wavelength_nm - cmf_min_wavelength_nm) / static_cast<float>(cmf_n_entries - 1);

        for(uint32_t i = 0; i < cmf_n_entries; i++)
        {
            x_cmf_values = sample_equidistant_spectral_data(cmf_values, cmf_n_entries, cmf_min_wavelength_nm, cmf_max_wavelength_nm, x_wavelength_nm);
            blackbody_xyz += x_cmf_values * sample_plancks_law(x_wavelength_nm, temperature);
            blackbody_xyz_dT += x_cmf_values * sample_plancks_law(x_wavelength_nm, temperature + 1);
            x_wavelength_nm += x_wavelength_range;
        }

        blackbody_xyz /= blackbody_xyz.y;
        blackbody_xyz_dT /= blackbody_xyz_dT.y;

        vec2f cie_uv_0 = cie_XYZ_to_cie_uv(blackbody_xyz);
        vec2f cie_uv_1 = cie_XYZ_to_cie_uv(blackbody_xyz_dT);
        vec2f n_locus = (cie_uv_1-cie_uv_0).norm();
        n_locus = {-n_locus.y, n_locus.x};

        if(n_locus.y < 0.0f) n_locus *= -1.0f;

        vec2f cie_uv_prime = cie_uv_0 + n_locus * tint;
        vec2f cie_xy = cie_uv_to_cie_xy(cie_uv_prime);
        return cie_xy_to_cie_XYZ(cie_xy);
    }

    __host__ static inline mat3f chromatic_adaptation(vec3f white_point_src_cie_xyz, vec3f white_point_dst_cie_xyz)
    {
        constexpr mat3f m_cat = {0.8951f, 0.2664f, -0.1614f, -0.7502f, 1.7135f, 0.0367f, 0.0389f, -0.0685f, 1.0296f};
        constexpr mat3f m_cat_inv = {0.9869929f, -0.1470543f, 0.1599627f, 0.4323053f, 0.5183603f, 0.0492912f, -0.0085287f, 0.0400428f, 0.9684867f};

        vec3f lms_src = m_cat * white_point_src_cie_xyz;
        vec3f lms_dst = m_cat * white_point_dst_cie_xyz;

        return m_cat_inv * mat3f{lms_dst.x / lms_src.x, 0.0f, 0.0f, 0.0f, lms_dst.y / lms_src.y, 0.0f, 0.0f, 0.0f, lms_dst.z / lms_src.z} * m_cat;
    }

    __host__ static inline void compute_normalized_isi_cmf_weights(vec3f* isi_to_scene_referred_weights, uint32_t n_isi_bin, float isi_min_wavelength_nm, float isi_max_wavelength_nm, const vec3f* cmf_values, uint32_t cmf_n_entries, float cmf_min_wavelength_nm, float cmf_max_wavelength_nm)
    {
        vec3f w = {0.0f, 0.0f, 0.0f};
        float sum_y = 0.0f;

        float isi_bin_range = (isi_max_wavelength_nm - isi_min_wavelength_nm) / static_cast<float>(n_isi_bin);
        float cmf_bin_range = (cmf_max_wavelength_nm - cmf_min_wavelength_nm) / static_cast<float>(cmf_n_entries - 1);
        uint32_t sub_range_steps = static_cast<uint32_t>(ceilf(isi_bin_range / cmf_bin_range));
        float x_wavelength_sub_range_nm = isi_bin_range / static_cast<float>(sub_range_steps);
        float x_wavelength_nm_isi_bin, x_wavelenght_nm_sub_range;

        for(uint32_t i = 0; i < n_isi_bin; i++)
        {
            x_wavelength_nm_isi_bin = isi_min_wavelength_nm + i * isi_bin_range;

            for(uint32_t j = 0; j < sub_range_steps; j++)
            {
                x_wavelenght_nm_sub_range = x_wavelength_nm_isi_bin + (j + 0.5f)*x_wavelength_sub_range_nm;
                w += sample_equidistant_spectral_data(cmf_values, cmf_n_entries, cmf_min_wavelength_nm, cmf_max_wavelength_nm, x_wavelenght_nm_sub_range) * x_wavelength_sub_range_nm;
            }

            isi_to_scene_referred_weights[i] = w;
            sum_y += w.y;
            w = {0.0f, 0.0f, 0.0f};
        }

        float k = 1.0f / sum_y;

        for(uint32_t i = 0; i < n_isi_bin; i++)
        {
            isi_to_scene_referred_weights[i] *= k;
        }
    }

    __host__ static inline void fold_XYZ_to_scene_matrix_into_isi(vec3f* isi_to_scene_referred_weights, uint32_t n_isi_bin, mat3f XYZ_to_scene)
    {
        for(uint32_t i = 0; i < n_isi_bin; i++)
        {
            isi_to_scene_referred_weights[i] = XYZ_to_scene * isi_to_scene_referred_weights[i];
        }
    }

    struct color_pipeline_settings_t
    {
        uint32_t n_isi_bin;
        e_magik_scene_colorspace_types scene_colorspace_type;
        e_magik_display_colorspace_types display_colorspace_type;
        e_magik_view_transform_types view_transform;
        e_magik_output_format_types output_format;
        float white_point;
        float tint;
        float isi_min_wavelength_nm;
        float isi_max_wavelength_nm;
        e_magik_color_matching_function_types cmf_type;
    };

    struct color_pipeline_descriptor_t
    {
        uint32_t n_spectral_bin;
        view_transform_descriptor_t view_transform_descriptor;
        vec3f isi_to_scene_referred_weights[MAGIK_N_MAX_SPECTRAL_BIN];
        e_magik_display_colorspace_types display_colorspace_type;
        float peak_nits;
        mat3f scene_to_display_referred;
        e_magik_output_format_types output_format;

        static __host__ color_pipeline_descriptor_t create(color_pipeline_settings_t settings)
        {
            color_pipeline_descriptor_t result;

            // Extract number of spectral bins - This should be replaced by a command-level constraint ! 
            result.n_spectral_bin = settings.n_isi_bin > MAGIK_N_MAX_SPECTRAL_BIN ? MAGIK_N_MAX_SPECTRAL_BIN : settings.n_isi_bin;

            // Fold the scene referred colorspace into the CMF
            mat3f XYZ_to_scene_colorspace, scene_colorspace_to_XYZ;
            vec2f scene_white_point_cie_xy;

            bool successful_colorspace = dispatch_list(supported_scene_colorspaces{}, settings.scene_colorspace_type, [&](auto tag)
            {
                constexpr auto T = decltype(tag)::value;
                XYZ_to_scene_colorspace = generic_scene_colorspace_t<T>::XYZ_to_colorspace;
                scene_colorspace_to_XYZ = generic_scene_colorspace_t<T>::colorspace_to_XYZ;
                scene_white_point_cie_xy = generic_scene_colorspace_t<T>::white_point_cie_xy;
            });

            if(!successful_colorspace)
            {
                XYZ_to_scene_colorspace = generic_scene_colorspace_t<MAGIK_SCENE_COLORSPACE_CIE_XYZ>::XYZ_to_colorspace;
                scene_colorspace_to_XYZ = generic_scene_colorspace_t<MAGIK_SCENE_COLORSPACE_CIE_XYZ>::colorspace_to_XYZ;
                scene_white_point_cie_xy = generic_scene_colorspace_t<MAGIK_SCENE_COLORSPACE_CIE_XYZ>::white_point_cie_xy;
            }

            uint32_t cmf_n_entries;
            float cmf_min_wavelength_nm;
            float cmf_max_wavelength_nm;
            const vec3f* cmf_values;

            bool successful_cmf = dispatch_list(supported_color_matching_functions{}, settings.cmf_type, [&](auto tag)
            {
                constexpr auto T = decltype(tag)::value;
                cmf_n_entries = generic_color_matching_function_t<T>::n_entries;
                cmf_min_wavelength_nm = generic_color_matching_function_t<T>::min_wavelength_nm;
                cmf_max_wavelength_nm = generic_color_matching_function_t<T>::max_wavelength_nm;
                cmf_values = generic_color_matching_function_t<T>::values;
            });

            if(!successful_cmf)
            {
                cmf_n_entries = generic_color_matching_function_t<MAGIK_CMF_CIE_1931>::n_entries;
                cmf_min_wavelength_nm = generic_color_matching_function_t<MAGIK_CMF_CIE_1931>::min_wavelength_nm;
                cmf_max_wavelength_nm = generic_color_matching_function_t<MAGIK_CMF_CIE_1931>::max_wavelength_nm;
                cmf_values = generic_color_matching_function_t<MAGIK_CMF_CIE_1931>::values;
            }

            vec3f white_point_src_cie_xyz = compute_white_point_xyz(settings.white_point, settings.tint, cmf_n_entries, cmf_min_wavelength_nm, cmf_max_wavelength_nm, cmf_values);
            vec3f white_point_dst_cie_xyz = cie_xy_to_cie_XYZ(scene_white_point_cie_xy);
            mat3f XYZ_to_scene_white_balanced = XYZ_to_scene_colorspace * chromatic_adaptation(white_point_src_cie_xyz, white_point_dst_cie_xyz);

            compute_normalized_isi_cmf_weights(result.isi_to_scene_referred_weights, result.n_spectral_bin, settings.isi_min_wavelength_nm, settings.isi_max_wavelength_nm, cmf_values, cmf_n_entries, cmf_min_wavelength_nm, cmf_max_wavelength_nm);

            fold_XYZ_to_scene_matrix_into_isi(result.isi_to_scene_referred_weights, result.n_spectral_bin, XYZ_to_scene_white_balanced);

            // Scene to display referred 
            mat3f XYZ_to_display_colorspace;
            vec2f display_white_point_cie_xy;
            float display_peak_nits;

            bool successful_display_colorspace = dispatch_list(supported_display_colorspaces{}, settings.display_colorspace_type, [&](auto tag)
            {
                constexpr auto T = decltype(tag)::value;
                XYZ_to_display_colorspace = generic_display_colorspace_t<T>::XYZ_to_colorspace;
                display_white_point_cie_xy = generic_display_colorspace_t<T>::white_point_cie_xy;
                display_peak_nits = generic_display_colorspace_t<T>::peak_luminance;
            });

            if(!successful_display_colorspace)
            {
                XYZ_to_display_colorspace = generic_display_colorspace_t<MAGIK_DISPLAY_COLORSPACE_SRGB>::XYZ_to_colorspace;
                display_white_point_cie_xy = generic_display_colorspace_t<MAGIK_DISPLAY_COLORSPACE_SRGB>::white_point_cie_xy;
                display_peak_nits = generic_display_colorspace_t<MAGIK_DISPLAY_COLORSPACE_SRGB>::peak_luminance;
            }

            result.scene_to_display_referred = XYZ_to_display_colorspace * chromatic_adaptation(white_point_dst_cie_xyz, cie_xy_to_cie_XYZ(display_white_point_cie_xy)) * scene_colorspace_to_XYZ;

            // Create the view transform paramters
            view_transform_params_t view_transform_params;
            view_transform_params.reinhard_extended_white_luminance = 4.0f;
            view_transform_params.reinhard_extended_luminance_weights = vec3f{scene_colorspace_to_XYZ.m21, scene_colorspace_to_XYZ.m22, scene_colorspace_to_XYZ.m23};

            view_transform_params.khronos_pbr_neutral_start_compression = 0.8f;
            view_transform_params.khronos_pbr_neutral_desaturation = 0.15f;
            mat3f XYZ_to_rec709 = generic_display_colorspace_t<MAGIK_DISPLAY_COLORSPACE_REC709>::XYZ_to_colorspace;
            mat3f rec709_to_XYZ = generic_display_colorspace_t<MAGIK_DISPLAY_COLORSPACE_REC709>::colorspace_to_XYZ;
            mat3f cat_in = chromatic_adaptation(white_point_dst_cie_xyz, cie_xy_to_cie_XYZ(generic_display_colorspace_t<MAGIK_DISPLAY_COLORSPACE_REC709>::white_point_cie_xy));
            mat3f cat_out = chromatic_adaptation(cie_xy_to_cie_XYZ(generic_display_colorspace_t<MAGIK_DISPLAY_COLORSPACE_REC709>::white_point_cie_xy), white_point_dst_cie_xyz);
            view_transform_params.khronos_pbr_neutral_to_linear_rec_709 = XYZ_to_rec709 * cat_in * scene_colorspace_to_XYZ;
            view_transform_params.khronos_pbr_neutral_to_scene_colorspace = XYZ_to_scene_colorspace * cat_out * rec709_to_XYZ;

            result.view_transform_descriptor = view_transform_descriptor_t::create(settings.view_transform, view_transform_params);

            // Set remainers
            result.display_colorspace_type = settings.display_colorspace_type;
            result.peak_nits = display_peak_nits;
            result.output_format = settings.output_format;

            return result;
        }
    };
}
