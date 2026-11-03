#pragma once

#ifdef __CUDACC__
    #define MAGIK_DEVICE_HOST __device__ __host__ __inline__
#else
    #define MAGIK_DEVICE_HOST inline 
#endif

namespace magik
{

}
