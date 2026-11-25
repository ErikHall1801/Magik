#pragma once

#include "magik.h"
#include "internal_math.h"
#include "color_matching_functions.cuh"
#include "colorspaces.cuh"
#include <vector>

#define MAGIK_N_MAX_SPECTRAL_BIN 64
#define MAGIK_N_CMF_INVERSE_CDF_BIN 256

namespace magik
{
    static inline vec3f cie_xy_to_cie_XYZ(vec2f cie_xy)
    {
        return {cie_xy.x / cie_xy.y, 1.0f, (1.0f - cie_xy.x - cie_xy.y) / cie_xy.y};
    }

    static inline vec2f cie_XYZ_to_cie_uv(vec3f cie_XYZ)
    {
        return { 4.0f*cie_XYZ.x / (cie_XYZ.x + 15.0f*cie_XYZ.y + 3.0f*cie_XYZ.z), 6.0f*cie_XYZ.y / (cie_XYZ.x + 15.0f*cie_XYZ.y + 3.0f*cie_XYZ.z) };
    }

    static inline vec2f cie_uv_to_cie_xy(vec2f cie_uv)
    {
        return { 3.0f*cie_uv.x / (2.0f*cie_uv.x - 8.0f*cie_uv.y + 4.0f), 2.0f*cie_uv.y / (2.0f*cie_uv.x - 8.0f*cie_uv.y + 4.0f) };
    }

