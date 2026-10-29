#pragma once

namespace magik
{
    template<typename T> T* allocate_device(size_t size);

    template<typename T> void free_device(T* d_ptr);

    template<typename T> T* allocate_host_pinned(size_t size);

    template<typename T> void free_host_pinned(T* h_ptr);

    template<typename T> T* allocate_host(size_t size);

    template<typename T> void free_host(T* h_ptr);

    template<typename T> void memcpy_device_to_host(T* d_ptr, T* h_ptr, size_t size);

    template<typename T> void memcpy_host_to_device(T* h_ptr, T* d_ptr, size_t size);

    template<typename T> void memcpy_device_to_device(T* d_ptr_a, T* d_ptr_b, size_t size);
}
