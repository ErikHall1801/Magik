#include "internal_memory.h"
#include "cuda_memory.cuh"

namespace magik
{
    template<typename T> T* allocate_device(size_t size)
    {
        return cuda_malloc_wrapper<T>(size);
    }

    template<typename T> void free_device(T* d_ptr)
    {
        cuda_free_wrapper<T>(d_ptr);
    }

    template<typename T> T* allocate_host_pinned(size_t size)
    {
        return cuda_malloc_page_locked_wrapper<T>(size);
    }

    template<typename T> void free_host_pinned(T* h_ptr)
    {
        cuda_free_page_locked_wrapper<T>(size);
    }

    template<typename T> T* allocate_host(size_t size)
    {
        return (T*)malloc(size);
    }

    template<typename T> void free_host(T* h_ptr)
    {
        free(h_ptr);
    }

    template<typename T> void memcpy_device_to_host(T* d_ptr, T* h_ptr, size_t size)
    {
        cuda_memcpy_device_to_host<T>(d_ptr, h_ptr, size);
    }

    template<typename T> void memcpy_host_to_device(T* h_ptr, T* d_ptr, size_t size)
    {
        cuda_memcpy_host_to_device<T>(h_ptr, d_ptr, size);
    }

    template<typename T> void memcpy_device_to_device(T* d_ptr_a, T* d_ptr_b, size_t size)
    {
        cuda_memcpy_device_to_device<T>(d_ptr_a, d_ptr_b, size);
    }
}
