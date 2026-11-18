#pragma once

#include "magik.h"
#include "internal_math.h"

namespace magik
{
    template<auto T_colorspace> struct generic_scene_colorspace_t; // Maybe make distinct _scene and _display types. Bc the display has a peak luminance and transfer functions 

    template<auto... T> struct colorspaces_list {};

    // Scene colorspaces
    template<> struct generic_scene_colorspace_t<MAGIK_SCENE_COLORSPACE_CIE_XYZ>
    {
        static constexpr mat3f colorspace_to_XYZ{1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 1.0f};
        static constexpr mat3f XYZ_to_colorspace{1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 1.0f};
        static constexpr vec2f white_point_cie_xy{1.0f/3.0f, 1.0f/3.0f};
    };

    template<> struct generic_scene_colorspace_t<MAGIK_SCENE_COLORSPACE_CIE_RGB>
    {
        static constexpr mat3f colorspace_to_XYZ{0.49f, 0.31f, 0.2f, 0.1769f, 0.8124f, 0.0107f, 0.0f, 0.0099f, 0.9901f};
        static constexpr mat3f XYZ_to_colorspace{2.36449012f, -0.89655263f, -0.46793749f, -0.51493525f, 1.42633279f, 0.08860245f, 0.00514883f, -0.01426189f, 1.00911305f};
        static constexpr vec2f white_point_cie_xy{1.0f/3.0f, 1.0f/3.0f};
    };

    template<> struct generic_scene_colorspace_t<MAGIK_SCENE_COLORSPACE_LINEAR_REC709>
    {
        static constexpr mat3f colorspace_to_XYZ{0.41238656f, 0.35759149f, 0.18045049f, 0.21263682f, 0.71518298f, 0.0721802f, 0.01933062f, 0.11919716f, 0.95037259f};
        static constexpr mat3f XYZ_to_colorspace{3.24100326f, -1.53739899f, -0.49861587f, -0.96922426f, 1.87592999f, 0.04155422f, 0.05563942f, -0.2040112f, 1.05714897f};
        static constexpr vec2f white_point_cie_xy{0.31271f, 0.32902f};
    };

    template<> struct generic_scene_colorspace_t<MAGIK_SCENE_COLORSPACE_LINEAR_REC2020>
    {
        static constexpr mat3f colorspace_to_XYZ{6.36953507e-01f, 1.44619185e-01f, 1.68855854e-01f, 2.62698339e-01f, 6.78008766e-01f, 5.92928953e-02f, 4.99407097e-17f, 2.80731358e-02f, 1.06082723e+00f};
        static constexpr mat3f XYZ_to_colorspace{1.71666343f, -0.35567332f, -0.25336809f, -0.66667384f, 1.61645574f, 0.0157683f, 0.01764248f, -0.04277698f, 0.94224328f};
        static constexpr vec2f white_point_cie_xy{0.31271f, 0.32902f};
    };

    template<> struct generic_scene_colorspace_t<MAGIK_SCENE_COLORSPACE_ACES_CG>
    {
        static constexpr mat3f colorspace_to_XYZ{0.66245418f, 0.13400421f, 0.15618769f, 0.27222872f, 0.67408177f, 0.05368952f, -0.00557465f, 0.00406073f, 1.0103391f};
        static constexpr mat3f XYZ_to_colorspace{ 1.64102338f, -0.32480329f, -0.2364247f, -0.66366286f, 1.61533159f, 0.01675635f, 0.01172189f, -0.00828444f, 0.98839486f};
        static constexpr vec2f white_point_cie_xy{0.32168f, 0.33767f};
    };

    template<> struct generic_scene_colorspace_t<MAGIK_SCENE_COLORSPACE_ADOBE_RGB_1998>
    {
        static constexpr mat3f colorspace_to_XYZ{0.57667f, 0.18556f, 0.18823f, 0.29734f, 0.62736f, 0.07529f, 0.02703f, 0.07069f, 0.99134f};
        static constexpr mat3f XYZ_to_colorspace{2.04159f, -0.56501f, -0.34473f, -0.96924f, 1.87597f, 0.04156f, 0.01344f, -0.11836f, 1.01517f};
        static constexpr vec2f white_point_cie_xy{0.31272f, 0.32903f};
    };

