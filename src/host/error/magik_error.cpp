#include "magik_error.h"
#include <iostream>

#ifdef __cplusplus
extern "C" {
#endif

static magik_error_callback g_error_callback = nullptr;

static void* g_error_user_data = nullptr;

thread_local e_magik_result_types g_last_error = MAGIK_SUCCESS;

#ifdef __cplusplus
}
#endif

namespace magik::error
{
    void set_error_callback_internal(magik_error_callback callback, void* user_data)
    {
        g_error_callback = callback;
        g_error_user_data = user_data;
    }

    e_magik_result_types get_last_error_internal(void)
    {
        return g_last_error;
    }

    void check_error_internal(e_magik_result_types result, char const* func, const char* const file, int const line)
    {
        if(result != MAGIK_SUCCESS)
        {
            if(g_error_callback)
            {
                g_error_callback(result, func, file, line, g_error_user_data);
            }
            else
            {
                printf("Magik error = %u at %s:%d '%s'\n", static_cast<unsigned int>(result), file, line, func);
            }
        }
    }
}
