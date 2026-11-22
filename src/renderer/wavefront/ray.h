#pragma once

#include "internal_math.h"
#include "device_arena.h"
#include <cstdint>
#include "cuda_runtime.h"
#include <curand_kernel.h>
#include "curand.h"

namespace magik
{
    struct ray_queue_base_t 
    {
        uint32_t* d_count = nullptr; 
        uint32_t* d_count_history = nullptr; 
        uint32_t* d_id = nullptr; 
    };

    struct advance_A_queue_t : ray_queue_base_t {};

    struct advance_B_queue_t : ray_queue_base_t {};

    struct intersect_queue_t : ray_queue_base_t {};

    struct bxdf_queue_t : ray_queue_base_t {};

    struct redistribute_queue_t : ray_queue_base_t {};

    struct splat_queue_t : ray_queue_base_t {};

    template<typename... T_queue> struct queue_pool_t : T_queue...
    {
        uint32_t* d_count_base = nullptr;
        uint32_t* d_count_history_base = nullptr;
        uint32_t* d_id_base = nullptr;

        size_t size_of_d_count_block = 0;
        size_t size_of_d_count_history_block = 0;
        size_t size_of_d_id_block = 0;

        static constexpr size_t align_up(size_t x)
        {
            return (x + 255) & ~(255);
        }

        size_t total_bytes(const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t n_geodesic_step_limit)
        {
            size_t bytes_id = align_up((size_t)x_resolution * y_resolution * sizeof(uint32_t));
            size_t bytes_count = align_up(sizeof(uint32_t));
            size_t bytes_count_history = align_up(sizeof(uint32_t) * n_geodesic_step_limit);
            return sizeof...(T_queue) * (bytes_id + bytes_count + bytes_count_history);
        }

        template<typename Q> uint32_t* get_count_ptr()
        {
            return static_cast<const Q&>(*this).d_count;
        }

        template<typename Q> uint32_t* get_id_ptr()
        {
            return static_cast<const Q&>(*this).d_id;
        }

        template<typename Q> uint32_t* get_count_history_ptr()
        {
            return static_cast<const Q&>(*this).d_count_history;
        }

        template<typename Q> void store_count_in_history(cudaStream_t user_stream, uint32_t n_iteration, uint32_t n_geodesic_step_limit)
        {
            if(n_iteration > n_geodesic_step_limit) return; // Big error

            uint32_t* dst = this->get_count_history_ptr<Q>() + n_iteration;
            uint32_t* src = this->get_count_ptr<Q>();
            check_cuda_errors(cudaMemcpyAsync(dst, src, sizeof(uint32_t), cudaMemcpyDeviceToDevice, user_stream));
        }

        template<typename Q> void zero_count_async(cudaStream_t user_stream)
        {
            check_cuda_errors(cudaMemsetAsync(get_count_ptr<Q>(), 0x0, sizeof(uint32_t), user_stream));
        }

        template<typename Q> void set_count_async(uint32_t value, cudaStream_t user_stream)
        {
            check_cuda_errors(cudaMemcpyAsync(get_count_ptr<Q>(), &value, sizeof(uint32_t), cudaMemcpyHostToDevice, user_stream));
        } 

        void reset_all_counts(cudaStream_t user_stream)
        {
            check_cuda_errors(cudaMemsetAsync(d_count_base, 0, size_of_d_count_block, user_stream));
        }

        void reset_all_count_histories(cudaStream_t user_stream, uint32_t n_geodesic_step_limit)
        {
            check_cuda_errors(cudaMemsetAsync(d_count_history_base, 0, size_of_d_count_history_block, user_stream));
        }

        void swap_advance_queues()
        {
            auto& a = static_cast<advance_A_queue_t&>(*this);
            auto& b = static_cast<advance_B_queue_t&>(*this);
            std::swap(a.d_count, b.d_count);
            std::swap(a.d_id, b.d_id);
        }

        void assign(device_mem_arena* arena, const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t n_geodesic_step_limit)
        {
            constexpr size_t n_queue = sizeof...(T_queue);
            const size_t id_stride = ((size_t)x_resolution * y_resolution + 63) & ~size_t(63);

            size_t total_size_of_count = n_queue * sizeof(uint32_t);
            size_t total_size_of_count_history = n_queue * sizeof(uint32_t) * (size_t)n_geodesic_step_limit;
            size_t total_size_of_id = n_queue * id_stride * sizeof(uint32_t);

            size_of_d_count_block = total_size_of_count;
            size_of_d_count_history_block = total_size_of_count_history;
            size_of_d_id_block = total_size_of_id;

            uint32_t* d_count_base_ptr = static_cast<uint32_t*>(device_arena_push(arena, total_size_of_count));
            uint32_t* d_count_history_base_ptr = static_cast<uint32_t*>(device_arena_push(arena, total_size_of_count_history));
            uint32_t* d_id_base_ptr = static_cast<uint32_t*>(device_arena_push(arena, total_size_of_id));

            d_count_base = d_count_base_ptr;
            d_count_history_base = d_count_history_base_ptr;
            d_id_base = d_id_base_ptr;

            size_t i_push_count = 0;
            auto push_count = [&](ray_queue_base_t& q)
            {
                q.d_count = d_count_base_ptr + i_push_count;
                i_push_count++;
            };
            (push_count(static_cast<T_queue&>(*this)), ...);

            size_t i_push_count_history = 0;
            auto push_count_history = [&](ray_queue_base_t& q)
            {
                q.d_count_history = d_count_history_base_ptr + i_push_count_history * (size_t)n_geodesic_step_limit;
                i_push_count_history++;
            };
            (push_count_history(static_cast<T_queue&>(*this)), ...);

            size_t i_push_id = 0;
            auto push_id = [&](ray_queue_base_t& q)
            {
                q.d_id = d_id_base_ptr + i_push_id * id_stride;
                i_push_id++;
            };
            (push_id(static_cast<T_queue&>(*this)), ...);
        }
    };

