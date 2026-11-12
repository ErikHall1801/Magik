#pragma once
#include "host_arena.h"

namespace magik
{
    bool host_trace_geodesic(magik_trace_geodesic_container_t* container, magik_trace_geodesic_inital_conditions_t initial_conditions, magik_trace_geodesic_metric_parameters_t metric_parameters, magik_trace_geodesic_integrator_parameters_t integrator_parameters);
}
