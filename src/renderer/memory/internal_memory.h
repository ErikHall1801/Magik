#pragma once

#include <cstddef>
#include <cstdlib>
#include <cuda_runtime_api.h>
#include "cuda_host_utilities.h"

namespace magik
{
    template<typename T> inline T* allocate_device(size_t size)
    {
        T* d_ptr = nullptr;
        check_cuda_errors(cudaMalloc(reinterpret_cast<void**>(&d_ptr), size));
        return d_ptr;
    }

    template<typename T> inline void free_device(T* d_ptr)
    {
        check_cuda_errors(cudaFree(d_ptr));
    }

    template<typename T> inline T* allocate_host_pinned(size_t size)
    {
        T* h_ptr = nullptr;
        check_cuda_errors(cudaMallocHost(reinterpret_cast<void**>(&h_ptr), size));
        return h_ptr;
    }

    template<typename T> inline void free_host_pinned(T* h_ptr)
    {
        check_cuda_errors(cudaFreeHost(h_ptr));
    }

    template<typename T> inline T* allocate_host(size_t size)
    {
        return static_cast<T*>(std::malloc(size));
    }

    template<typename T> inline void free_host(T* h_ptr)
    {
        std::free(h_ptr);
    }

    template<typename T> inline void memcpy_device_to_host(T* d_ptr, T* h_ptr, size_t size)
    {
        check_cuda_errors(cudaMemcpy(h_ptr, d_ptr, size, cudaMemcpyDeviceToHost));
    }

    template<typename T> inline void memcpy_host_to_device(T* h_ptr, T* d_ptr, size_t size)
    {
        check_cuda_errors(cudaMemcpy(d_ptr, h_ptr, size, cudaMemcpyHostToDevice));
    }

    template<typename T> inline void memcpy_device_to_device(T* d_ptr_a, T* d_ptr_b, size_t size)
    {
        check_cuda_errors(cudaMemcpy(d_ptr_a, d_ptr_b, size, cudaMemcpyDeviceToDevice));
    }

    template<typename T> inline void memset_async(T* d_ptr, T value, size_t size, void* user_stream)
    {
        check_cuda_errors(cudaMemsetAsync(d_ptr, value, size, user_stream));
    }
}