#pragma once

#include <stdint.h>
#include <cuda_runtime_api.h>

namespace magik
{
    /*
    Design notes;

    A device arena is a host managed object. This is what the 
    d_base pointer is for. 

    By default the memory is 256 bit alligned. 
    */

    constexpr uint64_t DEVICE_ARENA_DEFAULT_ALIGN = 256;

    struct device_mem_arena
    {
        uint8_t* d_base;
        uint64_t base_offset;
        uint64_t capacity;
    };

    static inline device_mem_arena device_arena_create_async(cudaStream_t user_stream, uint64_t size)
    {
        device_mem_arena arena {};
        check_cuda_errors(cudaMallocAsync((void**)arena.d_base, size, user_stream));
        arena.base_offset = 0;
        arena.capacity = size;
        return arena;
    }

    static inline void device_arena_destroy_async(cudaStream_t user_stream, device_mem_arena* arena)
    {
        check_cuda_errors(cudaFreeAsync(arena->d_base, user_stream));
        *arena = {};
    }

    static inline void* device_arena_push(device_mem_arena* arena, uint64_t size, uint64_t align = DEVICE_ARENA_DEFAULT_ALIGN)
    {
        uint64_t addr  = (uint64_t)arena->d_base + arena->base_offset;
        uint64_t start = (((addr + align - 1) & ~(align - 1)) - (uint64_t)arena->d_base);

        if (start > arena->capacity || size > arena->capacity - start) return nullptr;

        arena->base_offset = start + size;
        return arena->d_base + start;
    }

    static inline void device_arena_clear(cudaStream_t user_stream, device_mem_arena* arena)
    {
        arena->base_offset = 0;
    }
}
