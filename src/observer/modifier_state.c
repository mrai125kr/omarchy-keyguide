#include "modifier_state.h"
#include "input_codes.h"

#include <inttypes.h>
#include <stdio.h>
#include <string.h>

enum modifier_bit {
    MOD_LEFT_SUPER = 1U << 0,
    MOD_RIGHT_SUPER = 1U << 1,
    MOD_LEFT_CTRL = 1U << 2,
    MOD_RIGHT_CTRL = 1U << 3,
    MOD_LEFT_SHIFT = 1U << 4,
    MOD_RIGHT_SHIFT = 1U << 5,
    MOD_LEFT_ALT = 1U << 6,
    MOD_RIGHT_ALT = 1U << 7,
};

static uint8_t modifier_bit_for_code(unsigned int code)
{
    switch (code) {
    case KEY_LEFTMETA:
        return MOD_LEFT_SUPER;
    case KEY_RIGHTMETA:
        return MOD_RIGHT_SUPER;
    case KEY_LEFTCTRL:
        return MOD_LEFT_CTRL;
    case KEY_RIGHTCTRL:
        return MOD_RIGHT_CTRL;
    case KEY_LEFTSHIFT:
        return MOD_LEFT_SHIFT;
    case KEY_RIGHTSHIFT:
        return MOD_RIGHT_SHIFT;
    case KEY_LEFTALT:
        return MOD_LEFT_ALT;
    case KEY_RIGHTALT:
        return MOD_RIGHT_ALT;
    default:
        return 0;
    }
}

static bool action_code(unsigned int code)
{
    return input_code_is_action(code) &&
           modifier_bit_for_code(code) == 0;
}

static bool action_is_set(const uint8_t actions[MODIFIER_STATE_KEY_BYTES],
                          unsigned int code)
{
    return (actions[code / 8U] & (uint8_t)(1U << (code % 8U))) != 0;
}

static void set_action(uint8_t actions[MODIFIER_STATE_KEY_BYTES],
                       unsigned int code, bool pressed)
{
    uint8_t mask = (uint8_t)(1U << (code % 8U));

    if (pressed) {
        actions[code / 8U] |= mask;
    } else {
        actions[code / 8U] &= (uint8_t)~mask;
    }
}

static bool has_actions(const uint8_t actions[MODIFIER_STATE_KEY_BYTES])
{
    size_t index;

    for (index = 0; index < MODIFIER_STATE_KEY_BYTES; ++index) {
        if (actions[index] != 0) {
            return true;
        }
    }
    return false;
}

static bool device_has_state(const struct modifier_device_state *device)
{
    return device->modifiers != 0 || has_actions(device->actions);
}

static struct modifier_device_state *find_device(struct modifier_state *state,
                                                  int device_id)
{
    size_t index;

    for (index = 0; index < MODIFIER_STATE_MAX_DEVICES; ++index) {
        if (state->devices[index].used &&
            state->devices[index].device_id == device_id) {
            return &state->devices[index];
        }
    }
    return NULL;
}

static struct modifier_device_state *add_device(struct modifier_state *state,
                                                 int device_id)
{
    size_t index;

    for (index = 0; index < MODIFIER_STATE_MAX_DEVICES; ++index) {
        if (!state->devices[index].used) {
            state->devices[index].used = true;
            state->devices[index].device_id = device_id;
            state->devices[index].modifiers = 0;
            memset(state->devices[index].actions, 0,
                   sizeof state->devices[index].actions);
            return &state->devices[index];
        }
    }
    return NULL;
}

static bool refresh_public_state(struct modifier_state *state)
{
    bool old_super = state->super;
    bool old_ctrl = state->ctrl;
    bool old_shift = state->shift;
    bool old_alt = state->alt;
    bool old_action_pressed = state->action_pressed;
    uint8_t modifiers = 0;
    bool action_pressed = false;
    size_t index;

    for (index = 0; index < MODIFIER_STATE_MAX_DEVICES; ++index) {
        if (state->devices[index].used) {
            modifiers |= state->devices[index].modifiers;
            action_pressed = action_pressed ||
                             has_actions(state->devices[index].actions);
        }
    }

    state->super = (modifiers & (MOD_LEFT_SUPER | MOD_RIGHT_SUPER)) != 0;
    state->ctrl = (modifiers & (MOD_LEFT_CTRL | MOD_RIGHT_CTRL)) != 0;
    state->shift = (modifiers & (MOD_LEFT_SHIFT | MOD_RIGHT_SHIFT)) != 0;
    state->alt = (modifiers & (MOD_LEFT_ALT | MOD_RIGHT_ALT)) != 0;
    state->action_pressed = action_pressed;

    return old_super != state->super || old_ctrl != state->ctrl ||
           old_shift != state->shift || old_alt != state->alt ||
           old_action_pressed != state->action_pressed;
}

