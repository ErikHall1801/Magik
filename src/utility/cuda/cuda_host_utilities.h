#pragma once

#include <cstdint>
#include <cuda_runtime_api.h>

namespace magik
{
    void check_cuda(cudaError_t result, char const* const func, const char* const file, int const line);

    #define check_cuda_errors(val) magik::check_cuda( (val), #val, __FILE__, __LINE__ )

    void set_cuda_device(uint32_t cuda_device);

    void printf_system_info();

    int32_t get_cuda_device_count();

    void create_cuda_stream(void** user_stream);

    void destroy_cuda_stream(void** user_stream);
}
