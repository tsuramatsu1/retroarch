#!/usr/bin/env python3
"""Forward DualSense touchpad coordinates to SDL's mouse state.

RetroArch derives RETRO_DEVICE_POINTER from SDL_GetMouseState(), and its SDL
input driver reads neither SDL touch events nor SDL_CONTROLLERTOUCHPAD events.
So the touchpad has to arrive as absolute mouse motion to be usable as a pointer.
"""
import sys

PATH = sys.argv[1]
src = open(PATH).read()

INCLUDES_ANCHOR = '#include "SDL_ps5joystick.h"'
INCLUDES_ADD = '''#include "SDL_ps5joystick.h"
#include "SDL_mouse.h"
#include "SDL_video.h"
#include "../../events/SDL_mouse_c.h"'''

HELPER_ANCHOR = 'static void PS5_JoystickUpdate(SDL_Joystick *joystick)'
HELPER = '''/* Report the touchpad as absolute mouse motion.

   RetroArch's SDL input driver builds RETRO_DEVICE_POINTER out of
   SDL_GetMouseState(); it does not look at SDL touch events or at
   SDL_CONTROLLERTOUCHPAD events, so mouse motion is the only route that
   reaches a libretro core as a pointer.

   The touchpad coordinate range is not reported by the pad, so it is assumed
   to be 1920x1080 and can be corrected at runtime with PS5_TOUCHPAD_MAX_X and
   PS5_TOUCHPAD_MAX_Y if the pointer does not span the whole screen.

   By default a finger on the pad presses the left button, which mimics a
   touchscreen. Set PS5_TOUCHPAD_CLICK_PRESS=1 to take the press from the
   physical touchpad click instead, which allows aiming before committing. */
static void PS5_TouchpadToMouse(const PS5_PadData *prev, const PS5_PadData *cur)
{
    static int max_x = 0;
    static int max_y = 0;
    static int click_press = -1;
    SDL_Window *window;
    int w = 0;
    int h = 0;
    SDL_bool was_down;
    SDL_bool is_down;

    if (max_x == 0) {
        const char *env;
        max_x = (env = SDL_getenv("PS5_TOUCHPAD_MAX_X")) ? SDL_atoi(env) : 1920;
        max_y = (env = SDL_getenv("PS5_TOUCHPAD_MAX_Y")) ? SDL_atoi(env) : 1080;
        if (max_x <= 0) {
            max_x = 1920;
        }
        if (max_y <= 0) {
            max_y = 1080;
        }
        env = SDL_getenv("PS5_TOUCHPAD_CLICK_PRESS");
        click_press = (env && SDL_atoi(env)) ? 1 : 0;
    }

    window = SDL_GetMouseFocus();
    if (!window) {
        window = SDL_GetKeyboardFocus();
    }
    if (!window) {
        return;
    }
    SDL_GetWindowSize(window, &w, &h);
    if (w <= 0 || h <= 0) {
        return;
    }

    /* Position tracks finger 0 whenever the pad is being touched. */
    if (cur->touch.fingers > 0) {
        int moved = (prev->touch.fingers == 0) ||
                    (prev->touch.touch[0].x != cur->touch.touch[0].x) ||
                    (prev->touch.touch[0].y != cur->touch.touch[0].y);
        if (moved) {
            int x = (int)(((Sint64)cur->touch.touch[0].x * w) / max_x);
            int y = (int)(((Sint64)cur->touch.touch[0].y * h) / max_y);
            if (x < 0) {
                x = 0;
            } else if (x > w - 1) {
                x = w - 1;
            }
            if (y < 0) {
                y = 0;
            } else if (y > h - 1) {
                y = h - 1;
            }
            SDL_SendMouseMotion(window, 0, 0, x, y);
        }
    }

    if (click_press) {
        was_down = (prev->buttons & PS5_PAD_BUTTON_TOUCH_PAD) ? SDL_TRUE : SDL_FALSE;
        is_down = (cur->buttons & PS5_PAD_BUTTON_TOUCH_PAD) ? SDL_TRUE : SDL_FALSE;
    } else {
        was_down = (prev->touch.fingers > 0) ? SDL_TRUE : SDL_FALSE;
        is_down = (cur->touch.fingers > 0) ? SDL_TRUE : SDL_FALSE;
    }

    /* Motion above is emitted before this, so the press lands on the right spot. */
    if (is_down != was_down) {
        SDL_SendMouseButton(window, 0, is_down ? SDL_PRESSED : SDL_RELEASED,
                            SDL_BUTTON_LEFT);
    }
}

''' + HELPER_ANCHOR

CALL_ANCHOR = '    memcpy(&ctx->pad, &pad, sizeof(pad));'
CALL_ADD = '''    PS5_TouchpadToMouse(&ctx->pad, &pad);

    memcpy(&ctx->pad, &pad, sizeof(pad));'''

edits = [
    ("includes", INCLUDES_ANCHOR, INCLUDES_ADD),
    ("helper", HELPER_ANCHOR, HELPER),
    ("call site", CALL_ANCHOR, CALL_ADD),
]

for name, anchor, replacement in edits:
    if src.count(anchor) != 1:
        print("FAIL: anchor for %s found %d times (expected 1)" % (name, src.count(anchor)))
        sys.exit(1)
    src = src.replace(anchor, replacement, 1)
    print("  applied: %s" % name)

open(PATH, "w").write(src)

# verify
final = open(PATH).read()
for needle in ["PS5_TouchpadToMouse(&ctx->pad, &pad);",
               "static void PS5_TouchpadToMouse",
               "SDL_SendMouseMotion(window, 0, 0, x, y);",
               "SDL_mouse_c.h"]:
    if needle not in final:
        print("FAIL: verification missed %r" % needle)
        sys.exit(1)
print("  all edits verified")
