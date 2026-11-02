#pragma once

#include "internal_math.h"
#include "device_arena.h"
#include <cstdint>
#include "cuda_runtime.h"
#include <curand_kernel.h>
#include "curand.h"

namespace magik
{
    // When this works we should use the same template logic for the queues. 
    // So we can just kinda generalize the pool logic. 
    struct ray_queue_t
    {
        uint32_t* d_count = nullptr; 
        uint32_t* d_id = nullptr;
    };

    struct sensor_wavelength_nm_t { using type = float; uint32_t n_dimension = 1; };

    struct monte_carlo_weight_t { using type = float; uint32_t n_dimension = 1; };

    struct spectral_radiance_t { using type = float; uint32_t n_dimension = 1; };

    struct intrinsic_spectral_irradiance_t { using type = float; uint32_t n_dimension = 1; }; // This then needs to be set by the settings

    struct random_device_t { using type = curandState_t; uint32_t n_dimension = 1; };

    struct position_t { using type = vec4f; uint32_t n_dimension = 1; };

    struct direction_t { using type = vec4f; uint32_t n_dimension = 1; };

    struct step_distance_t { using type = float; uint32_t n_dimension = 1; };

    struct n_step_t { using type = uint32_t; uint32_t n_dimension = 1; };

    struct hit_id_t { using type = uint32_t; uint32_t n_dimension = 1; };

    struct hit_normal_t { using type = vec4f; uint32_t n_dimension = 1; }; 

    template<typename T> struct pool_member_t : T // This is important, this inherets the dimension
    {
        T::type* ptr = nullptr;
    };

    template<typename... T> struct ray_pool_t : pool_member_t<T>...
    {
        device_mem_arena arena;

        static constexpr size_t align_up(size_t x)
        {
            return (x + 255) & ~(255);
        }

        template<typename F> size_t bytes(const uint32_t x_resolution, const uint32_t y_resolution) const 
        {
            size_t n_pixels = (size_t)x_resolution * (size_t)y_resolution;
            return n_pixels * this->F::n_dimension * sizeof(typename F::type);
        }

        void allocate_async(cudaStream_t user_stream, const uint32_t x_resolution, const uint32_t y_resolution, bool set_zero)
        {
            size_t total_size = 256;
            ((total_size += align_up(bytes<T>(x_resolution, y_resolution))), ...);

            arena = device_arena_create_async(user_stream, total_size);

            // Assignment stage
            ((static_cast<pool_member_t<T>&>(*this).ptr = static_cast<typename T::type*>(device_arena_push(&arena, bytes<T>(x_resolution, y_resolution)))), ...);
        
            if(set_zero)
            {
                check_cuda_errors(cudaMemsetAsync(arena.d_base, 0x0, total_size, user_stream));
            }
        }

        void release_async(cudaStream_t user_stream)
        {
            device_arena_destroy_async(user_stream, &arena);
        }

        template<typename T> typename T::type* get() const
        {
            return static_cast<const pool_member_t<T>&>(*this).ptr;
        }

        template<typename T> void set_n_dimension(const uint32_t n_dimension)
        {
            static_cast<pool_member_t<T>&>(*this).n_dimension = n_dimension;
        }

        template<typename T> void memset_async(cudaStream_t user_stream, const uint32_t x_resolution, const uint32_t y_resolution, int value)
        {
            check_cuda_errors(cudaMemsetAsync(get<T>(), value, bytes<T>(x_resolution, y_resolution), user_stream));
        }
    };
}
