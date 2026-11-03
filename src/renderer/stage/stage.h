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
        vec3f box_min = {-10.0f, 0.0f, -10.0f};
        vec3f light_max = {5.0f, 10.5f, 5.0f};
        vec3f light_min = {-5.0f, 9.5f, -5.0f};
    };
}
