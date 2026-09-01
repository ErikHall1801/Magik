#pragma once 
#include "magik.h"
#include "magik_render_manager.h" 
#include "magik_bridge.h"
#include <chrono>
#include <thread>
#include <iostream>

namespace magik::worker
{
    void run(magik_render_manager* manager);
}
