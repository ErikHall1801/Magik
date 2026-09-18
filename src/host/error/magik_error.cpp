#include "magik_error.h"
#include <iostream>

#ifdef __cplusplus
extern "C" {
#endif

static magik_error_callback g_error_callback = nullptr;

static void* g_error_user_data = nullptr;

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
