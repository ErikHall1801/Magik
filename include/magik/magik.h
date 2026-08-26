#ifndef MAGIK_H
#define MAGIK_H

#include <stdint.h>

#if defined(_WIN32)
    #if defined(MAGIK_BUILD_DLL)
        #define MAGIK_API __declspec(dllexport)
    #else
        #define MAGIK_API __declspec(dllimport)
    #endif
#elif defined(__GNUC__) || defined(__clang__)
    #define MAGIK_API __attribute__((visibility("default")))
#else
    #define MAGIK_API
#endif

#ifdef __cplusplus
extern "C" {
#endif



/**
* [SECTION] Version
*/
#define MAGIK_VERSION_NAME "Rhapsody"
#define MAGIK_VERSION_MAJOR 0
#define MAGIK_VERSION_MINOR 1
#define MAGIK_VERSION_REVISION 0



/**
* [SECTION] Error handling & result types
*/

/**
* @brief Magik error results. "enum class" and ": type" are C++ features.
*/
typedef enum e_magik_result_types
{
    MAGIK_SUCCESS = 0, // The operation was successful

    // API specific 100 - 199
    MAGIK_ERROR_NOT_RUNNING = 1, // A runtime function was called before the Magik thread was running. This can happen by out-of-order initalization 
    MAGIK_ERROR_INVALID_POINTER = 2,

    // Host 200 - 299
    MAGIK_ERROR_HOST_OUT_OF_MEMORY = 100,

    // Device 300 - 399
    MAGIK_ERROR_DEVICE_OUT_OF_MEMORY = 200,

    // Command queue system 400 - 499
    MAGIK_ERROR_INVALID_ID = 400, // Happens when the id provided to a function related to the command queue system is not valid, i.e 0 or uninitialized
    MAGIK_ERROR_PROVIDED_ID_NOT_FOUND = 401, // Happens when the id provided to a function used command queue system has not been found, for example if the asset was not added. 
    MAGIK_ERROR_REQUESTED_ASSET_IS_NOT_A_CHILD_OF_THE_SCENE = 402,

    // General rendering 500 - 599
    MAGIK_ERROR_NEGATIVE_WAVELENGTH = 500,
    MAGIK_ERROR_NEGATIVE_MONTE_CARLO_WEIGHT = 501,
    MAGIK_ERROR_REFLECTANCE_GREATER_THAN_ONE = 502,
    MAGIK_ERROR_REFLECTANCE_LESS_THAN_ZERO = 503,
    MAGIK_ERROR_POSITION_INSIDE_CONDUCTOR = 504,
    MAGIK_ERROR_NEGATIVE_VOLUME_COEFFICIENT = 505,

    // General relativity 700 - 799
    MAGIK_ERROR_VELOCITY_GREATER_THAN_SPEED_OF_LIGHT = 700,
    MAGIK_ERROR_POSITION_INSIDE_EVENT_HORIZON = 701,
    MAGIK_ERROR_NEGATIVE_DOPPLER_FACTOR = 702,
    MAGIK_ERROR_NEGATIVE_TIME_COORDINATE = 703,
    MAGIK_ERROR_POSITIVE_NORM_TIMELIKE_FOUR_VECTOR = 704,
    MAGIK_ERROR_INCORRECT_PHOTON_NORM_FOUR_VECTOR = 705,
    MAGIK_ERROR_INCORRECT_PARTICLE_NORM_FOUR_VECTOR = 706,

    // Lens simulation 800 - 899
    MAGIK_ERROR_LENSLETS_OUT_OF_ORDER = 801,
    MAGIK_ERROR_NO_FRONT_LENSLET_ID = 802,
    MAGIK_ERROR_LENSLET_CYLINDER_LARGER_THAN_SURFACE_RADIUS = 803,
    MAGIK_ERROR_NO_REFERENCE_TO_SPECIFIED_SPECTRAL_DATA = 804,

    // General 10000 - 10099
    MAGIK_ERROR_UNKNOWN = 10000,

    // Prohibited
    MAGIK_PROHIBITED_FORCE_SIZE = 0x7FFFFFFF // Internal use only. Forces the C compiler to use uint32_t
} e_magik_result_types;

/**
* @brief Catches Magik errors and provides debug information
* 
* @param [in] val Magik API function which returns the e_magik_result_types type
* @warning If the return type is not MAGIK_SUCCESS this macro either prints out general debug information or calls 
           a user-defined callback. The callback uses the magik_error_callback signature and has to be set using 
           magik_set_error_callback. It is highly adviced to define a callback which handles errors, as many of 
           them, such as MAGIK_ERROR_HOST_OUT_OF_MEMORY will cause a crash sooner rather than later if left to their 
           own devices. The default behaivor does not cause the application to crash. 
*/
#define check_magik_error(val) check_magik( (val), #val, __FILE__, __LINE__);

/**
* @brief Typedef for error callbacks
* 
* @param [in] result The result of a Magik function which returns e_magik_result_types. It is recommended to use 
                     the macro check_magik_error to automatically fill the next arguments
* @param [in] func The function in which the error was first caught, not the one in which it necessarily happened. 
* @param [in] file The file in which the function that caugth the error was located in.
* @param [in] line The line where the error was caught.
* @param [in] user_data A void pointer to user data used by the callback. 
*/
typedef void (*magik_error_callback)(e_magik_result_types result, const char* func, const char* file, int line, void* user_data);

/**
* @brief Sets a callback function and user data to be used in the event of an error
* 
* @param [in] callback A function of a defined signature 
* @param [in] user_data A void pointer to user data. 
* 
* @warning Only one callback and user data pointer can be set at a time !
*/
MAGIK_API void magik_set_error_callback(magik_error_callback callback, void* user_data);

/**
* @brief Gets the last magik error. This is useful in circumstances where a Magik function call is wrapped inside
         another function which may not be able to return the error. You can nest this function inside the 
         check_magik_error macro to get the usual behavior. 
*
* @return Last error
* 
* @warning While the function is thread safe it can only return the last error and is not intrinsically aware to 
           distinguish where an error happen. The error log will use the location check_magik_error ! 
*/
MAGIK_API e_magik_result_types magik_get_last_error(void);

/**
* 
*/
MAGIK_API void check_magik(e_magik_result_types result, char const* func, const char* const file, int const line); 



/**
* [SECTION] Tests
*/

struct magik_rgba_test_frame_buffer_t
{
    uint32_t x_res = 0;
    uint32_t y_res = 0;
    float* data = nullptr;
};

/**
* @brief Example of an opaque pointer & struct. Note, in this example the opaque type is a pointer, but this works with raw pointers / structs too. 
*/
typedef struct magik_rgba_test_frame_buffer_t* magik_rgba_test_frame_buffer;

/**
* @brief Allocate width x height x 4 (RGBA) host frame buffer
*
* @param [out] buffer Pointer to the handle which recieves the data pointer and tracks the state.
* @param [in] width The width of the frame buffer in pixels.
* @param [in] height The height of the frame buffer in pixels.
* 
* @return MAGIK_SUCCESS on successful allocation.
* @return MAGIK_OUT_OF_MEMORY when the system ran out of memory
*
* @warning The caller is responsible for freeing the allocated buffer by passing it into magik_host_destroy_rgba_test
*/
MAGIK_API e_magik_result_types magik_allocate_host_rgba_test(magik_rgba_test_frame_buffer* buffer, uint32_t width, uint32_t height);

/**
* @brief Destroys previously allocated RGBA buffer
* 
* @param [out] result MAGIK_SUCCESS if the destruction was successful. Freeing null data is safe. 
* @param [in] buffer magik_rgba_test_frame_buffer struct
*/
MAGIK_API e_magik_result_types magik_destroy_host_rgba_test(magik_rgba_test_frame_buffer buffer);



/**
* [SECTION] Version checking
*/

/**
* @brief Fetches API version
* 
* @param [out] major unsigned 32 bit int for the major version number
* @param [out] minor unsigned 32 bit int for the minor version number
* @param [out] revision unsigned 32 bit int ofr the revision number
* @param [out] as_char Formated char of the version number and codename, MAJOR.MINOR.REVISION - Codename, for example "Magik ! 0.1.0 - Rhapsody" 
* 
* @return MAGIK_SUCCESS
*/
MAGIK_API e_magik_result_types magik_get_version(uint32_t* major, uint32_t* minor, uint32_t* revision, const char** as_char);



#ifdef __cplusplus
}
#endif

#endif
