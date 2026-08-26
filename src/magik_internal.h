#ifndef MAGIK_INTERNAL_H
#define MAGIK_INTERNAL_H

#include <stdint.h>
#include "magik.h"

struct magik_rgba_test_frame_buffer_t
{
    uint32_t x_res = 0;
    uint32_t y_res = 0;
    float* data = nullptr;
};

#endif