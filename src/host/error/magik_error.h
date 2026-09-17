#pragma once
#include "magik.h"
#include <initializer_list>

#ifdef __CUDACC__
    #define MAGIK_HD __host__ __device__ 
    #define MAGIK_INLINE __forceinline__ __host__ __device__
#else
    #define MAGIK_HD
    #define MAGIK_INLINE inline
#endif

/**
* [SECTION] Error handling & result types
*/

// DEPRICATED
#define set_and_return_error(val) { g_last_error = val; return val; }
#define set_g_last_error(val) { if(g_last_error == MAGIK_SUCCESS) { g_last_error = val; } }

/*
* 
* These try/catch/propagate blocks are for the internal API use
* 
*/
inline bool magik_error_matches(e_magik_result_types error, std::initializer_list<e_magik_result_types> filters)
{
    if(error == MAGIK_SUCCESS) return false;

    if(filters.size() == 0) return true; // Catch all
    
    for(auto f : filters)
    {
        if(f == error) return true;
    }

    return false;
}

#define MAGIK_PROPAGATE(expr) \
    do { \
        e_magik_result_types _magik_p = (expr); \
        if (_magik_p != MAGIK_SUCCESS) { \
            return _magik_p; \
        } \
    } while (0)

#define MAGIK_RETURN(val) \
    do { \
        return (val); \
    } while (0)

#define MAGIK_TRY_CATCH(var, expr, ...) \
    if (e_magik_result_types var = (expr); magik_error_matches(var, {__VA_ARGS__}))

#define MAGIK_SET_ERROR_ORDERED(c_err, n_err) \
    if(c_err == MAGIK_SUCCESS){c_err = n_err;}

namespace magik::error
{
    /*
    * 
    * check_magik_error and check_error_internal are DCC exclusive. The API never calls these
    * internally. 
    * 
    */
    void set_error_callback_internal(magik_error_callback callback, void* user_data);

    e_magik_result_types get_last_error_internal(void);

    void check_error_internal(e_magik_result_types result, char const* func, const char* const file, int const line);
}

#ifdef __cplusplus
extern "C" {
#endif

extern thread_local e_magik_result_types g_last_error;

#ifdef __cplusplus
}
#endif
