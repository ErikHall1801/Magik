#pragma once
#include "magik.h"
#include "cuda_host_device_utilities.h"
#include <cstdio>
#include <cstdlib>

#define MAGIK_FORCE_ASSERTS

#if !defined(NDEBUG) || defined(MAGIK_FORCE_ASSERTS)
    #define MAGIK_ASSERTS_ENABLED 1
#else
    #define MAGIK_ASSERTS_ENABLED 0
#endif

namespace magik
{
    [[noreturn]] MAGIK_DEVICE_HOST void assert_fail(const char* expr, const char* msg, const char* file, int line, const char* func)
    {
        #if defined(__CUDA_ARCH__)
            printf("MAGIK_ASSERT failed: %s\n    %s\n    %s:%d in %s\n", expr, msg, file, line, func);
            __trap();
        #else
            fprintf(stderr, "MAGIK ASSERT FAILED: %s\n    %s\n    %s:%d in %s\n", expr, msg, file, line, func);
            #if defined(_MSC_VER)
                __debugbreak();
            #endif
            std::abort();
        #endif
    }
}

#if MAGIK_ASSERTS_ENABLED
    #define MAGIK_ASSERT(cond, msg) do { if(!(cond)) magik::assert_fail(#cond, msg, __FILE__, __LINE__, __func__); } while(0)
#else
    #define MAGIK_ASSERT(cond, msg) do { (void)sizeof(!(cond)); } while(0)
#endif