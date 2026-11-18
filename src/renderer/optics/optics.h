#pragma once

#include "internal_math.h"
#include <cstdint>

/*
* Whats the idea ? 
* This file combines the various sub-components of Magiks optical logic. 
* It also defines various structs and enums. The big question here is 
* how we handle functions. The thin lens has a lot of device functions, 
* where do they go ? Well, of course, a cuh file. 
*/

namespace magik
{
    struct optical_system_t
    {
        // Lens
        float focal_length = 12.0f;
        
        // Sensor
        e_magik_color_matching_function_types cmf_type = MAGIK_CMF_CIE_1931;
        e_magik_scene_colorspace_types scene_colorspace_type = MAGIK_SCENE_COLORSPACE_LINEAR_REC709;
        e_magik_view_transform_types view_transform_type = MAGIK_VIEW_TRANSFORM_KHRONOS_PBR_NEUTRAL;
        e_magik_display_colorspace_types display_colorspace_type = MAGIK_DISPLAY_COLORSPACE_REC709;
        e_magik_output_format_types output_format = MAGIK_OUTPUT_FORMAT_FLOAT32;
        float iso = 1000.0f;
        float white_point = 5600.0f;
        float tint = 0.0f;
        float fps = 24.0f;
        // Shutter type
        // motion blur
        float shutter_angle = 180.0f;
        float sensor_diagonal_mm = 24.0f;
        uint32_t x_resolution = 2195;
        uint32_t y_resolution = 1860;

        // Body (Parasitic heat etc.)

        vec3f position = vec3f{2.0f, 0.0f, 9.0f};
        vec3f local_proper_velocity;
        mat3f orientation = {1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 1.0f};
    };
}
