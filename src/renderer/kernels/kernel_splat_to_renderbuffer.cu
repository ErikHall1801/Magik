#include "kernel_splat_to_renderbuffer.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"
#include "device_color_utilities.cuh"
#include "color_pipeline.cuh"

namespace magik
{
    struct kernel_splat_to_renderbuffer_t
    {
        float* d_intrinsic_spectral_irradiance;
        uint32_t* d_splat_queue_count;
        uint32_t* d_splat_queue_id;
        float* d_renderbuffer;
        color_pipeline_descriptor_t color_pipeline_descriptor;
        
        uint32_t n_isi_bin;
        float max_wavelength_nm;
        float min_wavelength_nm;
        uint32_t x_sample;

        __host__ void create(magik_render_manager* manager, wavefront_buffer_t* wb, float* d_target_buffer)
        {
            d_intrinsic_spectral_irradiance = wb->ray_pool.get<intrinsic_spectral_irradiance_t>();
            d_splat_queue_count = wb->queue_pool.get_count_ptr<splat_queue_t>();
            d_splat_queue_id = wb->queue_pool.get_id_ptr<splat_queue_t>();
            d_renderbuffer = d_target_buffer;
            color_pipeline_descriptor = manager->color_pipeline_descriptor;

            n_isi_bin = manager->stage.settings.n_isi_bin;
            max_wavelength_nm = manager->stage.settings.isi_max_wavelength_nm;
            min_wavelength_nm = manager->stage.settings.isi_min_wavelength_nm;
            x_sample = manager->x_sample.load(std::memory_order_acquire);
        }
    };

    static __global__ void kernel_splat_to_renderbuffer(kernel_splat_to_renderbuffer_t args)
    {
        uint32_t queue_index = blockIdx.x * blockDim.x + threadIdx.x;
        if(queue_index >= *args.d_splat_queue_count) return;
        uint32_t ray_id = args.d_splat_queue_id[queue_index];

        intrinsic_spectral_irradiance_to_color_args_t isi_args;
        isi_args.n_isi_bin = args.n_isi_bin;
        isi_args.ray_id = ray_id;
        isi_args.d_intrinsic_spectral_irradiance = args.d_intrinsic_spectral_irradiance;
        isi_args.isi_to_scene_referred_weights = args.color_pipeline_descriptor.isi_to_scene_referred_weights;
        isi_args.x_sample = args.x_sample;

        vec3f scene_color = intrinsic_spectral_irradiance_to_scene_color(isi_args);

        vec3f display_color = scene_to_display_referred_color(scene_color, args.color_pipeline_descriptor);

        args.d_renderbuffer[ray_id * 3 + 0] = display_color.x;
        args.d_renderbuffer[ray_id * 3 + 1] = display_color.y;
        args.d_renderbuffer[ray_id * 3 + 2] = display_color.z;
    }

    void launch_kernel_splat_to_renderbuffer_async(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer, float* d_renderbuffer)
    {
        uint32_t threads_per_block = manager->stage.settings.wavefront_threads_per_block;
        uint32_t n_block = (wavefront_buffer->queue_ceiling + threads_per_block - 1) / threads_per_block;

        kernel_splat_to_renderbuffer_t args;
        args.create(manager, wavefront_buffer, d_renderbuffer);

        kernel_splat_to_renderbuffer<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(args);
        check_cuda_errors(cudaGetLastError());

        wavefront_buffer->queue_pool.store_count_in_history<splat_queue_t>(static_cast<cudaStream_t>(manager->cuda_stream), wavefront_buffer->iteration, manager->stage.settings.n_geodesic_step_limit);
        wavefront_buffer->queue_pool.zero_count_async<splat_queue_t>(static_cast<cudaStream_t>(manager->cuda_stream));
    }
}
