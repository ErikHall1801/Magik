/*
* 
*/

#pragma once

#include <iostream>

namespace magik::utilities
{
    __inline__ __device__ bool is_valid_thread(const uint32_t x_resolution, const uint32_t y_resolution)
    {
        uint32_t i_x = threadIdx.x + blockIdx.x * blockDim.x;
        uint32_t i_y = threadIdx.y + blockIdx.y * blockDim.y;
        return (i_x < x_resolution) && (i_y < y_resolution);
    }

    __inline__ __device__ size_t get_n_dimensional_thread_id(const uint32_t x_resolution, const uint32_t n)
    {
        unsigned int i_x = threadIdx.x + blockIdx.x * blockDim.x;
        unsigned int i_y = threadIdx.y + blockIdx.y * blockDim.y;
        return i_y * x_resolution * n + i_x * n;
    }

    __inline__ __device__ size_t get_thread_id(const uint32_t x_resolution)
    {
        return get_n_dimensional_thread_id(x_resolution, 1);
    }

    __inline__ __device__ __host__ dim3 compute_n_blocks(const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t x_threads_per_block, const uint32_t y_threads_per_block)
    {
        return dim3(( x_resolution / x_threads_per_block) + 1, (y_resolution / y_threads_per_block) + 1, 1);
    }

    __inline__ __host__ void check_cuda(cudaError_t result, char const* const func, const char* const file, int const line)
    {
        if(result) 
        {
            std::cerr << "CUDA error = " << static_cast<unsigned int>(result) << " : '" << cudaGetErrorString(result) << "' at " << file << ":" << line << " '" << func << "' \n";
            cudaDeviceReset();
            exit(99);
        }
    }

    #define check_cuda_errors(val) magik::utilities::check_cuda( (val), #val, __FILE__, __LINE__ )
}