    using supported_scene_colorspaces = colorspaces_list
    <
        e_magik_scene_colorspace_types::MAGIK_SCENE_COLORSPACE_CIE_XYZ,
        e_magik_scene_colorspace_types::MAGIK_SCENE_COLORSPACE_CIE_RGB,
        e_magik_scene_colorspace_types::MAGIK_SCENE_COLORSPACE_LINEAR_REC709,
        e_magik_scene_colorspace_types::MAGIK_SCENE_COLORSPACE_LINEAR_REC2020,
        e_magik_scene_colorspace_types::MAGIK_SCENE_COLORSPACE_ACES_CG,
        e_magik_scene_colorspace_types::MAGIK_SCENE_COLORSPACE_ADOBE_RGB_1998
    >;

    template<class F, e_magik_scene_colorspace_types... Ts> bool match_scene_colorspace(e_magik_scene_colorspace_types type, F&& f, colorspaces_list<Ts...>)
    {
        return ((type == Ts ? (f(std::integral_constant<e_magik_scene_colorspace_types, Ts>{}), true) : false) || ...);
    }

    template<class F> bool dispatch_scene_colorspace(e_magik_scene_colorspace_types type, F&& f)
    {
        return match_scene_colorspace(type, std::forward<F>(f), supported_scene_colorspaces{});
    }



    // Display colorspaces
    template<auto T_colorspace> struct generic_display_colorspace_t;

    template<> struct generic_display_colorspace_t<MAGIK_DISPLAY_COLORSPACE_SRGB>
    {
        static constexpr mat3f colorspace_to_XYZ{0.4124564f, 0.3575761f, 0.1804375f, 0.2126729f, 0.7151522f, 0.0721750f, 0.0193339f, 0.1191920f, 0.9503041f};
        static constexpr mat3f XYZ_to_colorspace{3.2406255f, -1.537208f, -0.4986286f, -0.9689307f, 1.8757561f, 0.0415175f, 0.0557101f, -0.2040211f, 1.0569959f};
        static constexpr vec2f white_point_cie_xy{0.31271f, 0.32902f};
        static constexpr float peak_luminance{80.0f}; // in candela / m²

        static MAGIK_DEVICE_HOST vec3f encode(vec3f c)
        {
            auto ctf = [](const float comp)
            {
                if(comp <= 0.0031308f) return 12.92f*comp;

                return 1.055f*powf(comp, 1.0f/2.4f) - 0.055f;
            };

            return { ctf(c.x), ctf(c.y), ctf(c.z) };
        }

        static MAGIK_DEVICE_HOST vec3f decode(vec3f c)
        {
            auto ctf = [](const float comp)
            {
                if(comp <= 0.04045f) return comp/12.92f;

                return powf((comp+0.055f)/1.055f, 2.4f);
            };

            return { ctf(c.x), ctf(c.y), ctf(c.z) };
        }
    };

    using supported_display_colorspaces = colorspaces_list
    <
        e_magik_display_colorspace_types::MAGIK_DISPLAY_COLORSPACE_SRGB
        // e_magik_display_colorspace_types::MAGIK_DISPLAY_COLORSPACE_REC709,
        // e_magik_display_colorspace_types::MAGIK_DISPLAY_COLORSPACE_REC2100_PQ,
        // e_magik_display_colorspace_types::MAGIK_DISPLAY_COLORSPACE_REC2100_HLG,
        // e_magik_display_colorspace_types::MAGIK_DISPLAY_COLORSPACE_DCI_P3,
        // e_magik_display_colorspace_types::MAGIK_DISPLAY_COLORSPACE_DISPLAY_P3,
        // e_magik_display_colorspace_types::MAGIK_DISPLAY_COLORSPACE_ADOBE_RGB
    >;

    template<class F, e_magik_display_colorspace_types... Ts> bool match_display_colorspace(e_magik_display_colorspace_types type, F&& f, colorspaces_list<Ts...>)
    {
        return ((type == Ts ? (f(std::integral_constant<e_magik_display_colorspace_types, Ts>{}), true) : false) || ...);
    }

    template<class F> bool dispatch_display_colorspace(e_magik_display_colorspace_types type, F&& f)
    {
        return match_display_colorspace(type, std::forward<F>(f), supported_display_colorspaces{});
    }
}
