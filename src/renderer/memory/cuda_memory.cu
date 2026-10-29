#include "cuda_memory.cuh"
#include <stdint.h>
#include <cstddef>
#include <cuda_runtime.h>
#include <curand_kernel.h>

namespace magik
{
    template<typename T> T* cuda_malloc_wrapper(size_t size)
    {
        T* d_ptr;
        cudaMalloc(&d_ptr, size);
        return d_ptr;
    }

    template<typename T> void cuda_free_wrapper(T* d_ptr)
    {
        cudaFree(d_ptr);
    }

    template<typename T> T* cuda_malloc_page_locked_wrapper(size_t size)
    {
        T* h_ptr;
        cudaMallocHost(&h_ptr, size);
        return h_ptr;
    }

    template<typename T> void cuda_free_page_locked_wrapper(T* h_ptr)
    {
        cudaFreeHost(h_ptr);
    }

    template<typename T> void cuda_memcpy_host_to_device(T* h_ptr, T* d_ptr, size_t size)
    {
        cudaMemcpy(d_ptr, h_ptr, size, cudaMemcpyDeviceToHost);
    }

    template<typename T> void cuda_memcpy_device_to_host(T* d_ptr, T* h_ptr, size_t size)
    {
        cudaMemcpy(d_ptr, h_ptr, size, cudaMemcpyHostToDevice);
    }

    template<typename T> void cuda_memcpy_device_to_device(T* d_ptr_a, T* d_ptr_b, size_t size)
    {
        cudaMemcpy(d_ptr_a, d_ptr_b, size, cudaMemcpyDeviceToDevice);
    }
}
