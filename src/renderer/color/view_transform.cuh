#pragma once

#include "magik.h"
#include "cuda_host_device_utilities.h"
#include "internal_math.h"
#include "host_color_utilities.h"
#include "color_settings.h"

namespace magik
{
    template<e_magik_view_transform_types T_map> struct generic_view_transform_t;

    template<> struct generic_view_transform_t<MAGIK_VIEW_TRANSFORM_NONE>
    {
        static constexpr bool does_gamut_mapping = false;

        struct params_t{};

        static MAGIK_HOST params_t make_params(const color_settings_t& color_settings){ return params_t{}; }

        static MAGIK_DEVICE_HOST vec3f apply(vec3f c, const params_t& p) { return c; }
    };

    template<> struct generic_view_transform_t<MAGIK_VIEW_TRANSFORM_REINHARD_SIMPLE>
    {
        static constexpr bool does_gamut_mapping = false;

        struct params_t{};

        static MAGIK_HOST params_t make_params(const color_settings_t& color_settings){ return params_t{}; }

        static MAGIK_DEVICE_HOST vec3f apply(vec3f c, const params_t& p) 
        { 
            return c / (c + vec3f{1.0f, 1.0f, 1.0f}); 
        }
    };

    template<> struct generic_view_transform_t<MAGIK_VIEW_TRANSFORM_REINHARD_EXTENDED>
    {
        static constexpr bool does_gamut_mapping = false;
        
        struct params_t
        {
            float white_luminance;
            vec3f luminance_weights;
        };

        static MAGIK_HOST params_t make_params(const color_settings_t& color_settings)
        {
            params_t p;
            p.white_luminance = color_settings.vt_reinhard_extended_white_luminance;

            auto scene_colorspace_info = fetch_scene_colorspace(color_settings.scene_colorspace_type);
            p.luminance_weights = vec3f{scene_colorspace_info.colorspace_to_cie_XYZ.m21, scene_colorspace_info.colorspace_to_cie_XYZ.m22, scene_colorspace_info.colorspace_to_cie_XYZ.m23};
            
            return p; 
        }

        static MAGIK_DEVICE_HOST vec3f apply(vec3f c, const params_t& p) 
        {
            float L = vector_dot_product(p.luminance_weights, c); 
            float L0 = L * (1.0f + L/(p.white_luminance * p.white_luminance)) / (1.0f + L);
            return L > 0.0f ? c * (L0/L) : vec3f{0.0f, 0.0f, 0.0f};
        }
    };

    template<> struct generic_view_transform_t<MAGIK_VIEW_TRANSFORM_KHRONOS_PBR_NEUTRAL>
    {
        static constexpr bool does_gamut_mapping = false;
        
        struct params_t
        {
            float start_compression;
            float desaturation;
            mat3f to_linear_rec_709;
            mat3f to_scene_colorspace;
        };

        static MAGIK_HOST params_t make_params(const color_settings_t& color_settings)
        {
            params_t p;

            p.start_compression = color_settings.vt_khronos_pbr_neutral_start_compression;
            p.desaturation = color_settings.vt_khronos_pbr_neutral_desaturation;

            auto scene_colorspace_info = fetch_scene_colorspace(color_settings.scene_colorspace_type);
            auto rec709_info = fetch_scene_colorspace(MAGIK_SCENE_COLORSPACE_LINEAR_REC709);

            p.to_linear_rec_709 = convert_scene_colorspace(scene_colorspace_info, rec709_info);
            p.to_scene_colorspace = convert_scene_colorspace(rec709_info, scene_colorspace_info);

            return p; 
        }

        static MAGIK_DEVICE_HOST vec3f apply(vec3f c, const params_t& p) 
        {
            vec3f color = p.to_linear_rec_709 * c;
            float start_compression = p.start_compression - 0.04f;

            float x = fminf(color.x, fminf(color.y, color.z));
            float offset = x < 0.08f ? x - 6.25f * x * x : 0.04f;
            color -= vec3f{offset, offset, offset};

            float peak = fmaxf(color.x, fmaxf(color.y, color.z));
            if(peak < start_compression) return p.to_scene_colorspace * color;

            float d = 1.0f - start_compression;
            float new_peak = 1.0f - d * d / (peak + d - start_compression);
            color *= new_peak / peak;

            float g = 1.0f - 1.0f/(p.desaturation * (peak - new_peak) + 1.0f);
            return p.to_scene_colorspace * magik::lerp(color, vec3f{new_peak, new_peak, new_peak}, g);
        }
    };

