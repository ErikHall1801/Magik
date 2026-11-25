#include "wavefront.h"
#include "kernel_generate_thin_lens_ray.cuh"
#include "kernel_splat_to_renderbuffer.cuh"
#include "kernel_generate_initial_conditions.cuh"
#include "kernel_advance_geodesic.cuh"
#include "kernel_intersect.cuh"
#include "kernel_bxdf.cuh"
#include "kernel_enforce_ray_limits.cuh"
#include "kernel_initialize_random_device.cuh"
#include "kernel_redistribute_radiance.cuh"

namespace magik
{
    static void is_work_done_sync(bool* working, uint32_t* queue_ceiling, uint32_t* advance_d_count, cudaStream_t user_stream)
    {
        check_cuda_errors(cudaMemcpyAsync(queue_ceiling, advance_d_count, sizeof(uint32_t), cudaMemcpyDeviceToHost, user_stream));
        check_cuda_errors(cudaStreamSynchronize(user_stream));
        check_cuda_errors(cudaGetLastError());

        if(*queue_ceiling == 0)
        {
            *working = false;
        }
        else
        {
            *working = true;
        }
    }

    static void prepare_wavefront_buffer_async(wavefront_buffer_t& wavefront_buffer, cudaStream_t user_stream)
    {
        wavefront_buffer.queue_pool.reset_all_counts(user_stream);
        wavefront_buffer.queue_pool.reset_all_count_histories(user_stream, wavefront_buffer.n_geodesic_step_limit);

        wavefront_buffer.ray_pool.memset_async<spectral_radiance_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer.x_resolution, wavefront_buffer.y_resolution, 0x0);
        wavefront_buffer.ray_pool.memset_async<initial_four_vector_contraction_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer.x_resolution, wavefront_buffer.y_resolution, 0x0);
        wavefront_buffer.ray_pool.memset_async<affine_parameter_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer.x_resolution, wavefront_buffer.y_resolution, 0x0);
        wavefront_buffer.ray_pool.memset_async<delta_affine_parameter_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer.x_resolution, wavefront_buffer.y_resolution, 0x0);
        wavefront_buffer.ray_pool.memset_async<n_geodesic_step_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer.x_resolution, wavefront_buffer.y_resolution, 0x0);
        wavefront_buffer.ray_pool.memset_async<n_reflected_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer.x_resolution, wavefront_buffer.y_resolution, 0x0);

        wavefront_buffer.queue_pool.set_count_async<advance_A_queue_t>(wavefront_buffer.x_resolution*wavefront_buffer.y_resolution, user_stream);
        wavefront_buffer.queue_ceiling = wavefront_buffer.x_resolution*wavefront_buffer.y_resolution;

        wavefront_buffer.iteration = 0;
    }

    static void allocate_wavefront_buffer_async(wavefront_buffer_t& wavefront_buffer, cudaStream_t user_stream)
    {
        auto constexpr align_up = [](size_t x)
        {
            return (x+255) & ~(255);
        };

        wavefront_buffer.ray_pool.set_n_dimension<intrinsic_spectral_irradiance_t>(wavefront_buffer.n_isi_bin);

        size_t total_size_bytes = 0;
        total_size_bytes += align_up(wavefront_buffer.queue_pool.total_bytes(wavefront_buffer.x_resolution, wavefront_buffer.y_resolution, wavefront_buffer.n_geodesic_step_limit) + wavefront_buffer.ray_pool.total_bytes(wavefront_buffer.x_resolution, wavefront_buffer.y_resolution));

        wavefront_buffer.arena = device_arena_create_async(user_stream, total_size_bytes);
        wavefront_buffer.queue_pool.assign(&wavefront_buffer.arena, wavefront_buffer.x_resolution, wavefront_buffer.y_resolution, wavefront_buffer.n_geodesic_step_limit);
        wavefront_buffer.ray_pool.assign(&wavefront_buffer.arena, wavefront_buffer.x_resolution, wavefront_buffer.y_resolution);

        check_cuda_errors(cudaMemsetAsync(wavefront_buffer.arena.d_base, 0x0, total_size_bytes, user_stream));
    }

    static void reset_wavefront_progress_async(wavefront_buffer_t& wavefront_buffer, cudaStream_t user_stream, uint32_t& x_sample)
    {
        wavefront_buffer.ray_pool.memset_async<sensor_wavelength_nm_t>(user_stream, wavefront_buffer.x_resolution, wavefront_buffer.y_resolution, 0x0);
        wavefront_buffer.ray_pool.memset_async<throughput_t>(user_stream, wavefront_buffer.x_resolution, wavefront_buffer.y_resolution, 0x0);
        wavefront_buffer.ray_pool.memset_async<spectral_radiance_t>(user_stream, wavefront_buffer.x_resolution, wavefront_buffer.y_resolution, 0x0);
        wavefront_buffer.ray_pool.memset_async<intrinsic_spectral_irradiance_t>(user_stream, wavefront_buffer.x_resolution, wavefront_buffer.y_resolution, 0x0);
        x_sample = 0;
    }

    static void realloc_wavefront_buffer(wavefront_buffer_t& wavefront_buffer, cudaStream_t user_stream, uint32_t& x_sample, uint32_t x_resolution_target, uint32_t y_resolution_target, uint32_t n_isi_bin, uint32_t n_geodesic_step_limit)
    {
        wavefront_buffer.x_resolution = x_resolution_target;
        wavefront_buffer.y_resolution = y_resolution_target;
        wavefront_buffer.n_isi_bin = n_isi_bin;
        wavefront_buffer.n_geodesic_step_limit = n_geodesic_step_limit;

        release_wavefront_buffer(&wavefront_buffer.arena, user_stream);
        allocate_wavefront_buffer_async(wavefront_buffer, user_stream);
        launch_kernel_initialize_random_device_async(wavefront_buffer, user_stream);

        check_cuda_errors(cudaStreamSynchronize(user_stream));
        check_cuda_errors(cudaGetLastError());

        x_sample = 0;
    }

    void update_wavefront_buffer(update_wavefront_buffer_t args)
    {
        switch(args.update_policy)
        {
            case MAGIK_WAVEFRONT_UPDATE_POLICY_NONE:
            {
                break;
            }

            case MAGIK_WAVEFRONT_UPDATE_POLICY_RESET:
            {
                reset_wavefront_progress_async(args.wavefront_buffer, args.user_stream, args.x_sample);
                break;
            }

            case MAGIK_WAVEFRONT_UPDATE_POLICY_REALLOC:
            {
                realloc_wavefront_buffer(args.wavefront_buffer, args.user_stream, args.x_sample, args.x_resolution_target, args.y_resolution_target, args.n_isi_bin, args.n_geodesic_step_limit);
                break;
            }
        }
    }

    void wavefront_sample(wavefront_sample_args_t args)
    {
        // once this works we will further break the stage up into what each kernel ACTUALLY needs

        bool working = true;

        prepare_wavefront_buffer_async(args.wavefront_buffer, args.user_stream);

        launch_kernel_generate_thin_lens_ray_async(args.wavefront_buffer, args.user_stream, args.stage, args.color_pipeline);

        launch_kernel_generate_initial_conditions_async(args.wavefront_buffer, args.user_stream, args.stage);

        while(working)
        {
            launch_kernel_advance_geodesic_async(args.wavefront_buffer, args.user_stream, args.stage);

            // launch_kernel_intersect_tlas_affine_async

            // launch_kernel_intersect_tlas_hermite_async

            // launch_kernel_intersect_blas_affine_async

            // launch_kernel_intersect_blas_hermite_async

            launch_kernel_intersect_async(args.wavefront_buffer, args.user_stream, args.stage);

            launch_kernel_bxdf_async(args.wavefront_buffer, args.user_stream, args.stage);

            launch_kernel_redistribute_radiance_async(args.wavefront_buffer, args.user_stream, args.stage);

            launch_kernel_enforce_ray_limits_async(args.wavefront_buffer, args.user_stream, args.stage.render_settings);

            args.wavefront_buffer.queue_pool.swap_advance_queues();

            launch_kernel_splat_to_renderbuffer_async(args.wavefront_buffer, args.user_stream, args.stage.render_settings, args.stage.color_settings, args.color_pipeline, args.x_sample, args.d_renderbuffer);

            is_work_done_sync(&working, &args.wavefront_buffer.queue_ceiling, args.wavefront_buffer.queue_pool.get_count_ptr<advance_A_queue_t>(), args.user_stream);

            args.wavefront_buffer.iteration++; // This is safe despite the Async kernels for two reasons. 1. The sync point is above us; 2. When a kernel is launched all arguments are captured. 
        }

        args.x_sample++;
    }

    void release_wavefront_buffer(device_mem_arena* wavefront_buffer_arena, cudaStream_t user_stream)
    {
        device_arena_destroy_async(user_stream, wavefront_buffer_arena);
        check_cuda_errors(cudaStreamSynchronize(user_stream));
        check_cuda_errors(cudaGetLastError());
    }

}
