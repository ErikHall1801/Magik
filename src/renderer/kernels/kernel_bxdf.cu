#include "kernel_bxdf.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"

#include "kernel_advance_geodesic.cuh"
#include "relativity_utilities.cuh"
#include "metric_minkowski.cuh"
#include "metric_schwarzschild.cuh"
#include "metric_kerr.cuh"

#include "bxdf_utilities.cuh"

namespace magik
{
    static __device__ vec3f random_unit_three_vector(curandState_t* random_device, vec3f n)
    {
        using ::sin;
        using ::cos;
        using ::acos;

        float u = curand_uniform(random_device);
        float theta = acos(1.0f - 2.0f*u);
        float phi = 2.0f*magik::pi*curand_uniform(random_device);

        vec3f p;
        p.x = cos(phi) * sin(theta);
        p.y = sin(phi) * sin(theta);
        p.z = cos(theta);
        return (p+n).norm();
    }

    static __device__ vec3f offset_origin(vec3f x, vec3f n)
    {
        /*
        CREDITS;

        https://github.com/Apress/ray-tracing-gems/blob/master/Ch_06_A_Fast_and_Robust_Method_for_Avoiding_Self-Intersection/offset_ray.cu

        To make the function transform the offset into the surface, simply negate the normal
        assuming the convention that the passed in normal always opposes the geodesics direction ! 
        */

        const float offset_scale = 4.0f;
        const float int_scale = 256.0f * offset_scale;
        const float float_scale = (1.0f / 65536.0f) * offset_scale;
        const float origin = 1.0f / 32.0f;

        int of_ix = int_scale*n.x;
        int of_iy = int_scale*n.y;
        int of_iz = int_scale*n.z;

        float p_ix = __int_as_float(__float_as_int(x.x) + ((x.x < 0) ? -of_ix : of_ix));
        float p_iy = __int_as_float(__float_as_int(x.y) + ((x.y < 0) ? -of_iy : of_iy));
        float p_iz = __int_as_float(__float_as_int(x.z) + ((x.z < 0) ? -of_iz : of_iz));

        return vec3f{   fabsf(x.x) < origin ? x.x+float_scale*n.x : p_ix,
                        fabsf(x.y) < origin ? x.y+float_scale*n.y : p_iy,
                        fabsf(x.z) < origin ? x.z+float_scale*n.z : p_iz };
    }

    template<e_magik_spacetime_metric_types T, class bxdf_matter> static __global__ void kernel_bxdf(typename metric<T>::params_t metric_parameters)
    {
        // Constrain threads by stride and range within the bxdf queue based on the material id 

        bxdf_velocity_context v_context;
        // setup v context
        vec3f result_three_velocity = bxdf_matter::velocity(v_context);

        bxdf_material_context m_context;
        // setup m context 
        bxdf_result result_material = bxdf_matter::material(m_context);

        // Submit to advance or splat queue 
    }

    void launch_kernel_bxdf_async(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer)
    {
        uint32_t threads_per_block = manager->stage.settings.wavefront_threads_per_block;
        uint32_t n_block = (wavefront_buffer->queue_ceiling + threads_per_block - 1) / threads_per_block;

        uint32_t* d_hit_id = wavefront_buffer->ray_pool.get<hit_id_t>();
        vec4f* d_hit_normal = wavefront_buffer->ray_pool.get<hit_normal_t>();
        vec4f* current_four_position = wavefront_buffer->ray_pool.get<current_four_position_t>();
        vec4f* next_four_position = wavefront_buffer->ray_pool.get<next_four_position_t>();
        curandState_t* d_random_device = wavefront_buffer->ray_pool.get<random_device_t>();
        float* d_monte_carlo_weight = wavefront_buffer->ray_pool.get<monte_carlo_weight_t>();
        float* d_spectral_radiance = wavefront_buffer->ray_pool.get<spectral_radiance_t>();
        float* d_sensor_wavelength_nm = wavefront_buffer->ray_pool.get<sensor_wavelength_nm_t>();

        uint32_t* d_bxdf_queue_count = wavefront_buffer->queue_pool.get_count_ptr<bxdf_queue_t>();
        uint32_t* d_bxdf_queue_id = wavefront_buffer->queue_pool.get_id_ptr<bxdf_queue_t>();

        uint32_t* d_advance_queue_A_count = wavefront_buffer->queue_pool.get_count_ptr<advance_A_queue_t>();
        uint32_t* d_advance_queue_A_id = wavefront_buffer->queue_pool.get_id_ptr<advance_A_queue_t>();

        uint32_t* d_redistribute_queue_count = wavefront_buffer->queue_pool.get_count_ptr<redistribute_queue_t>();
        uint32_t* d_redistribute_queue_id = wavefront_buffer->queue_pool.get_id_ptr<redistribute_queue_t>();

        bool successful = dispatch_metric(manager->stage.settings.metric_type, [&](auto tag)
        {
            constexpr auto T = decltype(tag)::value;
            // kernel_bxdf<T><<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(metric<T>::make_params(manager), d_hit_id, d_hit_normal, current_four_position, next_four_position, d_random_device, d_monte_carlo_weight, d_spectral_radiance, d_sensor_wavelength_nm, d_bxdf_queue_count, d_bxdf_queue_id, d_advance_queue_A_count, d_advance_queue_A_id, d_redistribute_queue_count, d_redistribute_queue_id);
        });

        check_cuda_errors(cudaGetLastError());

        wavefront_buffer->queue_pool.zero_count_async<bxdf_queue_t>(static_cast<cudaStream_t>(manager->cuda_stream));

        if(!successful)
        {
            e_magik_result_types expected = MAGIK_SUCCESS, result = MAGIK_ERROR_UNKNOWN_METRIC;
            manager->atomic_last_error_type.compare_exchange_strong(expected, result);
            manager->is_running.store(false, std::memory_order_release);
        }
    }
}
