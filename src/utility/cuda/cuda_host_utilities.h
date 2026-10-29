#pragma once

#include <stdint.h>

namespace magik
{
    void set_cuda_device(uint32_t cuda_device);

    void printf_system_info();

    int32_t get_cuda_device_count();

    void create_cuda_stream(void** user_stream);

    void destroy_cuda_stream(void** user_stream);
}
