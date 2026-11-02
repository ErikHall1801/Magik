#include "kernel_bxdf.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"

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

    static __global__ void kernel_bxdf(uint32_t* d_hit_id, vec4f* d_hit_normal, vec4f* d_dir, vec4f* d_pos, curandState_t* d_random_device, float* d_step_distance, float* d_monte_carlo_weight, float* d_spectral_radiance, float* d_sensor_wavelength_nm, uint32_t* d_bxdf_queue_count, uint32_t* d_bxdf_queue_id, uint32_t* d_advance_queue_A_count, uint32_t* d_advance_queue_A_id, uint32_t* d_redistribute_queue_count, uint32_t* d_redistribute_queue_id)
    {
        // Reads "bxdf queue"
        // Writes "advance queue" or "redistribution queue"

        // 1. Fetch ray id
        uint32_t queue_index = blockIdx.x * blockDim.x + threadIdx.x;
        if(queue_index >= *d_bxdf_queue_count) return;
        uint32_t ray_id = d_bxdf_queue_id[queue_index];

        // 2. Fetch ray-specific data
        uint32_t hit_id = d_hit_id[ray_id];

        bool to_advance = false;

        // 3. Do work
        if(hit_id == 1)
        {
            // Box, reflect ray dir, offset ray orig, set "step distance" to 0, send to advance queue

            vec3f hit_normal = vec3f{d_hit_normal[ray_id].x, d_hit_normal[ray_id].y, d_hit_normal[ray_id].z};
            vec3f hit_dir = vec3f{d_dir[ray_id].x, d_dir[ray_id].y, d_dir[ray_id].z};

            vec3f n = vector_dot_product(hit_normal, hit_dir) < 0.0f ? hit_normal : -hit_normal; // faces the ray
            vec3f outgoing_dir = random_unit_three_vector(&d_random_device[ray_id], n);

            if(vector_dot_product(outgoing_dir, n) < 0.0f)
            {
                outgoing_dir *= -1.0f;
            }

            vec3f new_orig = offset_origin(vec3f{d_pos[ray_id].x, d_pos[ray_id].y, d_pos[ray_id].z}, n);

            d_dir[ray_id] = vec4f{outgoing_dir.x, outgoing_dir.y, outgoing_dir.z, 0.0f};
            d_pos[ray_id] = vec4f{new_orig.x, new_orig.y, new_orig.z};
            d_step_distance[ray_id] = 0.0f;
            d_monte_carlo_weight[ray_id] *= 0.9f;

            to_advance = true;
        }
        else if(hit_id == 2)
        {
            // Light
            // ray_pool.d_spectral_radiance[ray_id] = magik::evaluate_sodium_vapor_lamp_spectrum(ray_pool.d_sensor_wavelength_nm[ray_id]) * 50000000000.0f;
            // float temperature = magik::map_range(0.0f, 1.0f, 500.0f, 1400.0f, (ray_pool.d_pos[ray_id].x + 5.0f) / 10.0f);
            d_spectral_radiance[ray_id] = magik::sample_plancks_law<float>(d_sensor_wavelength_nm[ray_id], 5600.0f) * 0.007f;
            to_advance = false;
        }

        uint32_t slot = 0;

        if(to_advance)
        {
            slot = atomicAdd(d_advance_queue_A_count, 1);
            d_advance_queue_A_id[slot] = ray_id;
        }
        else
        {
            slot = atomicAdd(d_redistribute_queue_count, 1);
            d_redistribute_queue_id[slot] = ray_id;
        }
    }

    void launch_kernel_bxdf_async(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer)
    {
        uint32_t threads_per_block = manager->stage.settings.wavefront_threads_per_block;
        uint32_t n_block = (wavefront_buffer->queue_ceiling + threads_per_block - 1) / threads_per_block;

        uint32_t* d_hit_id = wavefront_buffer->ray_pool.get<hit_id_t>();
        vec4f* d_hit_normal = wavefront_buffer->ray_pool.get<hit_normal_t>();
        vec4f* d_dir = wavefront_buffer->ray_pool.get<direction_t>();
        vec4f* d_pos = wavefront_buffer->ray_pool.get<position_t>();
        curandState_t* d_random_device = wavefront_buffer->ray_pool.get<random_device_t>();
        float* d_step_distance = wavefront_buffer->ray_pool.get<step_distance_t>();
        float* d_monte_carlo_weight = wavefront_buffer->ray_pool.get<monte_carlo_weight_t>();
        float* d_spectral_radiance = wavefront_buffer->ray_pool.get<spectral_radiance_t>();
        float* d_sensor_wavelength_nm = wavefront_buffer->ray_pool.get<sensor_wavelength_nm_t>();

        uint32_t* d_bxdf_queue_count = wavefront_buffer->queue_pool.get_count_ptr<bxdf_queue_t>();
        uint32_t* d_bxdf_queue_id = wavefront_buffer->queue_pool.get_id_ptr<bxdf_queue_t>();

        uint32_t* d_advance_queue_A_count = wavefront_buffer->queue_pool.get_count_ptr<advance_A_queue_t>();
        uint32_t* d_advance_queue_A_id = wavefront_buffer->queue_pool.get_id_ptr<advance_A_queue_t>();

        uint32_t* d_redistribute_queue_count = wavefront_buffer->queue_pool.get_count_ptr<redistribute_queue_t>();
        uint32_t* d_redistribute_queue_id = wavefront_buffer->queue_pool.get_id_ptr<redistribute_queue_t>();

        kernel_bxdf<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(d_hit_id, d_hit_normal, d_dir, d_pos, d_random_device, d_step_distance, d_monte_carlo_weight, d_spectral_radiance, d_sensor_wavelength_nm, d_bxdf_queue_count, d_bxdf_queue_id, d_advance_queue_A_count, d_advance_queue_A_id, d_redistribute_queue_count, d_redistribute_queue_id);
        check_cuda_errors(cudaGetLastError());

        wavefront_buffer->queue_pool.zero_count_async<bxdf_queue_t>(static_cast<cudaStream_t>(manager->cuda_stream));
    }
}
