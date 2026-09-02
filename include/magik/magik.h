/*
* This is the APIs public header. It uses opaque structs to hide the 
* actual implementation logic. 
* The core rule of this file is to keep everything opaque and C-style. 
*/

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
#define MAGIK_VERSION_NAME "Rhapsody"   // Codename
#define MAGIK_VERSION_MAJOR 0           // New features (In our case before the API switch)
#define MAGIK_VERSION_MINOR 3           // Small changes / additions
#define MAGIK_VERSION_REVISION 0        // Bug fix release



/**
* [SECTION] Error handling & result types
*/
typedef enum e_magik_result_types
{
    MAGIK_SUCCESS = 0, // The operation was successful

    // API specific 100 - 199
    MAGIK_ERROR_NOT_RUNNING = 1, // A runtime function was called before the Magik thread was running. This can happen by out-of-order initalization 
    MAGIK_ERROR_INVALID_POINTER = 2,
    MAGIK_UNKNOWN_ENUM_TYPE = 3, 

    // Host 200 - 299
    MAGIK_ERROR_HOST_OUT_OF_MEMORY = 100,
    MAGIK_ERROR_HOST_MEMORY_ALLOCATION_FAILED = 101,

    // Device 300 - 399
    MAGIK_ERROR_DEVICE_OUT_OF_MEMORY = 200,

    // Command queue system 400 - 499
    MAGIK_ERROR_INVALID_ID = 400, // Happens when the id provided to a function related to the command queue system is not valid, i.e 0 or uninitialized
    MAGIK_ERROR_PROVIDED_ID_NOT_FOUND = 401, // Happens when the id provided to a function used command queue system has not been found, for example if the asset was not added. 
    MAGIK_ERROR_REQUESTED_ASSET_IS_NOT_A_CHILD_OF_THE_SCENE = 402,
    MAGIK_ERROR_COMMAND_BUFFER_OVERFLOW = 403,
    MAGIK_ERROR_INVALID_COMMAND = 404,
    MAGIK_ERROR_PACKED_DATA_NOT_ALLIGNED = 405,
    MAGIK_ERROR_COMMAND_DROPPED = 406,

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

    // Arbitrary Output Variables 900 - 999
    MAGIK_ERROR_AOV_INCORRECT_EXTRACT_CALL = 900,
    MAGIK_ERROR_AOV_ALLOCATED_BEFORE_INITIALIZATION = 901,

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
#define check_magik_errors(val) check_magik( (val), #val, __FILE__, __LINE__)

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
* @brief This is the default error checking function which the macro "check_magik_errors" uses. 
* 
* @param [in] result The result of a function which returns e_magik_result_types. In case an API function does not 
                     return this type, you can instead use magik_get_last_error() as the input. All Magik functions 
                     record the last error.
* @param [in] func The name of the function which caused the error. 
* @param [in] file The file the function which caused the error was located in. You can use the "__FILE__" macro here. 
* @param [in] line The line in which the error occured. You can use the "__LINE__" macro here. 
* 
* @warning This function does not interfer with the programs operation. It only prints that an error has occured. 
           It is strongly recommended to set a error callback using magik_set_error_callback()
*/
MAGIK_API void check_magik(e_magik_result_types result, char const* func, const char* const file, int const line); 



/**
* [SECTION] Info
*/

/*
* @brief Prints system info to the console
*/
MAGIK_API void magik_get_system_Info();



/**
* [SECTION] Tests
*/

/**
* @brief Example of an opaque pointer & struct. More specifically, this defines an opaque alias to a 
         pointer of an internal struct. Where magik_rgba_test_frame_buffer is internal and 
         magik_rgba_test_frame_buffer_t is the alias. 
*/
typedef struct magik_test_rgba_frame_buffer* magik_test_rgba_frame_buffer_t;

/**
* @brief Two test-kernel patterns are available. The UV gradient should appear with the black corner, R = G = B = 0, 
         at the lower left side of your window. The mandelbrot is intended to test resource allocation performance. 
*/
enum e_magik_test_kernel_pattern_types
{
    uv_gradient = 0,
    mandelbrot = 1
};



/**
* [SECTION] Version checking
*/

/**
* @brief Fetches API version
* 
* @param [out] major major version number
* @param [out] minor minor version number
* @param [out] revision revision number
* @param [out] as_char Formated char of the version number and codename, MAJOR.MINOR.REVISION - Codename, for example "Magik ! 0.1.0 - Rhapsody" 
* 
* @return MAGIK_SUCCESS
*/
MAGIK_API e_magik_result_types magik_get_version(uint32_t* major, uint32_t* minor, uint32_t* revision, const char** as_char);



/**
* [SECTION] Frame time
*/

/**
* @brief Returns the frame time in microseconds. 
*/
MAGIK_API e_magik_result_types magik_fetch_frame_time(double* ft);



/**
* [SECTION] Render manager
*/

/**
* @brief 
*/
typedef struct magik_render_manager* magik_render_manager_t;

/**
* @brief 
* 
* @param 
* 
* @return 
* 
* @warning
*/
MAGIK_API magik_render_manager_t magik_create_render_manager(uint32_t cuda_device);

/**
* @brief TEMP !!! All this does is stop the render thread and call .join(). 
*/
MAGIK_API e_magik_result_types magik_destroy_render_manager(magik_render_manager_t mananger);



/**
* [SECTION] Arbitrary Output Variables
*/

/*
 The goal now is to make the AOV handshake work between the GUI and render thread. So that we can display
 a texture without invoking CUDA. 
*/

/**
* @brief All AOV types Magik supports. 
*/
typedef enum e_magik_aov_types
{
    MAGIK_BEAUTY = 0,
    MAGIK_REFLECTANCE = 1,
    MAGIK_ALBEDO = 2,
    MAGIK_SPECULAR_GLOBAL = 3,
    MAGIK_SPECULAR_DIRECT = 4,
    MAGIK_SPECULAR_INDIRECT = 5,
    MAGIK_DIFFUSE_GLOBAL = 6,
    MAGIK_DIFFUSE_DIRECT = 7,
    MAGIK_DIFFUSE_INDIRECT = 8,
    MAGIK_REFLECTION = 9,
    MAGIK_REFRACTION = 10,
    MAGIK_ILLUMINANT = 11,
    MAGIK_NORMAL = 12,
    MAGIK_POSITION = 13,
    MAGIK_VELOCITY = 14,
    MAGIK_ALPHA = 15,
    MAGIK_OBJECT_ID = 16,
    MAGIK_DEPTH = 17,
    MAGIK_DISTORTION_CHART = 18,

    MAGIK_AOV_PROHIBITED_FORCE_SIZE = 0x7FFFFFFF
} e_magik_aov_types;

typedef enum e_magik_aov_config_types
{
    MAGIK_AOV_CONFIG_HOST = 0,
    MAGIK_AOV_CONFIG_CUDA = 1,
    MAGIK_AOV_CONFIG_OPENGL_INTEROP = 2,
    MAGIK_AOV_CONFIG_VULKAN_INTEROP = 3     // To-be-implemented. DO NOT USE ! 
} e_magik_aov_transfer_types;

/**
* @brief Opaque struct which holds the AOV buffers on the DCC thread. To extract the data you must call the 
         matching extract function. 
*/
typedef struct magik_aov_framebuffer_object_external* magik_aov_framebuffer_object_external_t;

/**
* @brief Configurs the DCC side AOV buffer to anticipate a "config_type" backend. The configuration can be changed
         at runtime. 
* 
* @param [in] config_type 
* 
* @return magik_external_aov_buffer_t, MAGIK_SUCCESS, MAGIK_UNKNOWN_ENUM_TYPE
*/
MAGIK_API magik_aov_framebuffer_object_external_t magik_configure_aov_framebuffer(e_magik_aov_config_types config_type);

/**
* @brief This function fetches the most up-to-date AOV buffer from the API. Magik uses a tripple buffer lock-free
         setup. Memory transfers only happen if the AOV buffer internally tracked by Magik has changed since the 
         last time this function was called. 
* 
* @param [in] manager The render manager from which you want the AOV 
* @param [out] dcc_buffer The DCC buffer instance to which the AOVs will be copied too. 
* 
* @return MAGIK_SUCCESS, MAGIK_UNKNOWN_ENUM_TYPE, 
* 
* @warning This function returns false if the API side AOV has not updated since the last call. In this case a transfer
           would not change the result and is thus skipped. The DCC should only call the extract functions if this function
           returned true. Though the contents of the AOV object do not expire between calls. 
* @warning The user is not responsible for allocating the DCC buffer ! Magik automatically allocates and reallocates the buffers
           depending on the configuration and resolution ! The resolution is automatically updated using the active camera. 
*/
MAGIK_API bool magik_aov_fetch(magik_render_manager_t manager, magik_aov_framebuffer_object_external_t dcc_buffer); 

/**
* @brief Struct where the matching extract function will store pointers to the AOV memory to. 
* 
* @warning Do not allocate the pointers in this struct ! They will be overwriten by the extract function ! This struct servers as 
           an observer. 
*/
struct magik_aov_container_config_host_t
{
    uint32_t x_resolution = 0;
    uint32_t y_resolution = 0;
    size_t size_of_albedo = 0; 
    float* h_albedo = nullptr; // RGB, h_ means it is a host pointer. 
};

/**
* All of these will use non-opaque structs. The user does NOT have to allocate memory here. These functions 
  will alloc themselves. Indeed, it is recommended to not allocate because these  
  Make sure the descriptions here make it very clear what the functions return, write into the associated struct
  and how to cast this into the respective types. 
* @brief Extracts the pointers to the host configured AOV buffer. 
* 
* @param 
* 
* @return 
* 
* @warning 
*/
MAGIK_API e_magik_result_types magik_aov_config_host_extract(magik_aov_container_config_host_t* container, magik_aov_framebuffer_object_external_t dcc_buffer);

/**
* @brief Struct which containes base types for a CUDA DCC backend. The user is responsible for casting these base types into CUDA ones !
*/
struct magik_aov_container_config_cuda_t
{

};

/**
* 
*/
MAGIK_API e_magik_result_types magik_aov_config_cuda_extract(magik_aov_container_config_cuda_t* container, magik_aov_framebuffer_object_external_t dcc_buffer);

/**
* @brief Struct which containes base types for a OpenGL DCC backend. The user is responsible for casting these base types into OpenGL ones !
*/
struct magik_aov_container_config_opengl_interop_t
{
    uint32_t x_resolution;
    uint32_t y_resolution;

    uint32_t gl_buffer_id = 0;
    void* cuda_resources = nullptr; // true type is cudaGraphicsResource_t
};

/**
* 
*/
MAGIK_API e_magik_result_types magik_aov_config_opengl_interop_extract(magik_aov_container_config_opengl_interop_t* container, magik_aov_framebuffer_object_external_t dcc_buffer);

/**
* @brief Struct which containes base types for a Vulkan DCC backend. The user is responsible for casting these base types into Vulkan ones !
*/
struct magik_aov_container_config_vulkan_interop_t
{

};

/**
* @brief To be implemented ! DO NOT USE ! 
*/
MAGIK_API e_magik_result_types magik_aov_extract_vulkan_interop_extract(magik_aov_container_config_vulkan_interop_t* container, magik_aov_framebuffer_object_external_t dcc_buffer);

/**
* @brief This is mega tmp. Probably not thread save.
*/
MAGIK_API e_magik_result_types magik_aov_resize(magik_render_manager_t manager, uint32_t x_resolution, uint32_t y_resolution);

/**
* @brief Free´s the memory associated with an AOV buffer. The user does not have to call this function
         each time the configuration is changed. 
* 
* @param [in] dcc_buffer
* 
* @return 
* 
* @warning 
*/
MAGIK_API e_magik_result_types magik_aov_destroy(magik_aov_framebuffer_object_external_t dcc_buffer);



/**
* [SECTION] Command Queue System
*/

/**
* @brief The list of all commands the DCC can issue to Magik. Most command come with an associated struct which carries data. If it exists the
         struct will follow the naming convention "command_name_data_t". For example; "magik_command_printf_data_t". These structs are not opaque
         and the user is expected to input the data directly.  
* 
* @warning Magik is designed to be entirly controlled through the Command Queue System. For example, terminating the manager is done by issuing the
           command "MAGIK_COMMAND_DESTRY". 
*/
typedef enum e_magik_cqs_command_types
{
    // 1000-1999 Basic operations
    MAGIK_COMMAND_START = 1000,
    MAGIK_COMMAND_DESTROY = 1001,

    // 2000-2999 Built-in tests
    MAGIK_COMMAND_PRINTF = 2000,

    // 3000-3999 Callbacks
    MAGIK_COMMAND_SET_ERROR_CALLBACK = 3000,

    // 4000-4999 Settings

    // 5000-5999 Scene

    // 6000-6999 Camera

    // 7000-7999 Hittable Object

    // 8000-8999 bxdf materials 

    // Prohibited
    MAGIK_CQS_PROHIBITED_FORCE_SIZE = 0x7FFFFFFF 
} e_magik_cqs_command_types;

/**
* @brief 
* 
* @param 
* 
* @return 
* 
* @warning
*/
MAGIK_API e_magik_result_types magik_cqs_configure();

/**
* @brief 
* 
* @param 
* 
* @return 
* 
* @warning
*/
MAGIK_API e_magik_result_types magik_cqs_push_command();

/**
* @brief 
* 
* @param 
* 
* @return 
* 
* @warning
*/
MAGIK_API e_magik_result_types magik_cqs_dispatch_command_buffer();



#ifdef __cplusplus
}
#endif

#endif
