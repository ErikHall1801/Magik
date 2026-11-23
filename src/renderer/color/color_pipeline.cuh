#pragma once

#include "cuda_host_device_utilities.h"
#include "host_color_utilities.cuh" 
#include "view_transform.cuh"

namespace magik
{
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
        float cmf_inverse_cdf_values[MAGIK_N_CMF_INVERSE_CDF_BIN];
        e_magik_display_colorspace_types display_colorspace_type;
        float peak_nits;
        mat3f scene_to_display_referred;
        e_magik_output_format_types output_format;

        static __host__ color_pipeline_descriptor_t create(color_pipeline_settings_t settings)
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

            // Create the view transform paramters
            auto rec709_info = fetch_scene_colorspace(MAGIK_SCENE_COLORSPACE_LINEAR_REC709);
            auto rec2020_info = fetch_scene_colorspace(MAGIK_SCENE_COLORSPACE_LINEAR_REC2020);

            view_transform_params_t view_transform_params;

            view_transform_params.reinhard_extended_white_luminance = 4.0f;
            view_transform_params.reinhard_extended_luminance_weights = vec3f{scene_colorspace_info.colorspace_to_cie_XYZ.m21, scene_colorspace_info.colorspace_to_cie_XYZ.m22, scene_colorspace_info.colorspace_to_cie_XYZ.m23};

            view_transform_params.khronos_pbr_neutral_start_compression = 0.8f;
            view_transform_params.khronos_pbr_neutral_desaturation = 0.15f;
            view_transform_params.khronos_pbr_neutral_to_linear_rec_709 = convert_scene_colorspace(scene_colorspace_info, rec709_info);
            view_transform_params.khronos_pbr_neutral_to_scene_colorspace = convert_scene_colorspace(rec709_info, scene_colorspace_info);

            view_transform_params.gran_turismo_7_mode = MAGIK_GRANTURISMO_7_MODE_JZAZBZ; // Why not setting ? 
            view_transform_params.gran_turismo_7_to_linear_rec_2020 = convert_scene_colorspace(scene_colorspace_info, rec2020_info);
            view_transform_params.gran_turismo_7_to_scene_colorspace = convert_scene_colorspace(rec2020_info, scene_colorspace_info);
            view_transform_params.gran_turismo_7_sdr_paper_white = 250.0f; // All of this
            view_transform_params.gran_turismo_7_reference_luminance = 100.0f; // has to come 
            view_transform_params.gran_turismo_7_jzazbz_exponent_scale_factor = 1.7f; // from the settings 

            result.view_transform_descriptor = view_transform_descriptor_t::create(settings.view_transform, view_transform_params);

            return result;
        }
    };
}
