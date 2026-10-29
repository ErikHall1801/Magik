#include "cuda_host_utilities.h"
#include "cuda_device_utilities.cuh"

namespace magik
{
    void set_cuda_device(uint32_t cuda_device)
    {
        check_cuda_errors(cudaSetDevice(cuda_device));
    }
}