    static vec3f compute_white_point_xyz(float temperature, float tint, cmf_info_t cmf_info)
    {
        vec3f blackbody_xyz{}, blackbody_xyz_dT{};
        vec3f x_cmf_values; 
        float x_wavelength_nm = cmf_info.min_wavelength_nm;
        float x_wavelength_range = (cmf_info.max_wavelength_nm - cmf_info.min_wavelength_nm) / static_cast<float>(cmf_info.n_entries - 1);

        for(uint32_t i = 0; i < cmf_info.n_entries; i++)
        {
            x_cmf_values = sample_equidistant_spectral_data(cmf_info.values, cmf_info.n_entries, cmf_info.min_wavelength_nm, cmf_info.max_wavelength_nm, x_wavelength_nm);
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

    static inline mat3f chromatic_adaptation(vec3f white_point_src_cie_xyz, vec3f white_point_dst_cie_xyz)
    {
        constexpr mat3f m_cat = {0.8951f, 0.2664f, -0.1614f, -0.7502f, 1.7135f, 0.0367f, 0.0389f, -0.0685f, 1.0296f};
        constexpr mat3f m_cat_inv = {0.9869929f, -0.1470543f, 0.1599627f, 0.4323053f, 0.5183603f, 0.0492912f, -0.0085287f, 0.0400428f, 0.9684867f};

        vec3f lms_src = m_cat * white_point_src_cie_xyz;
        vec3f lms_dst = m_cat * white_point_dst_cie_xyz;

        return m_cat_inv * mat3f{lms_dst.x / lms_src.x, 0.0f, 0.0f, 0.0f, lms_dst.y / lms_src.y, 0.0f, 0.0f, 0.0f, lms_dst.z / lms_src.z} * m_cat;
    }

    static inline mat3f convert_scene_colorspace(const scene_colorspace_info_t& from, const scene_colorspace_info_t& to)
    {
        return to.cie_XYZ_to_colorspace * chromatic_adaptation(cie_xy_to_cie_XYZ(from.white_point_cie_xy), cie_xy_to_cie_XYZ(to.white_point_cie_xy)) * from.colorspace_to_cie_XYZ;
    }

    static inline scene_colorspace_info_t fetch_scene_colorspace(e_magik_scene_colorspace_types scene_colorspace_type)
    {
        scene_colorspace_info_t result;

        bool successful_colorspace = dispatch_list(supported_scene_colorspaces{}, scene_colorspace_type, [&](auto tag)
        {
            constexpr auto T = decltype(tag)::value;
            result.cie_XYZ_to_colorspace = generic_scene_colorspace_t<T>::XYZ_to_colorspace;
            result.colorspace_to_cie_XYZ = generic_scene_colorspace_t<T>::colorspace_to_XYZ;
            result.white_point_cie_xy = generic_scene_colorspace_t<T>::white_point_cie_xy;
        });

        if(!successful_colorspace)
        {
            result.cie_XYZ_to_colorspace = generic_scene_colorspace_t<MAGIK_SCENE_COLORSPACE_CIE_XYZ>::XYZ_to_colorspace;
            result.colorspace_to_cie_XYZ = generic_scene_colorspace_t<MAGIK_SCENE_COLORSPACE_CIE_XYZ>::colorspace_to_XYZ;
            result.white_point_cie_xy = generic_scene_colorspace_t<MAGIK_SCENE_COLORSPACE_CIE_XYZ>::white_point_cie_xy;
        }

        return result;
    }

    static inline display_colorspace_info_t fetch_display_colorspace(e_magik_display_colorspace_types display_colorspace_type)
    {
        display_colorspace_info_t result;

        bool successful_colorspace = dispatch_list(supported_display_colorspaces{}, display_colorspace_type, [&](auto tag)
        {
            constexpr auto T = decltype(tag)::value;
            result.cie_XYZ_to_colorspace = generic_display_colorspace_t<T>::XYZ_to_colorspace;
            result.colorspace_to_cie_XYZ = generic_display_colorspace_t<T>::colorspace_to_XYZ;
            result.white_point_cie_xy = generic_display_colorspace_t<T>::white_point_cie_xy;
            result.peak_luminance = generic_display_colorspace_t<T>::peak_luminance;
        });

        if(!successful_colorspace)
        {
            result.cie_XYZ_to_colorspace = generic_display_colorspace_t<MAGIK_DISPLAY_COLORSPACE_SRGB>::XYZ_to_colorspace;
            result.colorspace_to_cie_XYZ = generic_display_colorspace_t<MAGIK_DISPLAY_COLORSPACE_SRGB>::colorspace_to_XYZ;
            result.white_point_cie_xy = generic_display_colorspace_t<MAGIK_DISPLAY_COLORSPACE_SRGB>::white_point_cie_xy;
            result.peak_luminance = generic_display_colorspace_t<MAGIK_DISPLAY_COLORSPACE_SRGB>::peak_luminance;
        }

        return result;
    }

    static inline cmf_info_t fetch_cmf_info(e_magik_color_matching_function_types cmf_type)
    {
        cmf_info_t result;

        bool successful_cmf = dispatch_list(supported_color_matching_functions{}, cmf_type, [&](auto tag)
        {
            constexpr auto T = decltype(tag)::value;
            result.n_entries = generic_color_matching_function_t<T>::n_entries;
            result.min_wavelength_nm = generic_color_matching_function_t<T>::min_wavelength_nm;
            result.max_wavelength_nm = generic_color_matching_function_t<T>::max_wavelength_nm;
            result.values = generic_color_matching_function_t<T>::values;
        });

        if(!successful_cmf)
        {
            result.n_entries = generic_color_matching_function_t<MAGIK_CMF_CIE_1931>::n_entries;
            result.min_wavelength_nm = generic_color_matching_function_t<MAGIK_CMF_CIE_1931>::min_wavelength_nm;
            result.max_wavelength_nm = generic_color_matching_function_t<MAGIK_CMF_CIE_1931>::max_wavelength_nm;
            result.values = generic_color_matching_function_t<MAGIK_CMF_CIE_1931>::values;
        }

        return result;
    }

    static inline void compute_normalized_isi_cmf_weights(vec3f* isi_to_scene_referred_weights, uint32_t n_isi_bin, float isi_min_wavelength_nm, float isi_max_wavelength_nm, cmf_info_t cmf_info)
    {
        vec3f w = {0.0f, 0.0f, 0.0f};
        float sum_y = 0.0f;

        float isi_bin_range = (isi_max_wavelength_nm - isi_min_wavelength_nm) / static_cast<float>(n_isi_bin);
        float cmf_bin_range = (cmf_info.max_wavelength_nm - cmf_info.min_wavelength_nm) / static_cast<float>(cmf_info.n_entries - 1);
        uint32_t sub_range_steps = static_cast<uint32_t>(ceilf(isi_bin_range / cmf_bin_range));
        float x_wavelength_sub_range_nm = isi_bin_range / static_cast<float>(sub_range_steps);
        float x_wavelength_nm_isi_bin, x_wavelenght_nm_sub_range;

        for(uint32_t i = 0; i < n_isi_bin; i++)
        {
            x_wavelength_nm_isi_bin = isi_min_wavelength_nm + i * isi_bin_range;

            for(uint32_t j = 0; j < sub_range_steps; j++)
            {
                x_wavelenght_nm_sub_range = x_wavelength_nm_isi_bin + (j + 0.5f)*x_wavelength_sub_range_nm;
                w += sample_equidistant_spectral_data(cmf_info.values, cmf_info.n_entries, cmf_info.min_wavelength_nm, cmf_info.max_wavelength_nm, x_wavelenght_nm_sub_range) * x_wavelength_sub_range_nm;
            }

            isi_to_scene_referred_weights[i] = w;
            sum_y += w.y;
            w = {0.0f, 0.0f, 0.0f};
        }

        float k = 1.0f / sum_y;
        float inv_bin_width = 1.0f / isi_bin_range;

        for(uint32_t i = 0; i < n_isi_bin; i++)
        {
            isi_to_scene_referred_weights[i] *= k * inv_bin_width;
        }
    }

    static inline void fold_XYZ_to_scene_matrix_into_isi(vec3f* isi_to_scene_referred_weights, uint32_t n_isi_bin, mat3f XYZ_to_scene)
    {
        for(uint32_t i = 0; i < n_isi_bin; i++)
        {
            isi_to_scene_referred_weights[i] = XYZ_to_scene * isi_to_scene_referred_weights[i];
        }
    }

    static inline void compute_tabulated_cmf_inverse_cdf(float* cmf_inverse_cdf, float cdf_floor, float user_min_wavelength_nm, float user_max_wavelength_nm, cmf_info_t cmf_info)
    {
        uint32_t n = cmf_info.n_entries - 1;
        std::vector<vec3f> resampled_cmf(cmf_info.n_entries, vec3f{});

        float resampled_wavelength_range_nm_bin = (user_max_wavelength_nm - user_min_wavelength_nm)/float(n);

        for(uint32_t i = 0; i < cmf_info.n_entries; ++i)
        {
            float sample_wavelength_nm = user_min_wavelength_nm + float(i) * resampled_wavelength_range_nm_bin;
            resampled_cmf[i] = sample_equidistant_spectral_data(cmf_info.values, cmf_info.n_entries, cmf_info.min_wavelength_nm, cmf_info.max_wavelength_nm, sample_wavelength_nm);
        }

        auto s = [&](uint32_t i) 
        {
            return resampled_cmf[i].x + resampled_cmf[i].y + resampled_cmf[i].z; 
        };

        // Compute the CDF
        float wavelength_range_nm_bin = (user_max_wavelength_nm - user_min_wavelength_nm) / (static_cast<float>(n)); 
        std::vector<float> cdf(n + 1, 0.0f);

        float mean = 0.0f;
        for (uint32_t i = 0; i < cmf_info.n_entries; ++i) mean += s(i);
        mean /= float(cmf_info.n_entries);
        const float floor = cdf_floor * mean;

        for(uint32_t i = 0; i < n; ++i)
        {
            cdf[i+1] = cdf[i] + (0.5f*(s(i) + s(i+1)) + floor) * wavelength_range_nm_bin;
        }

        const float total = cdf[n];
        for (uint32_t j = 0; j <= n; ++j) cdf[j] /= total;

        // Inverte CDF
        uint32_t best_match_index = 0;
        for(uint32_t k = 0; k < MAGIK_N_CMF_INVERSE_CDF_BIN; k++)
        {
            float u = float(k) / float(MAGIK_N_CMF_INVERSE_CDF_BIN - 1);
            while(best_match_index < n - 1 && cdf[best_match_index+1] < u) ++best_match_index;
            float t = (u - cdf[best_match_index]) / fmaxf(cdf[best_match_index + 1] - cdf[best_match_index], 1e-12f);

            cmf_inverse_cdf[k] = user_min_wavelength_nm + (float(best_match_index) + t) * wavelength_range_nm_bin;
        }
    }
}
