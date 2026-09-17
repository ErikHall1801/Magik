#pragma once
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

namespace magik::host_memory
{
    struct host_mem_arena
    {
        uint64_t reserve_size; // This does not change once the arena has been created. 
        uint64_t commit_size; // But this is also not changing ? 

        uint64_t pos; // Where the actual memory is 
        uint64_t commit_pos; // Where the committed memory is 
    };

    host_mem_arena* arena_create(uint64_t reserve_size, uint64_t commit_size);

    void arena_destroy(host_mem_arena* host_arena);

    void* arena_push(host_mem_arena* host_arena, uint64_t size, bool non_zero);

    void arena_pop(host_mem_arena* host_arena, uint64_t size);

    void arean_pop_to(host_mem_arena* host_arena, uint64_t pos);

    void arena_clear(host_mem_arena* host_arena); 
}

extern std::atomic<uint64_t> host_mem_commit;
extern std::atomic<uint64_t> host_mem_reserve;
