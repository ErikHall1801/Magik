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
            auto ctf = [](const float L)
            {
                if(L <= 0.0031308f) return 12.92f*L;

                return 1.055f*powf(L, 1.0f/2.4f) - 0.055f;
            };

            return { ctf(c.x), ctf(c.y), ctf(c.z) };
        }

        static MAGIK_DEVICE_HOST vec3f decode(vec3f c)
        {
            auto ctf = [](const float V)
            {
                if(V <= 0.04045f) return V/12.92f;

                return powf((V+0.055f)/1.055f, 2.4f);
            };

            return { ctf(c.x), ctf(c.y), ctf(c.z) };
        }
    };

    template<> struct generic_display_colorspace_t<MAGIK_DISPLAY_COLORSPACE_REC709>
    {
        static constexpr mat3f colorspace_to_XYZ{0.41238656f, 0.35759149f, 0.18045049f, 0.21263682f, 0.71518298f, 0.0721802f, 0.01933062f, 0.11919716f, 0.95037259f};
        static constexpr mat3f XYZ_to_colorspace{3.24100326f, -1.53739899f, -0.49861587f, -0.96922426f, 1.87592999f, 0.04155422f, 0.05563942f, -0.2040112f, 1.05714897f};
        static constexpr vec2f white_point_cie_xy{0.31271f, 0.32902f};
        static constexpr float peak_luminance{100.0f}; // in candela / m²

        static MAGIK_DEVICE_HOST vec3f encode(vec3f c)
        {
            auto ctf = [](const float L)
            {
                return powf(fmaxf(L, 0.0f), 1.0f / 2.4f);
            };

            return { ctf(c.x), ctf(c.y), ctf(c.z) };
        }

        static MAGIK_DEVICE_HOST vec3f decode(vec3f c)
        {
            auto ctf = [](const float V)
            {
                return powf(fmaxf(V, 0.0f), 2.4f);
            };

            return { ctf(c.x), ctf(c.y), ctf(c.z) };
        }
    };

    template<> struct generic_display_colorspace_t<MAGIK_DISPLAY_COLORSPACE_REC2100_PQ>
    {
        static constexpr mat3f colorspace_to_XYZ{0.63695804830129132f, 0.14461690358620838f, 0.16888097516417205f, 0.26270021201126703f, 0.67799807151887104f, 0.059301716469861945f, 0.0f, 0.028072693049087508f, 1.0609850577107909f};
        static constexpr mat3f XYZ_to_colorspace{1.7166511879712676f, -0.35567078377639239f, -0.2533662813736598f, -0.66668435183248898f, 1.616481236634939f, 0.015768545813911131f, 0.017639857445310915f, -0.042770613257808655f, 0.94210312123547402f};
        static constexpr vec2f white_point_cie_xy{0.31271f, 0.32902f};
        static constexpr float peak_luminance{10000.0f}; // in candela / m²

        static MAGIK_DEVICE_HOST vec3f encode(vec3f c)
        {
            auto ctf = [](const float V)
            {
                const float m1 = 2610.0f/16384.0f;
                const float m2 = 2523.0f/4096.0f*128.0f;
                const float c1 = 3424.0f/4096.0f;
                const float c2 = 2413.0f/4096.0f*32.0f;
                const float c3 = 2392.0f/4096.0f*32.0f;

                float L_clamped = magik::clamp(0.0f, 1.0f, V);
                float Lm1 = powf(L_clamped, m1);
                float numerator = c1+c2*Lm1;
                float denominator = 1.0f + c3 * Lm1;
                return powf(numerator/denominator, m2);
            };

            return { ctf(c.x), ctf(c.y), ctf(c.z) };
        }

        static MAGIK_DEVICE_HOST vec3f decode(vec3f c)
        {
            auto ctf = [](const float V)
            {
                const float m1 = 2610.0f/16384.0f;
                const float m2 = 2523.0f/4096.0f*128.0f;
                const float c1 = 3424.0f/4096.0f;
                const float c2 = 2413.0f/4096.0f*32.0f;
                const float c3 = 2392.0f/4096.0f*32.0f;

                float N = magik::clamp(0.0f, 1.0f, V);
                float Nm2 = powf(N, 1.0f/m2);
                float numerator = fmaxf(Nm2 - c1, 0.0f);
                float denominator = c2 - c3 * Nm2;
                return powf(numerator/denominator, 1.0f/m1);
            };

            return { ctf(c.x), ctf(c.y), ctf(c.z) };
        }
    };

    template<> struct generic_display_colorspace_t<MAGIK_DISPLAY_COLORSPACE_REC2100_HLG>
    {
        static constexpr mat3f colorspace_to_XYZ{0.636958063f, 0.144616902f, 0.168880969f, 0.262700200f, 0.677998066f, 0.059301715f, 0.000000000f, 0.028072693f, 1.060985090f};
        static constexpr mat3f XYZ_to_colorspace{1.716651200f, -0.355670780f, -0.253366292f, -0.666684330f, 1.616481180f, 0.015768547f, 0.017639857f, -0.042770613f, 0.942103148f};
        static constexpr vec2f white_point_cie_xy{0.31271f, 0.32902f};
        static constexpr float peak_luminance{1000.0f}; // in candela / m²

        static MAGIK_DEVICE_HOST vec3f encode(vec3f c)
        {
            auto ctf = [](const float L)
            {
                const float a = 0.17883277f;
                const float b = 0.28466892f;
                const float c = 0.55991073f;

                float L_norm = magik::clamp(0.0f, 1.0f, L);

                if (L_norm <= 1.0f / 12.0f) return sqrtf(3.0f * L_norm);

                return a*logf(12.0f*L_norm-b)+c;
            };

            return { ctf(c.x), ctf(c.y), ctf(c.z) };
        }

        static MAGIK_DEVICE_HOST vec3f decode(vec3f c)
        {
            auto ctf = [](const float V)
            {
                const float a = 0.17883277f;
                const float b = 0.28466892f;
                const float c = 0.55991073f;

                if(V <= 0.5f) return (V*V)/3.0f;

                return (expf((V-c)/a)+b)/12.0f;
            };

            return { ctf(c.x), ctf(c.y), ctf(c.z) };
        }
    };

    template<> struct generic_display_colorspace_t<MAGIK_DISPLAY_COLORSPACE_DCI_P3_THEATRICAL_WHITE_POINT>
    {
        static constexpr mat3f colorspace_to_XYZ{0.44516982f, 0.27713441f, 0.17228267f, 0.20949168f, 0.72159525f, 0.06891307f, 0.00000000f, 0.04706056f, 0.90735539f};
        static constexpr mat3f XYZ_to_colorspace{2.72539403f, -1.01800301f, -0.44016320f, -0.79516803f, 1.68973205f, 0.02264719f, 0.04124189f, -0.08763902f, 1.10092938f};
        static constexpr vec2f white_point_cie_xy{0.314f, 0.351f};
        static constexpr float peak_luminance{48.0f}; // in candela / m²

        static MAGIK_DEVICE_HOST vec3f encode(vec3f c)
        {
            auto ctf = [](const float L)
            {
                return powf(L, 1.0f/2.6f);
            };

            return { ctf(c.x), ctf(c.y), ctf(c.z) };
        }

        static MAGIK_DEVICE_HOST vec3f decode(vec3f c)
        {
            auto ctf = [](const float V)
            {
                return powf(V, 2.6f);
            };

            return { ctf(c.x), ctf(c.y), ctf(c.z) };
        }
    };

    template<> struct generic_display_colorspace_t<MAGIK_DISPLAY_COLORSPACE_DISPLAY_P3>
    {
        static constexpr mat3f colorspace_to_XYZ{0.486570954f, 0.265667707f, 0.198217288f, 0.228974566f, 0.691738546f, 0.0792869106f, 0.000000000f, 0.045113381f, 1.043944360f};
        static constexpr mat3f XYZ_to_colorspace{2.493496890f, -0.9313836100f, -0.402710795f, -0.829488993f, 1.7626640800f, 0.0236246865f, 0.035845831f, -0.0761723891f, 0.956884503f};
        static constexpr vec2f white_point_cie_xy{0.3127f, 0.3290f};
        static constexpr float peak_luminance{80.0f}; // in candela / m²

        static MAGIK_DEVICE_HOST vec3f encode(vec3f c)
        {
            auto ctf = [](const float L)
            {
                if(L <= 0.0031308f) return 12.92f*L;

                return 1.055f*powf(L,1.0f/2.4f)-0.055f;
            };

            return { ctf(c.x), ctf(c.y), ctf(c.z) };
        }

        static MAGIK_DEVICE_HOST vec3f decode(vec3f c)
        {
            auto ctf = [](const float V)
            {
                if(V <= 0.04045f) return V/12.92f;

                return powf(((V+0.055f)/1.055f), 2.4f);
            };

            return { ctf(c.x), ctf(c.y), ctf(c.z) };
        }
    };

    template<> struct generic_display_colorspace_t<MAGIK_DISPLAY_COLORSPACE_ADOBE_RGB>
    {
        static constexpr mat3f colorspace_to_XYZ{0.57666904f, 0.18555824f, 0.18822865f, 0.29734498f, 0.62736357f, 0.07529146f, 0.02703136f, 0.07068885f, 0.99133754f};
        static constexpr mat3f XYZ_to_colorspace{2.04158790f, -0.56500697f, -0.34473135f, -0.96924364f, 1.87596750f, 0.04155506f, 0.01344428f, -0.11836239f, 1.01517499f};
        static constexpr vec2f white_point_cie_xy{0.3127f, 0.3290f};
        static constexpr float peak_luminance{160.0f}; // in candela / m²

        static MAGIK_DEVICE_HOST vec3f encode(vec3f c)
        {
            auto ctf = [](const float L)
            {
                float L_norm = magik::clamp(0.0f, 1.0f, L);

                return powf(L_norm, 256.0f/563.0f);
            };

            return { ctf(c.x), ctf(c.y), ctf(c.z) };
        }

        static MAGIK_DEVICE_HOST vec3f decode(vec3f c)
        {
            auto ctf = [](const float V)
            {
                return powf(V, 563.0f/256.0f);
            };

            return { ctf(c.x), ctf(c.y), ctf(c.z) };
        }
    };

    using supported_display_colorspaces = colorspaces_list
    <
        e_magik_display_colorspace_types::MAGIK_DISPLAY_COLORSPACE_SRGB,
        e_magik_display_colorspace_types::MAGIK_DISPLAY_COLORSPACE_REC709,
        e_magik_display_colorspace_types::MAGIK_DISPLAY_COLORSPACE_REC2100_PQ,
        e_magik_display_colorspace_types::MAGIK_DISPLAY_COLORSPACE_REC2100_HLG,
        e_magik_display_colorspace_types::MAGIK_DISPLAY_COLORSPACE_DCI_P3_THEATRICAL_WHITE_POINT,
        e_magik_display_colorspace_types::MAGIK_DISPLAY_COLORSPACE_DISPLAY_P3,
        e_magik_display_colorspace_types::MAGIK_DISPLAY_COLORSPACE_ADOBE_RGB
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
