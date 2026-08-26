#include <cuda_runtime.h>
#include "magik.h"

__device__ bool is_valid_thread(const unsigned int x_resolution, const unsigned int y_resolution)
{
    unsigned int i_x = threadIdx.x + blockIdx.x*blockDim.x;
    unsigned int i_y = threadIdx.y + blockIdx.y*blockDim.y;
    bool cond = (i_x < x_resolution) && (i_y < y_resolution);

    return cond;
}

__device__ unsigned int get_thread_id(const unsigned int x_resolution)
{
    unsigned int i_x = threadIdx.x + blockIdx.x*blockDim.x;
    unsigned int i_y = threadIdx.y + blockIdx.y*blockDim.y;
    return i_y*x_resolution + i_x;
}

__device__ unsigned int get_pixel_id(const unsigned int x_resolution)
{
    unsigned int i_x = threadIdx.x + blockIdx.x*blockDim.x;
    unsigned int i_y = threadIdx.y + blockIdx.y*blockDim.y;
    return i_y*x_resolution*4 + i_x*4;
}

__global__ void test_gradient_kernel(float* data, const unsigned int x_resolution, const unsigned int y_resolution)
{
    unsigned int pixel_id = get_pixel_id(x_resolution);
    
    unsigned int i_x = threadIdx.x + blockIdx.x*blockDim.x;
    unsigned int i_y = threadIdx.y + blockIdx.y*blockDim.y;
    
    float fx = static_cast<float>(i_x)/static_cast<float>(x_resolution - 1);
    float fy = static_cast<float>(i_y)/static_cast<float>(y_resolution - 1);


    if (!data) return;

    data[pixel_id] = fx;
    data[pixel_id + 1] = fy;
    data[pixel_id + 2] = 0.5;
    data[pixel_id + 3] = 1.0f;
}