#include "kernel_utility.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"

namespace magik
{
    __global__ static void kernel_swap_queues(ray_queue_t queue_A, ray_queue_t queue_B)
    {
        magik::mswap(*queue_A.d_count, *queue_B.d_count);
        magik::mswap(*queue_A.d_id, *queue_B.d_id);
    }

    void launch_kernel_swap_queues_async(magik_render_manager* manager, ray_queue_t queue_A, ray_queue_t queue_B)
    {
        kernel_swap_queues<<<1, 1, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(queue_A, queue_B);
    }
}
