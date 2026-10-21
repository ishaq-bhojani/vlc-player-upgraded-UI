/*****************************************************************************
 * test_update_versions.c: version compare of the VLC Reborn updater
 *****************************************************************************
 * src/misc/update.c is compiled into this test (not taken from libvlccore, where
 * the default build has stubs because "update-check" is off), with the build
 * configuration chosen by the meson entry instead of config.h:
 *   TEST_BUILD_NUMBER   redesign_build_number N of the build (version 4.0.0.N)
 *   TEST_VERSION_DEV    PACKAGE_VERSION_DEV: "dev" for the development build (N = 0),
 *                       "" for a numbered release (N > 0), see meson.build
 * (update_crypto.c is linked as a second source) so the default linux-tests.sh gate checks update_NeedUpgrade() for a numbered
 * release and for a development build. test_update_channel.c covers the crypto.
 *****************************************************************************/

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <stdio.h>
#include <string.h>

/* the build under test: update.c must not read config.h again */
#undef HAVE_CONFIG_H
#undef REDESIGN_BUILD_NUMBER
#define REDESIGN_BUILD_NUMBER TEST_BUILD_NUMBER
#undef PACKAGE_VERSION_DEV
#define PACKAGE_VERSION_DEV TEST_VERSION_DEV

#include <vlc_common.h>
#include "misc/update.c"

const char vlc_module_name[] = "test_qt_update_versions";

/* libvlccore does not export this core function; only update_Download() uses it, never called here */
#undef vlc_custom_create
void *vlc_custom_create(vlc_object_t *parent, size_t size, const char *type)
{
    (void) parent; (void) size; (void) type;
    return NULL;
}

static int failures;

#define CHECK(cond) do { \
    if (!(cond)) { \
        fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond); \
        failures++; \
    } \
} while (0)

static bool need_upgrade(int major, int minor, int revision, int extra)
{
    update_t update;
    memset(&update, 0, sizeof(update));
    update.release.i_major = major;
    update.release.i_minor = minor;
    update.release.i_revision = revision;
    update.release.i_extra = extra;
    return update_NeedUpgrade(&update);
}

/* the first line of a status file, parsed as GetUpdateFile() does */
static bool offered_by_status_line(const char *line)
{
    int ma = 0, mi = 0, rev = 0, extra = 0;
    int ret = sscanf(line, "%i.%i.%i.%i", &ma, &mi, &rev, &extra);
    CHECK(ret == 4);
    return need_upgrade(ma, mi, rev, extra);
}

int main(void)
{
    /* this build is 4.0.0.N */
    const int n = PACKAGE_VERSION_EXTRA + REDESIGN_BUILD_NUMBER;
    CHECK(n == TEST_BUILD_NUMBER);
    CHECK(PACKAGE_VERSION_MAJOR == 4 && PACKAGE_VERSION_MINOR == 0 &&
          PACKAGE_VERSION_REVISION == 0);

    CHECK(need_upgrade(4, 0, 0, n + 1));                 /* the next release is offered */
    CHECK(need_upgrade(4, 0, 0, n + 100));
    CHECK(need_upgrade(4, 0, 1, 0));
    CHECK(need_upgrade(5, 0, 0, 0));
    CHECK(!need_upgrade(3, 9, 9, 99));                   /* never an older one */

    char line[32];
    snprintf(line, sizeof(line), "4.0.0.%d", n + 1);
    CHECK(offered_by_status_line(line));

    if (n > 0) {
        /* a numbered release is not a "-dev" build: the installed version is current */
        CHECK(*PACKAGE_VERSION_DEV == '\0');
        CHECK(!need_upgrade(4, 0, 0, n));
        CHECK(!need_upgrade(4, 0, 0, n - 1));
        snprintf(line, sizeof(line), "4.0.0.%d", n);
        CHECK(!offered_by_status_line(line));
        snprintf(line, sizeof(line), "4.0.0.%d", n - 1);
        CHECK(!offered_by_status_line(line));
    } else {
        /* a development build offers the same version again, as upstream */
        CHECK(*PACKAGE_VERSION_DEV != '\0');
        CHECK(need_upgrade(4, 0, 0, 0));
    }

    if (failures) {
        fprintf(stderr, "%d check(s) failed\n", failures);
        return 1;
    }
    fprintf(stderr, "update versions (N=%d): all checks passed\n", n);
    return 0;
}
