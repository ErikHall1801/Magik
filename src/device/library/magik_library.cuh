/*
* This is a shared CUDA library which includes all utility, math and type headers used by the API. 
* Its purpose is to be included in CUDA translation units. It only includes generic concepts 
* applicable to all kernels and, by extension, not them. 
*/

#pragma once 

// General
#include <iostream>

// CUDA 
#include <cuda_runtime.h>

// Error macro 

// Magik
    // Shared
    #include "magik_error.h"

    // Include
    #include "magik_utilities.cuh"
    #include "magik_math.cuh"
