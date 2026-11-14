#pragma once
#include "magik.h"

#include "cuda_host_device_utilities.h"


/**
* [SECTION] Error handling & result types
*/

namespace magik::error
{
    /*
    * 
    * check_magik_error and check_error_internal are DCC exclusive. The API never calls these
    * internally. 
    * 
    */
    void set_error_callback_internal(magik_error_callback callback, void* user_data);

    void check_error_internal(e_magik_result_types result, char const* func, const char* const file, int const line);
}

#ifdef __cplusplus
extern "C" {
#endif

#ifdef __cplusplus
}
#endif
