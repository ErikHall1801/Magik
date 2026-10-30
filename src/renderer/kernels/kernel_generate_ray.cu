#include "kernel_generate_ray.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"

namespace magik
{
    static __global__ void kernel_generate_ray()
    {

    }

    void launch_kernel_generate_ray(void* user_stream, const uint32_t x_threads_per_block, const uint32_t y_threads_per_block, ray_pool_t ray_pool, ray_queue_t kernel_advance_queue, float focal_length, float sensor_diagonal_mm, vec3f position, mat3f orientation)
    {

    }
}
