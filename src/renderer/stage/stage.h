#pragma once

#include "optics.h"
#include "render_settings.h"

namespace magik
{
    struct stage_t
    {
        optical_system_t optical_systen;

        render_settings_t settings;

        vec3f box_max = {10.0f, 10.0f, 10.0f};
        vec3f box_min = {-10.0f, -10.0f, -10.0f};
        vec3f light_max = {5.0f, 10.5f, 5.0f};
        vec3f light_min = {-5.0f, 9.5f, -5.0f};

        float schwarzschild_mass = 6.7329546075E26f;

        float kerr_mass = 6.7329546075E26f;
        float kerr_spin = 0.999f;

        float event_horizon_scalar = 1.0001f;
    };
}
