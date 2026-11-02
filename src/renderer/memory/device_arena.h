#pragma once

#include <stdint.h>
#include <cuda_runtime_api.h>
#include "cuda_host_utilities.h"

namespace magik
{
    /*
    Design notes;

    A device arena is a host managed object. This is what the 
    d_base pointer is for. 

    By default the memory is 256 bit alligned. 
    */

    struct device_mem_arena
    {
        uint8_t* d_base = nullptr;
        uint64_t base_offset = 0;
        uint64_t capacity = 0;
    };

    static inline device_mem_arena device_arena_create_async(cudaStream_t user_stream, uint64_t size)
    {
        device_mem_arena arena {};
        void* p = nullptr;
        check_cuda_errors(cudaMallocAsync(&p, size, user_stream));
        arena.d_base = static_cast<uint8_t*>(p);
        arena.base_offset = 0;
        arena.capacity = size;
        return arena;
    }

    static inline void device_arena_destroy_async(cudaStream_t user_stream, device_mem_arena* arena)
    {
        if(arena->d_base == nullptr) return;

        check_cuda_errors(cudaFreeAsync(arena->d_base, user_stream));
        *arena = {};
    }

    static inline void* device_arena_push(device_mem_arena* arena, uint64_t size, uint64_t align = 256) // 256 byte alignment is good for GPUs
    {
        uint64_t addr  = (uint64_t)arena->d_base + arena->base_offset;
        uint64_t start = (((addr + align - 1) & ~(align - 1)) - (uint64_t)arena->d_base);

        if (start > arena->capacity || size > arena->capacity - start) return nullptr;

        arena->base_offset = start + size;
        return arena->d_base + start;
    }

    static inline void device_arena_clear(device_mem_arena* arena)
    {
        arena->base_offset = 0;
    }
}