    // Spectral 
    struct sensor_wavelength_nm_t { using type = float; uint32_t n_dimension = 1; };

    struct throughput_t { using type = float; uint32_t n_dimension = 1; };

    struct spectral_radiance_t { using type = float; uint32_t n_dimension = 1; };

    struct intrinsic_spectral_irradiance_t { using type = float; uint32_t n_dimension = 1; };

    // Randomness
    struct random_device_t { using type = curandState_t; uint32_t n_dimension = 1; };

    // Geodesic
    struct initial_observer_spatial_direction_t { using type = vec4f; uint32_t n_dimension = 1; };

    struct initial_observer_spatial_position_t { using type = vec4f; uint32_t n_dimension = 1; };

    struct initial_four_vector_contraction_t { using type = float; uint32_t n_dimension = 1; };

    struct affine_parameter_t { using type = float; uint32_t n_dimension = 1; };

    struct delta_affine_parameter_t { using type = float; uint32_t n_dimension = 1; };

    struct current_four_position_t { using type = vec4f; uint32_t n_dimension = 1; };

    struct current_four_momentum_t { using type = vec4f; uint32_t n_dimension = 1; };

    struct next_four_position_t { using type = vec4f; uint32_t n_dimension = 1; };

    struct next_four_momentum_t { using type = vec4f; uint32_t n_dimension = 1; };

    struct momentum_derivative_start_t { using type = vec4f; uint32_t n_dimension = 1; };

    struct momentum_derivative_end_t { using type = vec4f; uint32_t n_dimension = 1; };

    // Hit
    struct hit_matter_slot_t { using type = uint32_t; uint32_t n_dimension = 1; };

    struct hit_normal_t { using type = vec4f; uint32_t n_dimension = 1; }; 

    // Statistics
    struct n_geodesic_step_t { using type = uint32_t; uint32_t n_dimension = 1; };

    struct n_reflected_t { using type = uint32_t; uint32_t n_dimension = 1; };

    template<typename R> struct pool_member_t : R // This is important, this inherets the dimension
    {
        R::type* ptr = nullptr;
    };

    template<typename... T> struct ray_pool_t : pool_member_t<T>...
    {
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
