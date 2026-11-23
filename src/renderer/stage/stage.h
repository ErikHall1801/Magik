#pragma once

#include "relativity_settings.h"
#include "optical_system_settings.h"
#include "color_settings.h"
#include "render_settings.h"

namespace magik
{
    struct stage_t
    {
        // The idea is that all of these would be part of a scene 

        relativity_settings_t relativity_settings;
        optical_system_settings_t optical_system_settings;
        color_settings_t color_settings;
        render_settings_t render_settings;

        vec3f box_max = {20.0f, 10.0f, 20.0f};
        vec3f box_min = {-20.0f, -10.0f, -20.0f};
        vec3f light_max = {10.0f, 10.5f, 10.0f};
        vec3f light_min = {-10.0f, 9.5f, -10.0f};
    };
}
