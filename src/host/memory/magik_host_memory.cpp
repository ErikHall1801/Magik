#include "magik_host_memory.h"

namespace magik::host_memory
{
    #if defined(_WIN32)
        static uint32_t platform_get_pagesize(void)
        {
            SYSTEM_INFO sys_info = { 0 };
            GetSystemInfo(&sys_info);
            return sys_info.dwPageSize;
        }

        static void* platform_mem_reserve(uint64_t size)
        {
            return VirtualAlloc(NULL, size, MEM_RESERVE, PAGE_READWRITE);
        }

        static bool platform_mem_commit(void* ptr, uint64_t size)
        {
            void* ret = VirtualAlloc(ptr, size, MEM_COMMIT, PAGE_READWRITE);
            return ret != NULL;
        }

        static bool platform_mem_decommit(void* ptr, uint64_t size)
        {
            return VirtualFree(ptr, size, PAGE_READWRITE);
        }

        static bool platform_mem_release(void* ptr, uint64_t size)
        {
            return VirtualFree(ptr, size, MEM_RELEASE);
        }
    #elif defined(__linux__)
        static uint32_t platform_get_pagesize(void)
        {
            return (u32)sysconf(_SC_PAGESIZE);
        }

        static void* platform_mem_reserve(uint64_t size)
        {
            void* out = mmap(NULL, size, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
            if (out == MAP_FAILED) {
                return NULL;
            }
            return out;
        }

        static bool platform_mem_commit(void* ptr, uint64_t size)
        {
            i32 ret = mprotect(ptr, size, PROT_READ | PROT_WRITE);
            return ret == 0;
        }

        static bool platform_mem_decommit(void* ptr, uint64_t size)
        {
            i32 ret = mprotect(ptr, size, PROT_NONE);
            if (ret != 0) return false;
            ret = madvise(ptr, size, MADV_DONTNEED);
            return ret == 0;
        }

        static bool platform_mem_release(void* ptr, uint64_t size)
        {
            i32 ret = munmap(ptr, size);
            return ret == 0;
        }
    #endif

    host_mem_arena* arena_create(uint64_t reserve_size, uint64_t commit_size)
    {
        // TO-DO: Use user defined allocator matching the type

        uint32_t page_size = platform_get_pagesize();

        reserve_size = ALIGN_UP_POW2(reserve_size, page_size);
        commit_size = ALIGN_UP_POW2(commit_size, page_size);

        host_mem_arena* arena = (host_mem_arena*)platform_mem_reserve(reserve_size);

        if(!platform_mem_commit(arena, commit_size))
        {
            return nullptr;
        }

        arena->reserve_size = reserve_size;
        arena->commit_size = commit_size;
        arena->pos = AREAN_BASE_POS;
        arena->commit_pos = commit_size;

        return arena;
    }

    void arena_destroy(host_mem_arena* host_arena)
    {
        // TO-DO; Use user defined free function matching the type
        platform_mem_release(host_arena, host_arena->reserve_size);
    }

    void* arena_push(host_mem_arena* host_arena, uint64_t size, bool non_zero)
    {
        uint64_t pos_aligned = ALIGN_UP_POW2(host_arena->pos, ARENA_ALIGN);
        uint64_t new_pos = pos_aligned + size;

        if(new_pos > host_arena->reserve_size)
        {
            // To-Do; Allocate a new sub-arena, so it dynamically resizes. 
            return nullptr;
        }

        if(new_pos > host_arena->commit_pos)
        {
            uint64_t new_commit_pos = new_pos;
            new_commit_pos += host_arena->commit_size - 1;
            new_commit_pos -= new_commit_pos % host_arena->commit_size;
            new_commit_pos = MIN(new_commit_pos, host_arena->reserve_size);

            uint8_t* mem = (uint8_t*)host_arena + host_arena->commit_pos;
            uint64_t commit_size = new_commit_pos - host_arena->commit_pos;

            if(!platform_mem_commit(mem, commit_size))
            {
                return nullptr;
            }

            host_arena->commit_pos = new_commit_pos;
        }

        host_arena->pos = new_pos;

        uint8_t* out = (uint8_t*)host_arena + pos_aligned;

        if(!non_zero)
        {
            memset(out, 0, size);
        }

        return out;
    }

    void arena_pop(host_mem_arena* host_arena, uint64_t size)
    {
        size = MIN(size, host_arena->pos - AREAN_BASE_POS);
        host_arena->pos -= size;
    }

    void arean_pop_to(host_mem_arena* host_arena, uint64_t pos)
    {
        uint64_t size = pos < host_arena->pos ? host_arena->pos - pos : 0;
        arena_pop(host_arena, size);
    }

    void arena_clear(host_mem_arena* host_arena)
    {
        arean_pop_to(host_arena, AREAN_BASE_POS);
    }
}
