#pragma once
#include "magik.h"
#include "internal_error.h"
#include <stdint.h>
#include <memory>
#include <atomic>
#include <cstring>

#if defined(_WIN32)
    #include <windows.h>
#elif defined(__linux__)
    #define _DEFAULT_SOURCE
    #include <unistd.h>
    #include <sys/mman.h>
#endif

#define KiB(n) ((uint64_t)(n) << 10)
#define MiB(n) ((uint64_t)(n) << 20)
#define GiB(n) ((uint64_t)(n) << 30)

#define MIN(a, b) (((a) < (b)) ? (a) : (b))
#define MAX(a, b) (((a) > (b)) ? (a) : (b))
#define ARENA_ALIGN (sizeof(void*))
#define AREAN_BASE_POS (sizeof(host_mem_arena))
#define ALIGN_UP_POW2(n, p) (((uint64_t)(n) + ((uint64_t)(p) - 1)) & (~((uint64_t)(p) - 1)))

namespace magik
{
    // In the future we will want to expand this logic to accept user-defined malloc and free 
    // alternatives. 

    struct host_mem_arena
    {
        uint8_t* h_base = nullptr;
        uint64_t base_offset = 0;
        uint64_t capacity = 0;
    };

    static inline host_mem_arena host_arena_create(uint64_t size)
    {
        host_mem_arena arena{};
        void* p = nullptr;
        p = std::malloc(size);
        arena.h_base = static_cast<uint8_t*>(p);
        arena.base_offset = 0;
        arena.capacity = size;
        return arena;
    }

    static inline void host_arena_destroy(host_mem_arena* arena)
    {
        if(arena->h_base == nullptr) return;

        std::free(arena->h_base);
        *arena = {};
    }

    static inline void* host_arena_push(host_mem_arena* arena, uint64_t size, uint64_t align = 256)
    {
        uint64_t addr = (uint64_t)arena->h_base + arena->base_offset;
        uint64_t start = (((addr + align - 1) & ~(align - 1)) - (uint64_t)arena->h_base);

        if (start > arena->capacity || size > arena->capacity - start) return nullptr;

        arena->base_offset = start + size;
        return arena->h_base + start;
    }

    static inline void host_arena_clear(host_mem_arena* arena)
    {
        arena->base_offset = 0;
    }
}
