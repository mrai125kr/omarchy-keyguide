#define _GNU_SOURCE

#include <errno.h>
#include <stdarg.h>

#define open test_open
#define opendir test_opendir
#define readdir test_readdir
#define closedir test_closedir
#define main keyguide_observer_program_main
#include "../../src/observer/keyguide-observer.c"
#undef main
#undef closedir
#undef readdir
#undef opendir
#undef open

#include <assert.h>
#include <stdio.h>

static int fake_directory_entries;

int test_open(const char *path, int flags, ...)
{
    (void)path;
    (void)flags;
    errno = EACCES;
    return -1;
}

DIR *test_opendir(const char *path)
{
    (void)path;
    fake_directory_entries = 0;
    return (DIR *)(uintptr_t)1U;
}

struct dirent *test_readdir(DIR *directory)
{
    static struct dirent entry;

    (void)directory;
    if (fake_directory_entries++ > 0) {
        return NULL;
    }
    memset(&entry, 0, sizeof entry);
    strcpy(entry.d_name, "event3");
    return &entry;
}

int test_closedir(DIR *directory)
{
    (void)directory;
    return 0;
}

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
    advertise(gamepad, 0x224U);

    assert(!has_keyboard_key(mouse));
    assert(!has_keyboard_key(touch));
    assert(!has_keyboard_key(gamepad));
}

static void test_reports_the_device_open_error(void)
{
    int stderr_pipe[2];
    int saved_stderr;
    char output[128] = {0};
    ssize_t output_size;

    assert(pipe(stderr_pipe) == 0);
    saved_stderr = dup(STDERR_FILENO);
    assert(saved_stderr >= 0);
    assert(dup2(stderr_pipe[1], STDERR_FILENO) >= 0);
    close(stderr_pipe[1]);

    assert(keyguide_observer_program_main() == EXIT_FAILURE);
    assert(fflush(stderr) == 0);
    assert(dup2(saved_stderr, STDERR_FILENO) >= 0);
    close(saved_stderr);

    output_size = read(stderr_pipe[0], output, sizeof output - 1U);
    close(stderr_pipe[0]);
    assert(output_size > 0);
    assert(strcmp(output,
                  "{\"error\":\"no_readable_keyboard\",\"errno\":13}\n") == 0);
}

int main(void)
{
    test_accepts_keyboard_action_nodes_without_meta();
    test_does_not_classify_pointer_or_touch_nodes_as_keyboards();
    test_reports_the_device_open_error();
    puts("PASS: observer capabilities");
    return 0;
}
