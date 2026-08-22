#ifndef KEYGUIDE_MODIFIER_STATE_H
#define KEYGUIDE_MODIFIER_STATE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <linux/input-event-codes.h>

#define MODIFIER_STATE_MAX_DEVICES 64
#define MODIFIER_STATE_KEY_BYTES ((KEY_MAX + 8U) / 8U)

struct modifier_device_state {
    int device_id;
    uint8_t modifiers;
    uint8_t actions[MODIFIER_STATE_KEY_BYTES];
    bool used;
};

struct modifier_state {
    bool super;
    bool ctrl;
    bool shift;
    bool alt;
    bool action_pressed;
    uint64_t wheel_pulse;
    struct modifier_device_state devices[MODIFIER_STATE_MAX_DEVICES];
};

bool modifier_state_apply(struct modifier_state *state, int device_id,
                          unsigned int code, int value);
bool modifier_state_sync_device(struct modifier_state *state, int device_id,
                                const unsigned int *pressed_codes,
                                size_t pressed_count);
bool modifier_state_apply_wheel(struct modifier_state *state, int value);
bool modifier_state_remove_device(struct modifier_state *state, int device_id);
bool modifier_state_json(const struct modifier_state *state, char *buffer,
                         size_t size);

#endif
