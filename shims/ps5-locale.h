/* PS5 sysroot locale shim.
 *
 * The SDK's libc.a defines strtof_l and strtod_l (in no-locale.o) but the C
 * headers never declare them - only the libc++ headers do. A core that calls
 * them from C therefore hits "call to undeclared function", and letting it
 * through as an implicit declaration is not safe: that assumes an int return
 * and would silently corrupt every float it parses.
 *
 * Force-include this (-include ps5-locale.h) alongside -DHAVE_STRTOF_L so the
 * core uses the libc implementation with the correct prototype instead of
 * defining its own, which would collide with no-locale.o at link time.
 */
#ifndef PS5_LOCALE_SHIM_H
#define PS5_LOCALE_SHIM_H

#ifndef __cplusplus

#include <locale.h>
#include <xlocale.h>

float strtof_l(const char *, char **, locale_t);
double strtod_l(const char *, char **, locale_t);

#endif /* !__cplusplus */

#endif /* PS5_LOCALE_SHIM_H */
