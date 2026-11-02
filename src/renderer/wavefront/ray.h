#pragma once

#include "internal_math.h"
#include "device_arena.h"
#include <cstdint>
#include "cuda_runtime.h"
#include <curand_kernel.h>
#include "curand.h"

namespace magik
{
    struct ray_queue_base_t { uint32_t* d_count = nullptr; uint32_t* d_id = nullptr; };

    struct advance_A_queue_t : ray_queue_base_t {};

    struct advance_B_queue_t : ray_queue_base_t {};

    struct intersect_queue_t : ray_queue_base_t {};

    struct bxdf_queue_t : ray_queue_base_t {};

    struct redistribute_queue_t : ray_queue_base_t {};

    struct splat_queue_t : ray_queue_base_t {};

    template<typename... T_queue> struct queue_pool_t : T_queue...
    {
        static constexpr size_t align_up(size_t x)
        {
            return (x + 255) & ~(255);
        }

        size_t total_bytes(const uint32_t x_resolution, const uint32_t y_resolution)
        {
            size_t n = (size_t)x_resolution * y_resolution;
            return sizeof...(T_queue) * (align_up(sizeof(uint32_t)) + align_up(n * sizeof(uint32_t)));
        }

        template<typename Q> uint32_t* get_count_ptr()
        {
            return static_cast<const Q&>(*this).d_count;
        }

        template<typename Q> uint32_t* get_id_ptr()
        {
            return static_cast<const Q&>(*this).d_id;
        }

        template<typename Q> void zero_count_async(cudaStream_t user_stream) // zero_count_async
        {
            check_cuda_errors(cudaMemsetAsync(get_count_ptr<Q>(), 0x0, sizeof(uint32_t), user_stream));
        }

        template<typename Q> void set_count_async(uint32_t value, cudaStream_t user_stream)
        {
            check_cuda_errors(cudaMemcpyAsync(get_count_ptr<Q>(), &value, sizeof(uint32_t), cudaMemcpyHostToDevice, user_stream));
        } 

        void reset_all_counts(cudaStream_t user_stream)
        {
            (check_cuda_errors(cudaMemsetAsync(get_count_ptr<T_queue>(), 0x0, sizeof(uint32_t), user_stream)), ...);
        }

        void swap_advance_queues()
        {
            auto& a = static_cast<advance_A_queue_t&>(*this);
            auto& b = static_cast<advance_B_queue_t&>(*this);
            std::swap(a.d_count, b.d_count);
            std::swap(a.d_id,    b.d_id);
        }

        void assign(device_mem_arena* arena, const uint32_t x_resolution, const uint32_t y_resolution)
        {
            // It might, in the future, make sense to put all counts next to each other. 
            size_t n_pixel = (size_t)x_resolution * y_resolution;
            auto push = [&](ray_queue_base_t& q)
            {
                q.d_count = static_cast<uint32_t*>(device_arena_push(arena, sizeof(uint32_t)));
                q.d_id    = static_cast<uint32_t*>(device_arena_push(arena, n_pixel * sizeof(uint32_t)));
            };
            (push(static_cast<T_queue&>(*this)), ...);
        }
    };

    struct ray_queue_t
    {
        uint32_t* d_count = nullptr; 
        uint32_t* d_id = nullptr;
    };

    struct sensor_wavelength_nm_t { using type = float; uint32_t n_dimension = 1; };

    struct monte_carlo_weight_t { using type = float; uint32_t n_dimension = 1; };

    struct spectral_radiance_t { using type = float; uint32_t n_dimension = 1; };

    struct intrinsic_spectral_irradiance_t { using type = float; uint32_t n_dimension = 1; };

    struct random_device_t { using type = curandState_t; uint32_t n_dimension = 1; };

    struct position_t { using type = vec4f; uint32_t n_dimension = 1; };

    struct direction_t { using type = vec4f; uint32_t n_dimension = 1; };

    struct step_distance_t { using type = float; uint32_t n_dimension = 1; };

    struct n_step_t { using type = uint32_t; uint32_t n_dimension = 1; };

    struct hit_id_t { using type = uint32_t; uint32_t n_dimension = 1; };

    struct hit_normal_t { using type = vec4f; uint32_t n_dimension = 1; }; 

    template<typename R> struct pool_member_t : R // This is important, this inherets the dimension
    {
        R::type* ptr = nullptr;
    };

    template<typename... T> struct ray_pool_t : pool_member_t<T>...
    {
        device_mem_arena arena;

        static constexpr size_t align_up(size_t x)
        {
            return (x + 255) & ~(255);
        }

        template<typename R> size_t raw_bytes(size_t n_pixel) const
        {
            return n_pixel * static_cast<const pool_member_t<R>&>(*this).n_dimension * sizeof(typename R::type);
        }

        size_t total_bytes(const uint32_t x_resolution, const uint32_t y_resolution) const
        {
            size_t n_pixel = (size_t)x_resolution * y_resolution;
            return (align_up(raw_bytes<T>(n_pixel)) + ...);
        }

        void assign(device_mem_arena* arena, const uint32_t x_resolution, const uint32_t y_resolution)
        {
            size_t n_pixel = (size_t)x_resolution * y_resolution;
            ((static_cast<pool_member_t<T>&>(*this).ptr = static_cast<typename T::type*>(device_arena_push(arena, raw_bytes<T>(n_pixel)))), ...);
        }

        template<typename R> typename R::type* get() const
        {
            return static_cast<const pool_member_t<R>&>(*this).ptr;
        }

        template<typename R> void set_n_dimension(const uint32_t n_dimension)
        {
            static_cast<pool_member_t<R>&>(*this).n_dimension = n_dimension;
        }

        template<typename R> void memset_async(cudaStream_t user_stream, const uint32_t x_resolution, const uint32_t y_resolution, int value)
        {
            size_t memeber_size = (size_t)x_resolution * (size_t)y_resolution * sizeof(typename R::type) * (size_t)R::n_dimension;
            check_cuda_errors(cudaMemsetAsync(get<R>(), value, memeber_size, user_stream));
        }
    };
}
