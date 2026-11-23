#pragma once

#ifdef __CUDACC__
    #define MAGIK_DEVICE_HOST __device__ __host__ __inline__
    #define MAGIK_HOST __host__ __inline__
    #define MAGIK_DEVICE __device__ __inline__
#else
    #define MAGIK_DEVICE_HOST inline 
    #define MAGIK_HOST inline
    #define MAGIK_DEVICE 
#endif

namespace magik
{
    template<auto... Vs> struct value_list {};

    template<auto V> struct value_tag { static constexpr auto value = V; };

    #ifdef __CUDACC__
        #pragma nv_exec_check_disable
    #endif
    template<class E, class F, auto... Vs> MAGIK_DEVICE_HOST constexpr bool dispatch_list(value_list<Vs...>, E value, F&& f)
    {
        return ((value == Vs ? (f(value_tag<Vs>{}), void(), true) : false) || ...);
    }
}
