#include "cuda_host_utilities.h"

#include <cuda_runtime.h>
#include <cstdint>
#include <cstdlib>
#include <iostream>

namespace magik
{
    void check_cuda(cudaError_t result, char const* const func, const char* const file, int const line)
    {
        if(result) 
        {
            std::cerr << "CUDA error = " << static_cast<unsigned int>(result) << " : '" << cudaGetErrorString(result) << "' at " << file << ":" << line << " '" << func << "' \n";
            cudaDeviceReset();
            exit(99);
        }
    }

    void set_cuda_device(uint32_t cuda_device)
    {
        check_cuda_errors(cudaSetDevice(cuda_device));
    }

    void printf_system_info()
    {
        int n_device = 0;
        check_cuda_errors(cudaGetDeviceCount(&n_device));

        printf("Number of CUDA devices %d \n", n_device);

        for(int i_device = 0; i_device < n_device; i_device++)
        {
            cudaDeviceProp device_prop;
            check_cuda_errors(cudaGetDeviceProperties(&device_prop, i_device));

            if(n_device == 0)
            {
                if(device_prop.major == 9999 && device_prop.minor == 9999)
                {
                    printf("No CUDA GPU has been detected. \n");
                    return;
                }
            }

            printf("\n");
            printf("CUDA device #%d\n", i_device);
            printf("Device name:                        %s\n", device_prop.name);
            printf("Major revision number:              %d\n", device_prop.major);
            printf("Minor revision number:              %d\n", device_prop.minor);
            printf("Total global memory:                %lu\n", (unsigned long)device_prop.totalGlobalMem);
            printf("Total shared memory per block:      %lu\n", (unsigned long)device_prop.sharedMemPerBlock);
            printf("Total constant memory size:         %lu\n", (unsigned long)device_prop.totalConstMem);
            printf("Warp size:                          %d\n", device_prop.warpSize);
            printf("Maximum block dimensions:           %d x %d x %d\n", device_prop.maxThreadsDim[0], device_prop.maxThreadsDim[1], device_prop.maxThreadsDim[2]);
            printf("Maximum grid dimensions:            %d x %d x %d\n", device_prop.maxGridSize[0], device_prop.maxGridSize[1], device_prop.maxGridSize[2]);
            printf("Number of multiprocessors:          %d\n", device_prop.multiProcessorCount);
            printf("\n");
        }
    }

    int32_t get_cuda_device_count()
    {
        int32_t n_device = 0;
        check_cuda_errors(cudaGetDeviceCount(&n_device));

        return n_device;
    }

    void create_cuda_stream(void** user_stream)
    {
        cudaStream_t d_stream;
        check_cuda_errors(cudaStreamCreateWithFlags(&d_stream, cudaStreamNonBlocking));
        *user_stream = static_cast<void*>(d_stream);
    }

    void destroy_cuda_stream(void** user_stream)
    {
        check_cuda_errors(cudaStreamDestroy(static_cast<cudaStream_t>(*user_stream)));
    }
}
