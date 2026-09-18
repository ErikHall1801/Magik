#include "magik_command_queue_system.h"
#include "magik_render_manager.h"

namespace magik::cqs
{
    void fetch_command_info(e_magik_cqs_command_types type, bool* is_valid_command, size_t* command_size)
    {
        bool is_valid_ = false;
        size_t size_ = 0;

        switch(type)
        {
            // ##################################
            // ### 1000-1999 Basic operations ###
            // ##################################
            case MAGIK_COMMAND_SET_STATE_RENDER: { is_valid_ = true; size_ = sizeof(magik_command_set_state_render_t); break; }

            case MAGIK_COMMAND_SET_STATE_PAUSE: { is_valid_ = true; size_ = sizeof(magik_command_set_state_pause_t); break; }

            case MAGIK_COMMAND_CLEAR_RENDER_BUFFER: { is_valid_ = true; size_ = sizeof(magik_command_clear_render_buffer_t); break; }

            case MAGIK_COMMAND_ADD_AOV: { is_valid_ = true; size_ = sizeof(magik_command_add_aov_t); break; }

            case MAGIK_COMMAND_REMOVE_AOV: { is_valid_ = true; size_ = sizeof(magik_command_remove_aov_t); break; }



            // ################################
            // ### 2000-2999 Built-in tests ###
            // ################################
            case MAGIK_COMMAND_PRINTF: { is_valid_ = true; size_ = sizeof(magik_command_printf_t); break; }

            case MAGIK_COMMAND_SET_RESOLUTION: { is_valid_ = true; size_ = sizeof(magik_command_set_resolution_t); break; }

            case MAGIK_COMMAND_SET_JULIA_SET_OFFSET: { is_valid_ = true; size_ = sizeof(magik_command_set_julia_set_offset_t); break; }

            case MAGIK_COMMAND_SET_JULIA_SET_COLOR: { is_valid_ = true; size_ = sizeof(magik_command_set_julia_set_color_t); break; }



            // ##########################
            // ### 3000-3999 Settings ###
            // ##########################



            // #######################
            // ### 4000-4999 Scene ###
            // #######################


            
            // ########################
            // ### 5000-5999 Camera ###
            // ########################



            // #################################
            // ### 6000-6999 Hittable Object ###
            // #################################



            // ################################
            // ### 7000-7999 bxdf materials ###
            // ################################ 



            default: { break; }
        }

        *is_valid_command = is_valid_;
        *command_size = size_;
    }

    void apply_command(magik_render_manager* manager, uint32_t* playhead, buffer_object* buffer, e_magik_cqs_command_types command_type, size_t command_size)
    {
        switch(command_type)
        {
            // ##################################
            // ### 1000-1999 Basic operations ###
            // ##################################
            case MAGIK_COMMAND_SET_STATE_RENDER:
            {
                break;
            }

            case MAGIK_COMMAND_SET_STATE_PAUSE:
            {
                break;
            }

            case MAGIK_COMMAND_CLEAR_RENDER_BUFFER:
            {
                break;
            }

            case MAGIK_COMMAND_ADD_AOV:
            {
                magik_command_add_aov_t cmd;
                memcpy(&cmd, playhead, command_size);
                std::string aov_name(cmd.name, cmd.length_of_name);
                magik::aov::raw_buffer aov;
                aov.channels = cmd.channels;
                manager->aov_context.render_framebuffer_object.collection.emplace(aov_name, aov);
                break;
            }

            case MAGIK_COMMAND_REMOVE_AOV:
            {
                magik_command_remove_aov_t cmd;
                memcpy(&cmd, playhead, command_size);
                std::string aov_name(cmd.name, cmd.length_of_name);
                manager->aov_context.render_framebuffer_object.collection.erase(aov_name);
                break;
            }



            // ################################
            // ### 2000-2999 Built-in tests ###
            // ################################
            case MAGIK_COMMAND_PRINTF:
            {
                magik_command_printf_t cmd;
                memcpy(&cmd, playhead, command_size);
                if(cmd.length_of_text < 512) printf("%.*s \n", cmd.length_of_text, cmd.text);
                break;
            }

            case MAGIK_COMMAND_SET_RESOLUTION:
            {
                magik_command_set_resolution_t cmd;
                memcpy(&cmd, playhead, command_size);
                manager->aov_context.x_resolution_target = cmd.x_resolution;
                manager->aov_context.y_resolution_target = cmd.y_resolution;
                break;
            }

            case MAGIK_COMMAND_SET_JULIA_SET_OFFSET:
            {
                magik_command_set_julia_set_offset_t cmd;
                memcpy(&cmd, playhead, command_size);
                manager->render_context.real = cmd.real;
                manager->render_context.imag = cmd.imaginary;
                break;
            }

            case MAGIK_COMMAND_SET_JULIA_SET_COLOR:
            {
                magik_command_set_julia_set_color_t cmd;
                memcpy(&cmd, playhead, command_size);
                manager->render_context.c0 = cmd.c0;
                manager->render_context.c1 = cmd.c1;
                manager->render_context.c2 = cmd.c2;
                break;
            }



            // ##########################
            // ### 3000-3999 Settings ###
            // ##########################



            // #######################
            // ### 4000-4999 Scene ###
            // #######################


            
            // ########################
            // ### 5000-5999 Camera ###
            // ########################



            // #################################
            // ### 6000-6999 Hittable Object ###
            // #################################



            // ################################
            // ### 7000-7999 bxdf materials ###
            // ################################ 



            default:
            {
                break;
            }
        }
    }

