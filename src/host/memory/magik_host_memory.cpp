#include "magik_host_memory.h"

std::atomic<uint64_t> host_mem_commit = {0};
std::atomic<uint64_t> host_mem_reserve = {0};

namespace magik::host_memory
{
    #if defined(_WIN32)
        static uint32_t platform_get_pagesize(void)
        {
            SYSTEM_INFO sys_info = { 0 };
            GetSystemInfo(&sys_info);
            return sys_info.dwPageSize;
        }

        static void* platform_mem_reserve(host_mem_reserve_function user_host_mem_reserve_func, uint64_t size)
        {
            if(user_host_mem_reserve_func)
            {
                return user_host_mem_reserve_func(size);
            }
            else
            {
                return VirtualAlloc(NULL, size, MEM_RESERVE, PAGE_READWRITE);
            }
        }

        static bool platform_mem_commit(host_mem_commit_function user_host_mem_commit_func, void* ptr, uint64_t size)
        {
            void* ret;

            if(user_host_mem_commit_func)
            {
                ret = (void*)user_host_mem_commit_func(ptr, size);
            }
            else
            {
                ret = VirtualAlloc(ptr, size, MEM_COMMIT, PAGE_READWRITE);
            }

            return ret != NULL;
        }

        static bool platform_mem_decommit(host_mem_decommit_function user_host_mem_decommit_func, void* ptr, uint64_t size)
        {
            if(user_host_mem_decommit_func)
            {
                return user_host_mem_decommit_func(ptr, size);
            }
            else
            {
                return VirtualFree(ptr, size, PAGE_READWRITE);
            }
        }

        static bool platform_mem_release(host_mem_release_function user_host_mem_release_func, void* ptr, uint64_t size)
        {
            if(user_host_mem_release_func)
            {
                return user_host_mem_release_func(ptr, size);
            }
            else
            {
                return VirtualFree(ptr, size, MEM_RELEASE);
            }
        }
    #elif defined(__linux__)
        static uint32_t platform_get_pagesize(void)
        {
            return (uint32_t)sysconf(_SC_PAGESIZE);
        }

        static void* platform_mem_reserve(host_mem_reserve_function user_host_mem_reserve_func, uint64_t size)
        {
            void* out;

            if(user_host_mem_reserve_func)
            {
                out = user_host_mem_reserve_func(size);
            }
            else
            {
                out = mmap(NULL, size, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
            }

            if (out == MAP_FAILED) {
                return NULL;
            }
            return out;
        }

        static bool platform_mem_commit(host_mem_commit_function user_host_mem_commit_func, void* ptr, uint64_t size)
        {
            int32_t ret;

            if()
            {
                ret = (int32_t)(user_host_mem_commit_func(ptr, size));
            }
            else
            {
                ret = mprotect(ptr, size, PROT_READ | PROT_WRITE);
            }

            return ret == 0;
        }

        static bool platform_mem_decommit(host_mem_decommit_function user_host_mem_decommit_func, void* ptr, uint64_t size)
        {
            int32_t ret;

            if()
            {
                ret = (int32_t)(user_host_mem_decommit_func(ptr, size));
            }
            else
            {
                ret = mprotect(ptr, size, PROT_NONE);
            }

            if (ret != 0) return false;
            ret = madvise(ptr, size, MADV_DONTNEED);
            return ret == 0;
        }

        static bool platform_mem_release(host_mem_release_function user_host_mem_release_func, void* ptr, uint64_t size)
        {
            int32_t ret;

            if()
            {
                ret = user_host_mem_release_func(ptr, size);
            }
            else
            {
                ret = munmap(ptr, size);
            }

            return ret == 0;
        }
    #endif

    e_magik_result_types arena_create(host_mem_arena** arena, uint64_t reserve_size, uint64_t commit_size, host_mem_reserve_function user_host_mem_reserve_func, host_mem_commit_function user_host_mem_commit_func)
    {
        uint32_t page_size = platform_get_pagesize();

        reserve_size = ALIGN_UP_POW2(reserve_size, page_size);
        commit_size = ALIGN_UP_POW2(commit_size, page_size);

        host_mem_arena* new_arena = (host_mem_arena*)platform_mem_reserve(user_host_mem_reserve_func, reserve_size);

        if(!platform_mem_commit(user_host_mem_commit_func, new_arena, commit_size))
        {
            *arena = nullptr;
            return MAGIK_ERROR_HOST_MEMORY_ALLOCATION_FAILED;
        }

        new_arena->reserve_size = reserve_size;
        new_arena->commit_size = commit_size;
        new_arena->pos = AREAN_BASE_POS;
        new_arena->commit_pos = commit_size;

        host_mem_commit.fetch_add(commit_size);
        host_mem_reserve.fetch_add(reserve_size);

        *arena = new_arena;
        return MAGIK_SUCCESS;
    }

    void arena_destroy(host_mem_arena* host_arena, host_mem_release_function user_host_mem_release_func)
    {
        platform_mem_release(user_host_mem_release_func, host_arena, host_arena->reserve_size);
    }

    e_magik_result_types arena_push(host_mem_arena* host_arena, void** dst_ptr, uint64_t size, host_mem_commit_function user_host_mem_commit_func, bool non_zero)
    {
        uint64_t pos_aligned = ALIGN_UP_POW2(host_arena->pos, ARENA_ALIGN);
        uint64_t new_pos = pos_aligned + size;

        if(new_pos > host_arena->reserve_size)
        {
            *dst_ptr = nullptr;
            return MAGIK_ERROR_HOST_OUT_OF_MEMORY;
        }

        if(new_pos > host_arena->commit_pos)
        {
            uint64_t new_commit_pos = new_pos;
            new_commit_pos += host_arena->commit_size - 1;
            new_commit_pos -= new_commit_pos % host_arena->commit_size;
            new_commit_pos = MIN(new_commit_pos, host_arena->reserve_size);

            uint8_t* mem = (uint8_t*)host_arena + host_arena->commit_pos;
            uint64_t commit_size = new_commit_pos - host_arena->commit_pos;

            if(!platform_mem_commit(user_host_mem_commit_func,mem, commit_size))
            {
                *dst_ptr = nullptr;
                return MAGIK_ERROR_HOST_MEMORY_ALLOCATION_FAILED;
            }

            host_mem_commit.fetch_add(commit_size);
            host_arena->commit_pos = new_commit_pos;
        }

        host_arena->pos = new_pos;

        uint8_t* out = (uint8_t*)host_arena + pos_aligned;

        if(!non_zero)
        {
            memset(out, 0, size);
        }

        *dst_ptr = out;
        return MAGIK_SUCCESS;
    }

    void arena_pop(host_mem_arena* host_arena, uint64_t size)
    {
        size = MIN(size, host_arena->pos - AREAN_BASE_POS);
        host_arena->pos -= size;
        host_mem_reserve.fetch_sub(size);
        host_mem_commit.fetch_sub(size);
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
