#include "modifier_state.h"

#include <assert.h>
#include <linux/input-event-codes.h>
#include <stdio.h>
#include <string.h>

static void test_tracks_modifiers_across_devices(void)
{
    struct modifier_state state = {0};

    assert(modifier_state_apply(&state, 1, KEY_LEFTMETA, 1));
    assert(state.super);
    assert(!modifier_state_apply(&state, 1, KEY_LEFTMETA, 2));

    assert(modifier_state_apply(&state, 2, KEY_RIGHTCTRL, 1));
    assert(state.super && state.ctrl);

    assert(modifier_state_apply(&state, 1, KEY_LEFTMETA, 0));
    assert(!state.super && state.ctrl);

    assert(modifier_state_remove_device(&state, 2));
    assert(!state.ctrl);
}

static void test_tracks_left_and_right_keys_independently(void)
{
    struct modifier_state state = {0};

    assert(modifier_state_apply(&state, 7, KEY_LEFTSHIFT, 1));
    assert(!modifier_state_apply(&state, 7, KEY_RIGHTSHIFT, 1));
    assert(!modifier_state_apply(&state, 7, KEY_LEFTSHIFT, 0));
    assert(state.shift);
    assert(modifier_state_apply(&state, 7, KEY_RIGHTSHIFT, 0));
    assert(!state.shift);
}

static void test_tracks_the_same_modifier_across_devices(void)
{
    struct modifier_state state = {0};

    assert(modifier_state_apply(&state, 11, KEY_LEFTMETA, 1));
    assert(!modifier_state_apply(&state, 12, KEY_RIGHTMETA, 1));
    assert(!modifier_state_remove_device(&state, 11));
    assert(state.super);
    assert(modifier_state_remove_device(&state, 12));
    assert(!state.super);
}

static void test_resynchronizes_a_device_without_transient_state(void)
{
    struct modifier_state state = {0};
    const unsigned int current_codes[] = {KEY_RIGHTSHIFT, KEY_LEFTALT};

    assert(modifier_state_apply(&state, 21, KEY_LEFTCTRL, 1));
    assert(modifier_state_apply(&state, 22, KEY_LEFTMETA, 1));

    assert(modifier_state_sync_device(&state, 21, current_codes,
                                      sizeof current_codes /
                                          sizeof current_codes[0]));
    assert(state.super && !state.ctrl && state.shift && state.alt);

    assert(modifier_state_sync_device(&state, 21, NULL, 0));
    assert(state.super && !state.ctrl && !state.shift && !state.alt);
}

static void test_ignores_non_modifier_and_invalid_values(void)
{
    struct modifier_state state = {0};

    assert(!modifier_state_apply(&state, 3, KEY_LEFTALT, 3));
    assert(!state.super && !state.ctrl && !state.shift && !state.alt);
}

static void test_tracks_actions_across_devices(void)
{
    struct modifier_state state = {0};

    assert(modifier_state_apply(&state, 31, KEY_B, 1));
    assert(state.action_pressed);
    assert(!modifier_state_apply(&state, 32, BTN_RIGHT, 1));
    assert(state.action_pressed);

    assert(!modifier_state_apply(&state, 31, KEY_B, 0));
    assert(state.action_pressed);
    assert(modifier_state_apply(&state, 32, BTN_RIGHT, 0));
    assert(!state.action_pressed);
}

static void test_ignores_action_repeats_and_modifiers(void)
{
    struct modifier_state state = {0};

    assert(modifier_state_apply(&state, 41, KEY_A, 1));
    assert(!modifier_state_apply(&state, 41, KEY_A, 2));
    assert(state.action_pressed);
    assert(modifier_state_apply(&state, 41, KEY_A, 0));
    assert(!state.action_pressed);

    assert(modifier_state_apply(&state, 41, KEY_LEFTCTRL, 1));
    assert(!state.action_pressed);
    assert(modifier_state_apply(&state, 41, KEY_LEFTSHIFT, 1));
    assert(!state.action_pressed);
    assert(modifier_state_apply(&state, 41, KEY_LEFTALT, 1));
    assert(!state.action_pressed);
    assert(modifier_state_apply(&state, 41, KEY_LEFTMETA, 1));
    assert(!state.action_pressed);
}

