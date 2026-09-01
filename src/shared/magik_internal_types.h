/*
* This file solves a core question. magik.h obscures definitions by using type aliases. 
* But where is the actual definition of the aliased type ? It has to be visible to the 
* host and bridge. 
* The answer is, right here. This file contains host type implementations visible to the
* device bridge. Do note, the actual CUDA translation units are blind to these defintions. 
* We will not pass full host structs into kernels but rather unpack them.
* We cannot use namespaces here because the opaque namespace, global, has to match the 
* definition. 
* 
* This file defines the EXPOSED types ! 
*/

#pragma once
#include <stdint.h>
#include <thread>
#include <atomic>
#include <memory>
#include "magik_render_manager.h"

struct magik_test_rgba_frame_buffer
{
    uint32_t x_resolution = 0;
    uint32_t y_resolution = 0;
    float* h_data = nullptr;
    float* d_data = nullptr;
};
