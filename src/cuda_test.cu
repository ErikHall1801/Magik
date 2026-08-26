#include <cuda_runtime.h>

__global__ void test_gradient_kernel(int width, int height, float* r, float* g, float* b)
{
    int x = blockIdx.x*blockDim.x + threadIdx.x;
    int y = blockIdx.y*blockDim.y + threadIdx.y;

    float fx = static_cast<float>(x)/static_cast<float>(width - 1);
    float fy = static_cast<float>(x)/static_cast<float>(height - 1);

    r[y*width + x] = fx*255.0f;
    g[y*width + x] = fy*255.0f;
    b[y*width + x] = 128.0f;
}