    template<> struct generic_view_transform_t<MAGIK_VIEW_TRANSFORM_GRAN_TURISMO_7>
    {
        static constexpr bool does_gamut_mapping = false;
        
        struct params_t
        {
            e_magik_gran_turismo_7_mode_types mode;
            float sdr_paper_white;
            float reference_luminance;
            float jzazbz_exponent_scale_factor;
            
            mat3f to_linear_rec_2020;
            mat3f to_scene_colorspace;

            float peak_intensity_;
            float alpha_;
            float mid_point_;
            float linear_section_;
            float toe_strength_;
            float kA_, kB_, kC_;

            float sdr_correction_factor_;
            float framebuffer_luminance_target_;
            float framebuffer_luminance_target_ucs;

            float blend_ratio_;
            float fade_start_;
            float fade_end_;
        };

        static MAGIK_DEVICE_HOST float framebuffer_value_to_physical_value(float fb_value, float reference_luminance)
        {
            return fb_value * reference_luminance;
        }

        static MAGIK_DEVICE_HOST float physical_value_to_framebuffer_value(float physical, float reference_luminance)
        {
            return physical / reference_luminance;
        }

        static MAGIK_DEVICE_HOST float smooth_step(float x, float edge0, float edge1)
        {
            float t = (x - edge0) / (edge1 - edge0);

            if (x < edge0)
            {
                return 0.0f;
            }
            if (x > edge1)
            {
                return 1.0f;
            }

            return t * t * (3.0f - 2.0f * t);
        }

        static MAGIK_DEVICE_HOST float chroma_curve(float x, float a, float b)
        {
            return 1.0f - smooth_step(x, a, b);
        }

        static MAGIK_DEVICE_HOST float eotf_st2084(float n, float reference_luminance, float exponent_scale_factor)
        {
            if (n < 0.0f)
            {
                n = 0.0f;
            }
            if (n > 1.0f)
            {
                n = 1.0f;
            }

            const float m1 = 0.1593017578125f;
            const float m2 = 78.84375f * exponent_scale_factor;
            const float c1 = 0.8359375f;
            const float c2 = 18.8515625f;
            const float c3 = 18.6875f;
            const float pqC = 10000.0f;

            float np = powf(n, 1.0f / m2);
            float l = np - c1;

            if(l < 0.0f)
            {
                l = 0.0f;
            }

            l = l / (c2 - c3 * np);
            l = powf(l, 1.0f/m1);

            return physical_value_to_framebuffer_value(l*pqC, reference_luminance);
        }

        static MAGIK_DEVICE_HOST float inverse_eotf_st2084(float v, float reference_luminance, float exponent_scale_factor)
        {
            const float m1  = 0.1593017578125f;
            const float m2  = 78.84375f * exponent_scale_factor;
            const float c1  = 0.8359375f;
            const float c2  = 18.8515625f;
            const float c3  = 18.6875f;
            const float pqC = 10000.0f;

            float physical = framebuffer_value_to_physical_value(v, reference_luminance);
            float y = physical / pqC;
            float ym = powf(y, m1);
            return exp2f(m2 * (log2f(c1 + c2 * ym) - log2f(1.0f + c3 * ym)));
        }

        static MAGIK_DEVICE_HOST void rgb_to_ictcp(const float* rgb, float* ictCp, float reference_luminance)
        {
            float l = (rgb[0] * 1688.0f + rgb[1] * 2146.0f + rgb[2] * 262.0f) / 4096.0f;
            float m = (rgb[0] * 683.0f + rgb[1] * 2951.0f + rgb[2] * 462.0f) / 4096.0f;
            float s = (rgb[0] * 99.0f + rgb[1] * 309.0f + rgb[2] * 3688.0f) / 4096.0f;

            float lPQ = inverse_eotf_st2084(l, reference_luminance, 1.0f);
            float mPQ = inverse_eotf_st2084(m, reference_luminance, 1.0f);
            float sPQ = inverse_eotf_st2084(s, reference_luminance, 1.0f);

            ictCp[0] = (2048.0f * lPQ + 2048.0f * mPQ) / 4096.0f;
            ictCp[1] = (6610.0f * lPQ - 13613.0f * mPQ + 7003.0f * sPQ) / 4096.0f;
            ictCp[2] = (17933.0f * lPQ - 17390.0f * mPQ - 543.0f * sPQ) / 4096.0f;
        }

        static MAGIK_DEVICE_HOST void ictcp_to_rgb(const float* ictCp, float* rgb, float reference_luminance)
        {
            float l = ictCp[0] + 0.00860904f * ictCp[1] + 0.11103f * ictCp[2];
            float m = ictCp[0] - 0.00860904f * ictCp[1] - 0.11103f * ictCp[2];
            float s = ictCp[0] + 0.560031f * ictCp[1] - 0.320627f * ictCp[2];

            float lLin = eotf_st2084(l, reference_luminance, 1.0f);
            float mLin = eotf_st2084(m, reference_luminance, 1.0f);
            float sLin = eotf_st2084(s, reference_luminance, 1.0f);

            rgb[0] = fmaxf(3.43661f * lLin - 2.50645f * mLin + 0.0698454f * sLin, 0.0f);
            rgb[1] = fmaxf(-0.79133f * lLin + 1.9836f * mLin - 0.192271f * sLin, 0.0f);
            rgb[2] = fmaxf(-0.0259499f * lLin - 0.0989137f * mLin + 1.12486f * sLin, 0.0f);
        }

        static MAGIK_DEVICE_HOST void rgb_to_jzazbz(const float* rgb, float* jab, float reference_luminance, float jzazbz_exponent_scale_factor)
        {
            float l = rgb[0] * 0.530004f + rgb[1] * 0.355704f + rgb[2] * 0.086090f;
            float m = rgb[0] * 0.289388f + rgb[1] * 0.525395f + rgb[2] * 0.157481f;
            float s = rgb[0] * 0.091098f + rgb[1] * 0.147588f + rgb[2] * 0.734234f;

            float lPQ = inverse_eotf_st2084(l, reference_luminance, jzazbz_exponent_scale_factor);
            float mPQ = inverse_eotf_st2084(m, reference_luminance, jzazbz_exponent_scale_factor);
            float sPQ = inverse_eotf_st2084(s, reference_luminance, jzazbz_exponent_scale_factor);

            float iz = 0.5f * lPQ + 0.5f * mPQ;

            jab[0] = (0.44f * iz) / (1.0f - 0.56f * iz) - 1.6295499532821566e-11f;
            jab[1] = 3.524000f * lPQ - 4.066708f * mPQ + 0.542708f * sPQ;
            jab[2] = 0.199076f * lPQ + 1.096799f * mPQ - 1.295875f * sPQ;
        }

        static MAGIK_DEVICE_HOST void jzazbz_to_rgb(const float* jab, float* rgb, float reference_luminance, float jzazbz_exponent_scale_factor)
        {
            float jz = jab[0] + 1.6295499532821566e-11f;
            float iz = jz / (0.44f + 0.56f * jz);
            float a  = jab[1];
            float b  = jab[2];

            float l = iz + a * 1.386050432715393e-1f + b * 5.804731615611869e-2f;
            float m = iz + a * -1.386050432715393e-1f + b * -5.804731615611869e-2f;
            float s = iz + a * -9.601924202631895e-2f + b * -8.118918960560390e-1f;

            float lLin = eotf_st2084(l, reference_luminance, jzazbz_exponent_scale_factor);
            float mLin = eotf_st2084(m, reference_luminance, jzazbz_exponent_scale_factor);
            float sLin = eotf_st2084(s, reference_luminance, jzazbz_exponent_scale_factor);

            rgb[0] = lLin * 2.990669f + mLin * -2.049742f + sLin * 0.088977f;
            rgb[1] = lLin * -1.634525f + mLin * 3.145627f + sLin * -0.483037f;
            rgb[2] = lLin * -0.042505f + mLin * -0.377983f + sLin * 1.448019f;
        }

        static MAGIK_DEVICE_HOST void rgb_to_ucs(const float* rgb, float* ucs, float reference_luminance, float jzazbz_exponent_scale_factor, e_magik_gran_turismo_7_mode_types type)
        {
            switch(type)
            {
                case e_magik_gran_turismo_7_mode_types::MAGIK_GRAN_TURISMO_7_MODE_ICTCP:
                {
                    rgb_to_ictcp(rgb, ucs, reference_luminance);
                    break;
                }

                case e_magik_gran_turismo_7_mode_types::MAGIK_GRAN_TURISMO_7_MODE_JZAZBZ:
                {
                    rgb_to_jzazbz(rgb, ucs, reference_luminance, jzazbz_exponent_scale_factor);
                    break;
                }
            }
        }

        static MAGIK_DEVICE_HOST void ucs_to_rgb(const float* ucs, float* rgb, float reference_luminance, float jzazbz_exponent_scale_factor, e_magik_gran_turismo_7_mode_types type)
        {
            switch(type)
            {
                case e_magik_gran_turismo_7_mode_types::MAGIK_GRAN_TURISMO_7_MODE_ICTCP:
                {
                    ictcp_to_rgb(ucs, rgb, reference_luminance);
                    break;
                }

                case e_magik_gran_turismo_7_mode_types::MAGIK_GRAN_TURISMO_7_MODE_JZAZBZ:
                {
                    jzazbz_to_rgb(ucs, rgb, reference_luminance, jzazbz_exponent_scale_factor);
                    break;
                }
            }
        }

        static MAGIK_DEVICE_HOST void initialize_curve(params_t& p, float monitor_intensity, float alpha, float gray_point, float linear_section, float toe_strength)
        {
            p.peak_intensity_ = monitor_intensity;
            p.alpha_ = alpha;
            p.mid_point_ = gray_point;
            p.linear_section_ = linear_section;
            p.toe_strength_ = toe_strength;

            float k = (p.linear_section_ - 1.0f) / (p.alpha_ - 1.0f);
            p.kA_ = p.peak_intensity_ * p.linear_section_ + p.peak_intensity_ * k;
            p.kB_ = -p.peak_intensity_ * k * expf(p.linear_section_ / k);
            p.kC_ = -1.0f / (k * p.peak_intensity_);
        }

        static MAGIK_DEVICE_HOST float evaluate_curve(const params_t& p, float x)
        {
            if(x < 0.0f)
            {
                return 0.0f;
            }

            float weight_linear = smooth_step(x, 0.0f, p.mid_point_);
            float weight_toe = 1.0f - weight_linear;

            float shoulder = p.kA_ + p.kB_ * expf(x * p.kC_);

            if(x < p.linear_section_ * p.peak_intensity_)
            {
                float toe_mapped = p.mid_point_ * powf(x / p.mid_point_, p.toe_strength_);
                return weight_toe * toe_mapped + weight_linear * x;
            }
            else
            {
                return shoulder;
            }
        }

        static MAGIK_DEVICE_HOST void initialize_parameters(params_t& p)
        {
            p.framebuffer_luminance_target_ = physical_value_to_framebuffer_value(p.sdr_paper_white, p.reference_luminance);

            // This could be user defined parameters ! 
            initialize_curve(p, p.framebuffer_luminance_target_, 0.25f, 0.538f, 0.444f, 1.280f);

            p.blend_ratio_ = 0.6f;
            p.fade_start_ = 0.98f;
            p.fade_end_ = 1.16f;

            float ucs[3];
            float rgb[3] = {p.framebuffer_luminance_target_, p.framebuffer_luminance_target_, p.framebuffer_luminance_target_};

            rgb_to_ucs(rgb, ucs, p.reference_luminance, p.jzazbz_exponent_scale_factor, p.mode);

            p.framebuffer_luminance_target_ucs = ucs[0];
        }

        static MAGIK_DEVICE_HOST void initialize_as_hdr(params_t& p)
        {
            p.sdr_correction_factor_ = 1.0f;
            initialize_parameters(p);
        }

        static MAGIK_DEVICE_HOST void initialize_as_sdr(params_t& p)
        {
            p.sdr_correction_factor_ = 1.0f / physical_value_to_framebuffer_value(p.sdr_paper_white, p.reference_luminance);
            initialize_parameters(p);
        }

        static MAGIK_DEVICE_HOST void apply_tonemapping(const params_t& p, const float* rgb, float* out)
        {
            float ucs[3];
            rgb_to_ucs(rgb, ucs, p.reference_luminance, p.jzazbz_exponent_scale_factor, p.mode);

            float skewed_rgb[3] = { evaluate_curve(p, rgb[0]), evaluate_curve(p, rgb[1]), evaluate_curve(p, rgb[2]) };

            float skewed_ucs[3];
            rgb_to_ucs(skewed_rgb, skewed_ucs, p.reference_luminance, p.jzazbz_exponent_scale_factor, p.mode);

            float chroma_scale = chroma_curve(ucs[0] / p.framebuffer_luminance_target_ucs, p.fade_start_, p.fade_end_);

            float scaled_ucs[3] = {skewed_ucs[0], ucs[1] * chroma_scale, ucs[2] * chroma_scale};

            float scaled_rgb[3];
            ucs_to_rgb(scaled_ucs, scaled_rgb, p.reference_luminance, p.jzazbz_exponent_scale_factor, p.mode);

            for(int i = 0; i < 3; ++i)
            {
                float blended = (1.0f - p.blend_ratio_) * skewed_rgb[i] + p.blend_ratio_ * scaled_rgb[i];
                out[i] = p.sdr_correction_factor_ * fminf(blended, p.framebuffer_luminance_target_);
            }
        }

        static MAGIK_HOST params_t make_params(const color_settings_t& color_settings)
        {
            params_t p;

            p.mode = color_settings.vt_gt7_mode;
            p.sdr_paper_white = color_settings.vt_gt7_sdr_paper_white;
            p.reference_luminance = color_settings.vt_gt7_reference_luminance;
            p.jzazbz_exponent_scale_factor = color_settings.vt_gt7_jzazbz_exponent_scale_factor;

            auto scene_colorspace_info = fetch_scene_colorspace(color_settings.scene_colorspace_type);
            auto rec2020_info = fetch_scene_colorspace(MAGIK_SCENE_COLORSPACE_LINEAR_REC2020);

            p.to_linear_rec_2020 = convert_scene_colorspace(scene_colorspace_info, rec2020_info);
            p.to_scene_colorspace = convert_scene_colorspace(rec2020_info, scene_colorspace_info);

            bool is_sdr = true; // Future, automatically detect if a display colorspace is SDR or HDR
            if(is_sdr)
            {
                initialize_as_sdr(p);
            }
            else
            {
                initialize_as_hdr(p);
            }

            return p; 
        }

        static MAGIK_DEVICE_HOST vec3f apply(vec3f c, const params_t& p)
        {
            // CREDITS :: https://blog.selfshadow.com/publications/s2025-shading-course/pdi/supplemental/gt7_tone_mapping.cpp

            vec3f color = p.to_linear_rec_2020 * c;
            float rgb_in[3] = {color.x, color.y, color.z};
            float rgb_out[3] = {0.0f, 0.0f, 0.0f};

            color = { fmaxf(color.x, 0.0f), fmaxf(color.y, 0.0f), fmaxf(color.z, 0.0f) };

            apply_tonemapping(p, rgb_in, rgb_out);

            color = p.to_scene_colorspace * vec3f{rgb_out[0], rgb_out[1], rgb_out[2]};
            return color;
        }
    };

