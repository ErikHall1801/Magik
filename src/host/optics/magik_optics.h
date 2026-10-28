#pragma once

#include "magik_thin_lens.h"

namespace magik::optics
{
    typedef enum e_magik_objective_types
    {
        thin = 0,
        orthorgraphic = 1,
        equirectangular = 2,
        physical = 3,
    } e_magik_objective_types;

    struct objective
    {
        e_magik_objective_types lens_type = thin;

        magik::lens::thin::properties thin_lens_properties;
    };

    typedef enum e_magik_sensor_types
    {
        ideal = 0,
        photographic_film = 1,
        ccd = 2,
        cmos = 3
    } e_magik_sensor_types;

    struct sensor
    {
        e_magik_sensor_types sensor_type = ideal;

        float diagonal_mm = 24.0f;
        uint32_t x_resolution = 2195;
        uint32_t y_resolution = 1860;
    };

    struct camera
    {
        /* Objective */
        magik::optics::objective objective_properties;

        /* Sensor */
        magik::optics::sensor sensor_properties;

        /* World space */
        float pos_x = 0.0f;
        float pos_y = 0.0f;
        float pos_z = 0.0f;

        /* Orientation */
        float rot_x = 0.0f;
        float rot_y = 0.0f;
        float rot_z = 0.0f;
    };
}
