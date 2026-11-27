#include "kernel_splat_to_renderbuffer.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"
#include "device_color_utilities.cuh"
#include "color_pipeline.h"
#include "color_settings.h"
#include "render_settings.h"

namespace magik
{
    struct kernel_splat_to_renderbuffer_t
    {
        uint32_t x_resolution;
        uint32_t y_resolution;

        float* d_intrinsic_spectral_irradiance;
        uint32_t* d_splat_queue_count;
        uint32_t* d_splat_queue_id;
        float* d_renderbuffer;
        color_pipeline_descriptor_t color_pipeline_descriptor;

        uint32_t n_isi_bin;
        float max_wavelength_nm;
        float min_wavelength_nm;
        uint32_t x_sample;

        __host__ void create(wavefront_buffer_t& wavefront_buffer, color_settings_t& color_settings, color_pipeline_descriptor_t& host_color_pipeline_descriptor, uint32_t sample, float* d_target_buffer)
        {
            x_resolution = wavefront_buffer.x_resolution;
            y_resolution = wavefront_buffer.y_resolution;

            d_intrinsic_spectral_irradiance = wavefront_buffer.ray_pool.get<intrinsic_spectral_irradiance_t>();
            d_renderbuffer = d_target_buffer;
            color_pipeline_descriptor = host_color_pipeline_descriptor;

            n_isi_bin = color_settings.n_isi_bin;
            max_wavelength_nm = color_settings.isi_max_wavelength_nm;
            min_wavelength_nm = color_settings.isi_min_wavelength_nm;
            x_sample = sample;
        }
    };

    template<e_magik_view_transform_types T> static __global__ void kernel_splat_to_renderbuffer(typename generic_view_transform_t<T>::params_t view_transform_params, kernel_splat_to_renderbuffer_t args)
    {
        if(!magik::is_valid_thread(args.x_resolution, args.y_resolution)) return;

        uint32_t thread_id = magik::get_n_dimensional_thread_id(args.x_resolution, 1);

        intrinsic_spectral_irradiance_to_color_args_t isi_args;
        isi_args.n_isi_bin = args.n_isi_bin;
        isi_args.ray_id = thread_id;
        isi_args.d_intrinsic_spectral_irradiance = args.d_intrinsic_spectral_irradiance;
        isi_args.isi_to_scene_referred_weights = args.color_pipeline_descriptor.isi_to_scene_referred_weights;
        isi_args.x_sample = args.x_sample;

        vec3f scene_color = intrinsic_spectral_irradiance_to_scene_color(isi_args);

        vec3f display_color = scene_to_display_referred_color<T>(view_transform_params, scene_color, args.color_pipeline_descriptor);

        args.d_renderbuffer[thread_id * 3 + 0] = display_color.x;
        args.d_renderbuffer[thread_id * 3 + 1] = display_color.y;
        args.d_renderbuffer[thread_id * 3 + 2] = display_color.z;
    }

    void launch_kernel_splat_to_renderbuffer_sync(wavefront_buffer_t& wavefront_buffer, cudaStream_t user_stream, render_settings_t& render_settings, color_settings_t& color_settings, color_pipeline_descriptor_t& color_pipeline_descriptor, uint32_t x_sample, float* d_renderbuffer)
    {
        if(!d_renderbuffer) return;

        dim3 threads_per_block = dim3(render_settings.threads_per_block_x, render_settings.threads_per_block_y, 1);
        dim3 n_block = magik::compute_n_blocks(wavefront_buffer.x_resolution, wavefront_buffer.y_resolution, render_settings.threads_per_block_x, render_settings.threads_per_block_y);

        kernel_splat_to_renderbuffer_t args;
        args.create(wavefront_buffer, color_settings, color_pipeline_descriptor, x_sample, d_renderbuffer);

        bool successful = dispatch_list(supported_view_transforms{}, color_pipeline_descriptor.view_transform_type, [&](auto tag)
        {
            constexpr auto T = decltype(tag)::value;
            kernel_splat_to_renderbuffer<T><<<n_block, threads_per_block, 0, user_stream>>>(generic_view_transform_t<T>::make_params(color_settings), args);

        });

        check_cuda_errors(cudaGetLastError());
    }
}
