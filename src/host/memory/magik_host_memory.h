#pragma once
#include "magik.h"
#include "magik_error.h"
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

    e_magik_result_types arena_create(magik_render_manager* manager, host_mem_arena** arena, uint64_t reserve_size, uint64_t commit_size, host_mem_reserve_function user_host_mem_reserve_func, host_mem_commit_function user_host_mem_commit_func);

    void arena_destroy(magik_render_manager* manager, host_mem_arena* host_arena, host_mem_release_function user_host_mem_release_func);

    e_magik_result_types arena_push(magik_render_manager* manager, host_mem_arena* host_arena, void** dst_ptr, uint64_t size, host_mem_commit_function user_host_mem_commit_func, bool non_zero);

    void arena_pop(magik_render_manager* manager, host_mem_arena* host_arena, uint64_t size);

    void arean_pop_to(magik_render_manager* manager, host_mem_arena* host_arena, uint64_t pos);

    void arena_clear(magik_render_manager* manager, host_mem_arena* host_arena); 
}
