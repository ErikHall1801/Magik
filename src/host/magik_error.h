/*
* This is a shared types library designed to be usable in both CPU and GPU code. Moreover, this 
* header is used in the user facing part of the API and thus has to comply with the C-style. 
*/

#pragma once
#include "magik.h"

#ifdef __CUDACC__
    #define MAGIK_HD __host__ __device__ 
    #define MAGIK_INLINE __forceinline__ __host__ __device__
#else
    #define MAGIK_HD
    #define MAGIK_INLINE inline
#endif

#ifdef __cplusplus
extern "C" {
#endif

/**
* [SECTION] Error handling & result types
*/

void magik_set_error_callback_internal(magik_error_callback callback, void* user_data);

e_magik_result_types magik_get_last_error_internal(void);

void check_magik_internal(e_magik_result_types result, char const* func, const char* const file, int const line);

extern thread_local e_magik_result_types g_last_error;

#ifdef __cplusplus
}
#endif