static void test_non_mouse_buttons_do_not_count_as_actions(void)
{
    struct modifier_state state = {0};

    assert(!modifier_state_apply(&state, 42, BTN_TOUCH, 1));
    assert(!modifier_state_apply(&state, 42, BTN_TOOL_FINGER, 1));
    assert(!modifier_state_apply(&state, 42, BTN_GAMEPAD, 1));
    assert(!modifier_state_apply(&state, 42, BTN_DPAD_UP, 1));
    assert(!modifier_state_apply(&state, 42, BTN_GRIPL, 1));
    assert(!state.action_pressed);
}

static void test_removing_a_device_clears_only_its_actions(void)
{
    struct modifier_state state = {0};

    assert(modifier_state_apply(&state, 51, KEY_C, 1));
    assert(!modifier_state_apply(&state, 52, BTN_LEFT, 1));
    assert(!modifier_state_remove_device(&state, 51));
    assert(state.action_pressed);
    assert(modifier_state_remove_device(&state, 52));
    assert(!state.action_pressed);
}

static void test_resynchronizes_actions_after_dropped_events(void)
{
    struct modifier_state state = {0};
    const unsigned int before_drop[] = {KEY_LEFTMETA, KEY_D};
    const unsigned int after_drop[] = {KEY_LEFTMETA, BTN_MIDDLE};
    const unsigned int modifier_only[] = {KEY_LEFTMETA, KEY_RIGHTSHIFT};

    assert(modifier_state_sync_device(
        &state, 61, before_drop,
        sizeof before_drop / sizeof before_drop[0]));
    assert(state.super && state.action_pressed);

    assert(!modifier_state_sync_device(
        &state, 61, after_drop,
        sizeof after_drop / sizeof after_drop[0]));
    assert(state.super && state.action_pressed);

    assert(modifier_state_sync_device(
        &state, 61, modifier_only,
        sizeof modifier_only / sizeof modifier_only[0]));
    assert(state.super && state.shift && !state.action_pressed);
}

static void test_counts_wheel_events_monotonically(void)
{
    struct modifier_state state = {0};

    assert(!modifier_state_apply_wheel(&state, 0));
    assert(state.wheel_pulse == 0);
    assert(modifier_state_apply_wheel(&state, 1));
    assert(state.wheel_pulse == 1);
    assert(modifier_state_apply_wheel(&state, -1));
    assert(state.wheel_pulse == 2);
}

static void test_serializes_the_public_state(void)
{
    struct modifier_state state = {0};
    char json[128];

    assert(modifier_state_apply(&state, 9, KEY_RIGHTMETA, 1));
    assert(modifier_state_apply(&state, 9, KEY_LEFTALT, 1));
    assert(modifier_state_json(&state, json, sizeof json));
    assert(strcmp(json,
                  "{\"super\":true,\"ctrl\":false,\"shift\":false,"
                  "\"alt\":true,\"actionPressed\":false,"
                  "\"wheelPulse\":0}") == 0);
}

int main(void)
{
    test_tracks_modifiers_across_devices();
    test_tracks_left_and_right_keys_independently();
    test_tracks_the_same_modifier_across_devices();
    test_resynchronizes_a_device_without_transient_state();
    test_ignores_non_modifier_and_invalid_values();
    test_tracks_actions_across_devices();
    test_ignores_action_repeats_and_modifiers();
    test_non_mouse_buttons_do_not_count_as_actions();
    test_removing_a_device_clears_only_its_actions();
    test_resynchronizes_actions_after_dropped_events();
    test_counts_wheel_events_monotonically();
    test_serializes_the_public_state();
    puts("PASS: modifier state");
    return 0;
}
