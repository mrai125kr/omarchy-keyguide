#define main keyguide_observer_program_main
#include "../../src/observer/keyguide-observer.c"
#undef main

#include <assert.h>
#include <stdio.h>

static void advertise(unsigned char bits[KEY_BITS_SIZE], unsigned int code)
{
    bits[code / 8U] |= (unsigned char)(1U << (code % 8U));
}

static void test_accepts_keyboard_action_nodes_without_meta(void)
{
    unsigned char secondary_keyboard[KEY_BITS_SIZE] = {0};
    unsigned char numpad[KEY_BITS_SIZE] = {0};

    advertise(secondary_keyboard, KEY_B);
    advertise(numpad, KEY_KP1);

    assert(has_keyboard_key(secondary_keyboard));
    assert(has_keyboard_key(numpad));
}

static void test_does_not_classify_pointer_or_touch_nodes_as_keyboards(void)
{
    unsigned char mouse[KEY_BITS_SIZE] = {0};
    unsigned char touch[KEY_BITS_SIZE] = {0};
    unsigned char gamepad[KEY_BITS_SIZE] = {0};

    advertise(mouse, BTN_LEFT);
    advertise(touch, BTN_TOUCH);
    advertise(gamepad, BTN_DPAD_UP);
    advertise(gamepad, BTN_GRIPL);

    assert(!has_keyboard_key(mouse));
    assert(!has_keyboard_key(touch));
    assert(!has_keyboard_key(gamepad));
}

int main(void)
{
    test_accepts_keyboard_action_nodes_without_meta();
    test_does_not_classify_pointer_or_touch_nodes_as_keyboards();
    puts("PASS: observer capabilities");
    return 0;
}