    e_magik_result_types push_command(magik_render_manager_t manager, const void* command)
    {
        if(!manager || !command) return MAGIK_ERROR_INVALID_POINTER;

        if(reinterpret_cast<uintptr_t>(command) % sizeof(uint32_t) != 0) return MAGIK_ERROR_PACKED_COMMAND_NOT_ALLIGNED;

        e_magik_cqs_command_types command_type;
        memcpy(&command_type, command, sizeof(e_magik_cqs_command_types)); 
        
        bool is_valid = false;
        size_t command_size = 0;
        magik::cqs::fetch_command_info(command_type, &is_valid, &command_size);

        if(!is_valid) return MAGIK_ERROR_INVALID_COMMAND;

        if(command_size % sizeof(uint32_t) != 0) return MAGIK_ERROR_COMMAND_SIZE_NOT_A_MULTIPLE_OF_4;

        size_t command_buffer_occupancy = (size_t)(manager->cqs_context.front->n_occupied_chunk)*sizeof(uint32_t);
        size_t command_buffer_capacity = (size_t)(manager->cqs_context.n_reserved_chunk)*sizeof(uint32_t);

        if((command_buffer_occupancy+command_size) > command_buffer_capacity)
        {
            if(manager->cqs_context.drop_overflows)
            {
                return MAGIK_SUCCESS;
            }
            else
            {
                return MAGIK_ERROR_COMMAND_BUFFER_OVERFLOW;
            }
        }

        uint32_t* head_ptr = manager->cqs_context.front->data.get() + manager->cqs_context.front->n_occupied_chunk;
        memcpy(head_ptr, command, command_size);
        manager->cqs_context.front->n_occupied_chunk += static_cast<uint32_t>(command_size / sizeof(uint32_t));

        return MAGIK_SUCCESS;
    }

    e_magik_result_types dispatch_command_buffer(magik_render_manager_t manager, bool* is_dispatched)
    {
        if(!manager) 
        {
            *is_dispatched = false;
            return MAGIK_ERROR_INVALID_POINTER;
        }

        if(manager->cqs_context.is_swap_ready.load(std::memory_order_acquire))
        {
            manager->cqs_context.front.swap(manager->cqs_context.back);
            manager->cqs_context.is_swap_ready.store(false, std::memory_order_release);

            *is_dispatched = true;
            return MAGIK_SUCCESS;
        }
        else
        {
            *is_dispatched = false;
            return MAGIK_SUCCESS;
        }
    }

    e_magik_result_types consume_command_buffer(magik_render_manager_t manager, buffer_object* buffer)
    {
        /*
        * We ultimately want to apply the commands on the DCC as well to maintain a 
        * mirror copy of the render graph. This can be done with this function, we 
        * just need to copy the buffer before consuming it. 
        * And, once it exists, pass in the correct render graph. 
        */

        if(!manager) return MAGIK_ERROR_INVALID_POINTER;

        size_t command_buffer_occupancy = (size_t)(buffer->n_occupied_chunk);
        uint32_t* playhead = buffer->data.get();
        size_t playhead_offset = 0;

        e_magik_cqs_command_types command_type;
        bool is_valid = false;
        size_t command_size = 0;

        while(command_buffer_occupancy > playhead_offset)
        {
            memcpy(&command_type, (playhead + playhead_offset), sizeof(e_magik_cqs_command_types));

            fetch_command_info(command_type, &is_valid, &command_size);

            if(!is_valid || command_size == 0 || (command_size % sizeof(uint32_t) != 0)) return MAGIK_ERROR_INVALID_COMMAND;

            if(((playhead_offset + command_size) / sizeof(uint32_t)) > command_buffer_occupancy) return MAGIK_ERROR_OUT_OF_BOUNDS_COMMAND_BUFFER_READ;

            apply_command(manager, (playhead + playhead_offset), buffer, command_type, command_size);

            playhead_offset += (command_size/sizeof(uint32_t));
        }

        buffer->n_occupied_chunk = 0;
        return MAGIK_SUCCESS;
    }

    e_magik_result_types consume_back_command_buffer(magik_render_manager_t manager)
    {
        e_magik_result_types error = consume_command_buffer(manager, manager->cqs_context.back.get());
        manager->cqs_context.is_swap_ready.store(true, std::memory_order_release);
        return error;
    }
}
