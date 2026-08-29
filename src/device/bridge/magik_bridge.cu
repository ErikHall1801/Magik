#include "magik_bridge.h"
#include "../kernels/magik_test_pattern.cuh"

namespace magik::bridge
{
    template<typename T> static  T* allocate_device_memory(size_t size)
    {
        T* d_ptr = nullptr;
        cudaMalloc(&d_ptr, size);
        return d_ptr;
    }

    template<typename T> static  T* allocate_host_memory(size_t size)
    {
        T* h_ptr = nullptr;
        cudaMallocHost(&h_ptr, size);
        return h_ptr;
    }

    template<typename T> static void destroy_device_memory(T* ptr)
    {
        cudaFree(ptr);
    }

    template<typename T> static void destroy_host_memory(T* ptr)
    {
        cudaFreeHost(ptr);
    }

    template<typename T> static void memcpy_device_to_host(T* h_ptr, T* d_ptr, size_t size)
    {
        cudaMemcpy(h_ptr, d_ptr, size, cudaMemcpyDeviceToHost);
    }

    float* host_allocate_device_memory(size_t size)
    {
        return allocate_device_memory<float>(size);
    }

    float* host_allocate_host_memory(size_t size)
    {
        return allocate_host_memory<float>(size);
    }

    void host_destroy_device_memory(float* d_ptr)
    {
        destroy_device_memory<float>(d_ptr);
    }

    void host_destroy_host_memory(float* h_ptr)
    {
        destroy_host_memory<float>(h_ptr);
    }

    void host_memcpy_device_to_host(float* h_ptr, float* d_ptr, size_t size)
    {
        memcpy_device_to_host<float>(h_ptr, d_ptr, size);
    }

    void call_test_pattern_gradient_kernel(float* d_rgba_fb, uint32_t x_resolution, uint32_t y_resolution)
    {
        magik::kernels::launch_test_pattern_gradient(d_rgba_fb, x_resolution, y_resolution, 16, 16);
    }

    void call_test_pattern_mandelbrot_kernel(float* d_rgba_fb, uint32_t x_resolution, uint32_t y_resolution)
    {
        magik::kernels::launch_test_pattern_mandelbrot(d_rgba_fb, x_resolution, y_resolution, 16, 16);
    }
}
