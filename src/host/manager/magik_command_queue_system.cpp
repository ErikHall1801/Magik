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
        if(command_type == MAGIK_COMMAND_SET_RESOLUTION)
        {
            magik_command_set_resolution_t cmd;
            memcpy(&cmd, playhead, command_size);
            manager->aov_context.x_resolution = cmd.x_resolution;
            manager->aov_context.y_resolution = cmd.y_resolution;
        }

        if(command_type == MAGIK_COMMAND_SET_JULIA_SET_COLOR)
        {
            magik_command_set_julia_set_color_t cmd;
            memcpy(&cmd, playhead, command_size);
            manager->render_context.c0 = cmd.c0;
            manager->render_context.c1 = cmd.c1;
            manager->render_context.c2 = cmd.c2;
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

        if(!manager) set_and_return_error(MAGIK_ERROR_INVALID_POINTER);

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

            if(!is_valid || command_size == 0 || (command_size % sizeof(uint32_t) != 0)) set_and_return_error(MAGIK_ERROR_INVALID_COMMAND);

            apply_command(manager, (playhead + playhead_offset), buffer, command_type, command_size);

            playhead_offset += (command_size/sizeof(uint32_t));
        }

        buffer->n_occupied_chunk = 0;
        set_and_return_error(MAGIK_SUCCESS);
    }

    e_magik_result_types consume_back_command_buffer(magik_render_manager_t manager)
    {
        e_magik_result_types error = consume_command_buffer(manager, manager->cqs_context.back.get());
        manager->cqs_context.is_swap_ready.store(true, std::memory_order_release);
        set_and_return_error(error);
    }
}
