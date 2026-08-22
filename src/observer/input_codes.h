#ifndef KEYGUIDE_INPUT_CODES_H
#define KEYGUIDE_INPUT_CODES_H

#include <stdbool.h>
#include <linux/input-event-codes.h>

static inline bool input_code_is_keyboard_action(unsigned int code)
{
    bool gamepad_button = code >= BTN_DPAD_UP && code <= BTN_GRIPR2;

    return (code > KEY_RESERVED && code < BTN_MISC) ||
           (code >= KEY_OK && code < BTN_TRIGGER_HAPPY1 &&
            !gamepad_button);
}

static inline bool input_code_is_mouse_button(unsigned int code)
{
    return code >= BTN_LEFT && code <= BTN_TASK;
}

static inline bool input_code_is_action(unsigned int code)
{
    return input_code_is_keyboard_action(code) ||
           input_code_is_mouse_button(code);
}

#endif