    template<> struct generic_view_transform_t<MAGIK_VIEW_TRANSFORM_AGX>
    {
        // CREDITS: https://github.com/google/filament/blob/main/filament/src/ToneMapper.cpp#L694 

        static constexpr bool does_gamut_mapping = false;

        // These are most likely meant to be functions ? With LOG2_MIN, MAX and MIDDLE GRAY being parameters ? 
        static MAGIK_DEVICE_HOST float agx_min_ev()
        {
            return -12.47393f;
        }

        static MAGIK_DEVICE_HOST float agx_max_ev()
        {
            return 4.026069f;
        }

        static MAGIK_DEVICE_HOST vec3f agx_default_contrast_approx(vec3f x)
        {
            vec3f const x2 = x*x;
            vec3f const x4 = x2*x2;
            vec3f const x6 = x4*x2;
            return -17.86f*x6*x + 78.01f*x6 - 126.7f*x4*x + 92.06f*x4 - 28.72f*x2*x + 4.361f*x2 - 0.1718f*x + vec3f{0.002857f, 0.002857f, 0.002857f};
        }

        static MAGIK_DEVICE_HOST vec3f agx_look(vec3f val, e_magik_agx_look_types look)
        {
            if(look == MAGIK_AGX_LOOK_NONE) return val;

            constexpr vec3f lw = vec3f{0.2126f, 0.7152f, 0.0722f};
            float const luma = vector_dot_product(val, lw);

            constexpr vec3f offset = vec3f{0.0f, 0.0f, 0.0f};
            vec3f slope = vec3f{1.0f, 1.0f, 1.0f};
            vec3f power = vec3f{1.0f, 1.0f, 1.0f};
            float sat = 1.0f;

            if(look == MAGIK_AGX_LOOK_GOLDEN)
            {
                slope = vec3f{1.0f, 0.9f, 0.5f};
                power = vec3f{0.8f, 0.8f, 0.8f};
                sat = 1.3f;
            }

            if(look == MAGIK_AGX_LOOK_PUNCHY)
            {
                slope = vec3f{1.0f, 1.0f, 1.0f};
                power = vec3f{1.35f, 1.35f, 1.35f};
                sat = 1.4f;
            }

            vec3f val2 = vec3f{ powf(val.x * slope.x + offset.x, power.x), powf(val.y * slope.y + offset.y, power.y), powf(val.z * slope.z + offset.z, power.z) };
            return vec3f{luma, luma, luma} + sat * (val2 - vec3f{luma, luma, luma});
        }

        struct params_t
        {
            mat3f to_linear_rec_2020;
            mat3f agx_inset_matrix;
            mat3f agx_outset_matrix;
            mat3f to_scene_colorspace;
            e_magik_agx_look_types look;
        };

        static MAGIK_HOST params_t make_params(const color_settings_t& color_settings)
        {
            params_t p;

            auto scene_colorspace_info = fetch_scene_colorspace(color_settings.scene_colorspace_type);
            auto rec2020_info = fetch_scene_colorspace(MAGIK_SCENE_COLORSPACE_LINEAR_REC2020);

            p.to_linear_rec_2020 = convert_scene_colorspace(scene_colorspace_info, rec2020_info);
            p.to_scene_colorspace = convert_scene_colorspace(rec2020_info, scene_colorspace_info);

            p.agx_inset_matrix = mat3f{0.856627153315983f, 0.137318972929847f, 0.11189821299995f, 0.0951212405381588f, 0.761241990602591f, 0.0767994186031903f, 0.0482516061458583f, 0.101439036467562f, 0.811302368396859f}.transpose();
            p.agx_outset_matrix = mat3f{1.1271005818144f, -0.14132976349844f, -0.14132976349844f, -0.11060664309660f, 1.1578237022163f, -0.11060664309660f, -0.016493938717835f, -0.016493938717834f, 1.2519364065950f}.transpose();

            p.look = color_settings.vt_agx_look;
            return p; 
        }

        static MAGIK_DEVICE_HOST vec3f apply(vec3f c, const params_t& p) 
        {
            vec3f v = p.to_linear_rec_2020 * c;
            v = vec3f{fmaxf(0.0f, v.x), fmaxf(0.0f, v.y), fmaxf(0.0f, v.z)};
            v = p.agx_inset_matrix * v;

            v = vec3f{fmaxf(v.x, 1e-10f), fmaxf(v.y, 1e-10f), fmaxf(v.z, 1e-10f)};
            v = vec3f{log2f(v.x), log2f(v.y), log2f(v.z)};
            v = (v - vec3f{agx_min_ev(), agx_min_ev(), agx_min_ev()}) / (agx_max_ev() - agx_min_ev());

            v = vec3f{magik::clamp(0.0f, 1.0f, v.x), magik::clamp(0.0f, 1.0f, v.y), magik::clamp(0.0f, 1.0f, v.z)};

            v = agx_default_contrast_approx(v);

            v = agx_look(v, p.look);

            v = p.agx_outset_matrix * v;
            v = vec3f{powf(fmaxf(0.0f, v.x), 2.2f), powf(fmaxf(0.0f, v.y), 2.2f), powf(fmaxf(0.0f, v.z), 2.2f)};
            v = p.to_scene_colorspace * v;

            return v;
        }
    };

    using supported_view_transforms = value_list
    <
        e_magik_view_transform_types::MAGIK_VIEW_TRANSFORM_NONE,
        e_magik_view_transform_types::MAGIK_VIEW_TRANSFORM_REINHARD_SIMPLE,
        e_magik_view_transform_types::MAGIK_VIEW_TRANSFORM_REINHARD_EXTENDED,
        e_magik_view_transform_types::MAGIK_VIEW_TRANSFORM_KHRONOS_PBR_NEUTRAL,
        e_magik_view_transform_types::MAGIK_VIEW_TRANSFORM_GRAN_TURISMO_7,
        e_magik_view_transform_types::MAGIK_VIEW_TRANSFORM_AGX
    >;
}
