#pragma once

#include "cuda_host_device_utilities.h"
#include "host_color_utilities.cuh" 
#include "color_settings.h"
#include "view_transform.cuh"

namespace magik
{
    typedef enum e_magik_color_pipeline_update_policy_types : uint32_t
    {
        COLOR_PIPELINE_UPDATE_POLICY_NONE = 0,
        COLOR_PIPELINE_UPDATE_POLICY_RELAXED = 1,
        COLOR_PIPELINE_UPDATE_POLICY_STRICT = 2
    } e_magik_color_pipeline_update_policy_types;

    struct color_pipeline_descriptor_t
    {
        uint32_t n_spectral_bin;
        vec3f isi_to_scene_referred_weights[MAGIK_N_MAX_SPECTRAL_BIN];
        float cmf_inverse_cdf_values[MAGIK_N_CMF_INVERSE_CDF_BIN];
        e_magik_display_colorspace_types display_colorspace_type;
        float peak_nits;
        mat3f scene_to_display_referred;
        e_magik_output_format_types output_format;
        e_magik_view_transform_types view_transform_type;
        e_magik_color_pipeline_update_policy_types update_policy = COLOR_PIPELINE_UPDATE_POLICY_NONE;

        static __host__ color_pipeline_descriptor_t create(color_settings_t settings)
        {
            color_pipeline_descriptor_t result;

            auto scene_colorspace_info = fetch_scene_colorspace(settings.scene_colorspace_type);
            auto display_colorspace_info = fetch_display_colorspace(settings.display_colorspace_type);
            auto cmf_info = fetch_cmf_info(settings.cmf_type);

            result.display_colorspace_type = settings.display_colorspace_type;
            result.peak_nits = display_colorspace_info.peak_luminance;
            result.output_format = settings.output_format;
            result.n_spectral_bin = settings.n_isi_bin > MAGIK_N_MAX_SPECTRAL_BIN ? MAGIK_N_MAX_SPECTRAL_BIN : settings.n_isi_bin; // This should be replaced by a command-level constraint !

            compute_normalized_isi_cmf_weights(result.isi_to_scene_referred_weights, result.n_spectral_bin, settings.isi_min_wavelength_nm, settings.isi_max_wavelength_nm, cmf_info);

            compute_tabulated_cmf_inverse_cdf(result.cmf_inverse_cdf_values, 0.05f, settings.isi_min_wavelength_nm, settings.isi_max_wavelength_nm, cmf_info);

            vec3f white_point_src_cie_xyz = compute_white_point_xyz(settings.white_point, settings.tint, cmf_info);
            vec3f white_point_dst_cie_xyz = cie_xy_to_cie_XYZ(scene_colorspace_info.white_point_cie_xy);
            mat3f XYZ_to_scene_white_balanced = scene_colorspace_info.cie_XYZ_to_colorspace * chromatic_adaptation(white_point_src_cie_xyz, white_point_dst_cie_xyz);
            fold_XYZ_to_scene_matrix_into_isi(result.isi_to_scene_referred_weights, result.n_spectral_bin, XYZ_to_scene_white_balanced);

            result.scene_to_display_referred = display_colorspace_info.cie_XYZ_to_colorspace * chromatic_adaptation(white_point_dst_cie_xyz, cie_xy_to_cie_XYZ(display_colorspace_info.white_point_cie_xy)) * scene_colorspace_info.colorspace_to_cie_XYZ;

            result.view_transform_type = settings.view_transform_type;

            return result;
        }

        __host__ void raise_update_policy(e_magik_color_pipeline_update_policy_types policy)
        {
            update_policy = static_cast<e_magik_color_pipeline_update_policy_types>(update_policy | policy);
        }
    };
}