bool modifier_state_apply(struct modifier_state *state, int device_id,
                          unsigned int code, int value)
{
    struct modifier_device_state *device;
    uint8_t bit;
    bool is_action;

    if (state == NULL || (value != 0 && value != 1 && value != 2)) {
        return false;
    }

    bit = modifier_bit_for_code(code);
    is_action = action_code(code);
    if (bit == 0 && !is_action) {
        return false;
    }
    if (value == 2) {
        return false;
    }

    device = find_device(state, device_id);
    if (device == NULL) {
        if (value == 0) {
            return false;
        }
        device = add_device(state, device_id);
        if (device == NULL) {
            return false;
        }
    }

    if (bit != 0 && value == 1) {
        if ((device->modifiers & bit) != 0) {
            return false;
        }
        device->modifiers |= bit;
    } else if (bit != 0) {
        if ((device->modifiers & bit) == 0) {
            return false;
        }
        device->modifiers &= (uint8_t)~bit;
    } else if (value == 1) {
        if (action_is_set(device->actions, code)) {
            return false;
        }
        set_action(device->actions, code, true);
    } else {
        if (!action_is_set(device->actions, code)) {
            return false;
        }
        set_action(device->actions, code, false);
    }

    if (!device_has_state(device)) {
        device->used = false;
    }

    return refresh_public_state(state);
}

bool modifier_state_sync_device(struct modifier_state *state, int device_id,
                                const unsigned int *pressed_codes,
                                size_t pressed_count)
{
    struct modifier_device_state *device;
    uint8_t modifiers = 0;
    uint8_t actions[MODIFIER_STATE_KEY_BYTES] = {0};
    size_t index;

    if (state == NULL || (pressed_codes == NULL && pressed_count != 0)) {
        return false;
    }

    for (index = 0; index < pressed_count; ++index) {
        uint8_t bit = modifier_bit_for_code(pressed_codes[index]);

        if (bit != 0) {
            modifiers |= bit;
        } else if (action_code(pressed_codes[index])) {
            set_action(actions, pressed_codes[index], true);
        }
    }

    device = find_device(state, device_id);
    if (device == NULL && (modifiers != 0 || has_actions(actions))) {
        device = add_device(state, device_id);
        if (device == NULL) {
            return false;
        }
    }

    if (device != NULL) {
        device->modifiers = modifiers;
        memcpy(device->actions, actions, sizeof device->actions);
        if (!device_has_state(device)) {
            device->used = false;
        }
    }
    return refresh_public_state(state);
}

bool modifier_state_apply_wheel(struct modifier_state *state, int value)
{
    if (state == NULL || value == 0 || state->wheel_pulse == UINT64_MAX) {
        return false;
    }

    ++state->wheel_pulse;
    return true;
}

bool modifier_state_remove_device(struct modifier_state *state, int device_id)
{
    struct modifier_device_state *device;

    if (state == NULL) {
        return false;
    }

    device = find_device(state, device_id);
    if (device == NULL) {
        return false;
    }

    device->used = false;
    device->modifiers = 0;
    memset(device->actions, 0, sizeof device->actions);
    return refresh_public_state(state);
}

bool modifier_state_json(const struct modifier_state *state, char *buffer,
                         size_t size)
{
    int written;

    if (state == NULL || buffer == NULL || size == 0) {
        return false;
    }

    written = snprintf(buffer, size,
                       "{\"super\":%s,\"ctrl\":%s,\"shift\":%s,"
                       "\"alt\":%s,\"actionPressed\":%s,"
                       "\"wheelPulse\":%" PRIu64 "}",
                       state->super ? "true" : "false",
                       state->ctrl ? "true" : "false",
                       state->shift ? "true" : "false",
                       state->alt ? "true" : "false",
                       state->action_pressed ? "true" : "false",
                       state->wheel_pulse);
    return written >= 0 && (size_t)written < size;
}
