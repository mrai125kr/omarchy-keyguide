#define _GNU_SOURCE

#include "modifier_state.h"
#include "input_codes.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/epoll.h>
#include <sys/ioctl.h>
#include <unistd.h>

#define MAX_DEVICES MODIFIER_STATE_MAX_DEVICES
#define MAX_EVENTS MAX_DEVICES
#define EVENT_BITS_SIZE ((EV_MAX / 8) + 1)
#define KEY_BITS_SIZE ((KEY_MAX / 8) + 1)
#define REL_BITS_SIZE ((REL_MAX / 8) + 1)

struct observed_device {
    int fd;
    bool awaiting_sync;
    bool has_key_events;
};

static bool bit_is_set(const unsigned char *bits, unsigned int bit)
{
    return (bits[bit / 8] & (unsigned char)(1U << (bit % 8))) != 0;
}

static bool is_event_device_name(const char *name)
{
    const char *character;

    if (strncmp(name, "event", 5) != 0 || name[5] == '\0') {
        return false;
    }
    for (character = name + 5; *character != '\0'; ++character) {
        if (*character < '0' || *character > '9') {
            return false;
        }
    }
    return true;
}

static bool has_key_in_range(const unsigned char *key_bits,
                             unsigned int first, unsigned int last)
{
    unsigned int code;

    for (code = first; code <= last; ++code) {
        if (bit_is_set(key_bits, code)) {
            return true;
        }
    }
    return false;
}

static bool has_keyboard_key(const unsigned char *key_bits)
{
    unsigned int code;

    for (code = 0; code <= KEY_MAX; ++code) {
        if (input_code_is_keyboard_action(code) &&
            bit_is_set(key_bits, code)) {
            return true;
        }
    }
    return false;
}

static bool has_wheel_axis(const unsigned char *relative_bits)
{
    return bit_is_set(relative_bits, REL_WHEEL) ||
           bit_is_set(relative_bits, REL_HWHEEL) ||
           bit_is_set(relative_bits, REL_WHEEL_HI_RES) ||
           bit_is_set(relative_bits, REL_HWHEEL_HI_RES);
}

static bool is_wheel_code(unsigned int code)
{
    return code == REL_WHEEL || code == REL_HWHEEL ||
           code == REL_WHEEL_HI_RES || code == REL_HWHEEL_HI_RES;
}

static bool is_observed_input(int fd, bool *has_key_events)
{
    unsigned char event_bits[EVENT_BITS_SIZE] = {0};
    unsigned char key_bits[KEY_BITS_SIZE] = {0};
    unsigned char relative_bits[REL_BITS_SIZE] = {0};
    bool keyboard = false;
    bool pointer_buttons = false;
    bool wheel = false;

    if (ioctl(fd, EVIOCGBIT(0, sizeof event_bits), event_bits) < 0) {
        return false;
    }

    *has_key_events = bit_is_set(event_bits, EV_KEY);
    if (*has_key_events) {
        if (ioctl(fd, EVIOCGBIT(EV_KEY, sizeof key_bits), key_bits) < 0) {
            return false;
        }
        keyboard = has_keyboard_key(key_bits);
        pointer_buttons = has_key_in_range(key_bits, BTN_LEFT, BTN_TASK);
    }

    if (bit_is_set(event_bits, EV_REL)) {
        if (ioctl(fd, EVIOCGBIT(EV_REL, sizeof relative_bits),
                  relative_bits) < 0) {
            return false;
        }
        wheel = has_wheel_axis(relative_bits);
    }

    return keyboard || pointer_buttons || wheel;
}

static void emit_error(const char *error, int error_number)
{
    fprintf(stderr, "{\"error\":\"%s\",\"errno\":%d}\n", error,
            error_number);
}

static bool emit_json(const struct modifier_state *state)
{
    char json[128];

    if (!modifier_state_json(state, json, sizeof json)) {
        emit_error("state_serialization_failed", 0);
        return false;
    }
    if (printf("%s\n", json) < 0 || fflush(stdout) == EOF) {
        emit_error("state_output_failed", errno);
        return false;
    }
    return true;
}

static bool read_pressed_keys(int fd, bool has_key_events,
                              unsigned int *pressed_codes,
                              size_t *pressed_count)
{
    unsigned char key_state[KEY_BITS_SIZE] = {0};
    unsigned int code;

    *pressed_count = 0;
    if (!has_key_events) {
        return true;
    }

    if (ioctl(fd, EVIOCGKEY(sizeof key_state), key_state) < 0) {
        return false;
    }

    for (code = 0; code <= KEY_MAX; ++code) {
        if (bit_is_set(key_state, code)) {
            pressed_codes[*pressed_count] = code;
            ++*pressed_count;
        }
    }
    return true;
}

static int discover_keyboards(int epoll_fd,
                              struct observed_device devices[MAX_DEVICES],
                              struct modifier_state *state)
{
    DIR *input_directory;
    struct dirent *entry;
    int count = 0;

    input_directory = opendir("/dev/input");
    if (input_directory == NULL) {
        return 0;
    }

