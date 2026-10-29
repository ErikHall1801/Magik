#pragma once

namespace magik
{
    template<typename T> T* cuda_malloc_wrapper(size_t size);

    template<typename T> void cuda_free_wrapper(T* d_ptr);

    template<typename T> T* cuda_malloc_page_locked_wrapper(size_t size);

    template<typename T> void cuda_free_page_locked_wrapper(T* h_ptr);

    template<typename T> void cuda_memcpy_host_to_device(T* h_ptr, T* d_ptr, size_t size);

    template<typename T> void cuda_memcpy_device_to_host(T* d_ptr, T* h_ptr, size_t size);

    template<typename T> void cuda_memcpy_device_to_device(T* d_ptr_a, T* d_ptr_b, size_t size);
}