    while (count < MAX_DEVICES && (entry = readdir(input_directory)) != NULL) {
        char path[sizeof "/dev/input/" + sizeof entry->d_name];
        struct epoll_event registration = {0};
        unsigned int pressed_codes[KEY_CNT];
        size_t pressed_count;
        bool has_key_events;
        int fd;

        if (!is_event_device_name(entry->d_name)) {
            continue;
        }
        if (snprintf(path, sizeof path, "/dev/input/%s", entry->d_name) < 0) {
            continue;
        }

        fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
        if (fd < 0) {
            continue;
        }
        if (!is_observed_input(fd, &has_key_events)) {
            close(fd);
            continue;
        }
        if (!read_pressed_keys(fd, has_key_events, pressed_codes,
                               &pressed_count)) {
            close(fd);
            continue;
        }

        registration.events = EPOLLIN | EPOLLERR | EPOLLHUP;
        registration.data.u32 = (unsigned int)count;
        if (epoll_ctl(epoll_fd, EPOLL_CTL_ADD, fd, &registration) < 0) {
            close(fd);
            continue;
        }
        devices[count].fd = fd;
        devices[count].awaiting_sync = false;
        devices[count].has_key_events = has_key_events;
        if (modifier_state_sync_device(state, fd, pressed_codes,
                                       pressed_count) &&
            !emit_json(state)) {
            closedir(input_directory);
            return -1;
        }
        ++count;
    }

    closedir(input_directory);
    return count;
}

static bool remove_device(int epoll_fd, struct observed_device *device,
                          struct modifier_state *state, int *active_devices)
{
    int fd = device->fd;

    if (fd < 0) {
        return true;
    }
    epoll_ctl(epoll_fd, EPOLL_CTL_DEL, fd, NULL);
    close(fd);
    device->fd = -1;
    --*active_devices;
    if (modifier_state_remove_device(state, fd)) {
        return emit_json(state);
    }
    return true;
}

int main(void)
{
    struct observed_device devices[MAX_DEVICES];
    struct modifier_state state = {0};
    struct epoll_event events[MAX_EVENTS];
    int epoll_fd;
    int active_devices;
    size_t index;
    struct sigaction ignored_signal = {0};

    ignored_signal.sa_handler = SIG_IGN;
    sigemptyset(&ignored_signal.sa_mask);
    if (sigaction(SIGPIPE, &ignored_signal, NULL) < 0) {
        emit_error("sigpipe_setup_failed", errno);
        return EXIT_FAILURE;
    }

    for (index = 0; index < MAX_DEVICES; ++index) {
        devices[index].fd = -1;
        devices[index].awaiting_sync = false;
        devices[index].has_key_events = false;
    }

    epoll_fd = epoll_create1(EPOLL_CLOEXEC);
    if (epoll_fd < 0) {
        emit_error("epoll_create_failed", errno);
        return EXIT_FAILURE;
    }

    active_devices = discover_keyboards(epoll_fd, devices, &state);
    if (active_devices < 0) {
        close(epoll_fd);
        return EXIT_FAILURE;
    }
    if (active_devices == 0) {
        emit_error("no_readable_keyboard", 0);
        close(epoll_fd);
        return EXIT_FAILURE;
    }

    while (active_devices > 0) {
        int ready = epoll_wait(epoll_fd, events, MAX_EVENTS, -1);
        int event_index;

        if (ready < 0) {
            if (errno == EINTR) {
                continue;
            }
            emit_error("epoll_wait_failed", errno);
            close(epoll_fd);
            return EXIT_FAILURE;
        }

        for (event_index = 0; event_index < ready; ++event_index) {
            unsigned int device_index = events[event_index].data.u32;
            struct observed_device *device;
            bool disconnected = false;

            if (device_index >= MAX_DEVICES) {
                continue;
            }
            device = &devices[device_index];
            if (device->fd < 0) {
                continue;
            }

            for (;;) {
                struct input_event input_event;
                ssize_t bytes_read = read(device->fd, &input_event,
                                          sizeof input_event);

                if (bytes_read == (ssize_t)sizeof input_event) {
                    if (device->awaiting_sync) {
                        if (input_event.type == EV_SYN &&
                            input_event.code == SYN_REPORT) {
                            unsigned int pressed_codes[KEY_CNT];
                            size_t pressed_count;

                            if (!read_pressed_keys(device->fd,
                                                   device->has_key_events,
                                                   pressed_codes,
                                                   &pressed_count)) {
                                disconnected = true;
                                break;
                            }
                            device->awaiting_sync = false;
                            if (modifier_state_sync_device(
                                    &state, device->fd, pressed_codes,
                                    pressed_count) &&
                                !emit_json(&state)) {
                                close(epoll_fd);
                                return EXIT_FAILURE;
                            }
                        }
                        continue;
                    }
                    if (input_event.type == EV_SYN &&
                        input_event.code == SYN_DROPPED) {
                        device->awaiting_sync = true;
                        continue;
                    }
                    if (input_event.type == EV_KEY &&
                        modifier_state_apply(&state, device->fd,
                                             input_event.code,
                                             input_event.value) &&
                        !emit_json(&state)) {
                        close(epoll_fd);
                        return EXIT_FAILURE;
                    }
                    if (input_event.type == EV_REL &&
                        is_wheel_code(input_event.code) &&
                        modifier_state_apply_wheel(&state,
                                                   input_event.value) &&
                        !emit_json(&state)) {
                        close(epoll_fd);
                        return EXIT_FAILURE;
                    }
                    continue;
                }
                if (bytes_read < 0 && errno == EINTR) {
                    continue;
                }
                if (bytes_read < 0 &&
                    (errno == EAGAIN || errno == EWOULDBLOCK)) {
                    break;
                }
                disconnected = true;
                break;
            }

            if (disconnected ||
                (events[event_index].events & (EPOLLERR | EPOLLHUP)) != 0) {
                if (!remove_device(epoll_fd, device, &state,
                                   &active_devices)) {
                    close(epoll_fd);
                    return EXIT_FAILURE;
                }
            }
        }
    }

    emit_error("no_readable_keyboard", 0);
    close(epoll_fd);
    return EXIT_FAILURE;
}
