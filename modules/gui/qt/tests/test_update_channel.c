/*****************************************************************************
 * test_update_channel.c: VLC Reborn update channel (src/misc/update*.c)
 *****************************************************************************
 * The updater of this fork trusts one key (include/vlc_pgpkey.h, generated from
 * docs/redesign/reborn-update-public.asc) and reads its status file from
 * REDESIGN_UPDATE_URL. This test uses the real verifier (src/misc/update_crypto.c is
 * included, as test/src/crypto/update.c does) and checks:
 *   - a DSA-2048 key and a "gpg --armor --detach-sign" signature of a status file
 *     made by extras/redesign/make-status.sh (SHA-256, and SHA-512 too) are accepted,
 *     through the same calls as GetUpdateFile() in update.c;
 *   - the same file with one byte changed (every byte in turn), a truncated file, a
 *     signature of another key, and a changed installer are rejected;
 *   - the embedded key is the fork's key (fingerprint recomputed from the key packet),
 *     not VideoLAN's, and the status URL is not a VideoLAN one;
 *     (the version compare is test_update_versions.c; the URLs and the absence of any
 *     VideoLAN host in the sources and in libvlccore: extras/redesign/check-update-urls.py).
 * The data are throwaway keys (update_channel_fixtures.h, made by
 * extras/redesign/gen-update-test-fixtures.sh); the fork's real private key cannot
 * sign in a test, that check is made on the first release candidate.
 *****************************************************************************/

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>

#include <vlc_common.h>
#include "misc/update_crypto.c"
#include <vlc_pgpkey.h>

#include "update_channel_fixtures.h"

const char vlc_module_name[] = "test_qt_update_channel";

static int failures;

#define CHECK(cond) do { \
    if (!(cond)) { \
        fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond); \
        failures++; \
    } \
} while (0)

/* What download_signature() does with the downloaded bytes (src/misc/update_crypto.c),
 * minus the download. 0 on success. */
static int parse_sig(signature_packet_t *sig, const uint8_t *armored)
{
    size_t size = strlen((const char *)armored);
    if (armored[0] >= 0x80)
        return -1;

    uint8_t *bin = malloc((size * 3) / 4 + 1);
    if (!bin)
        return -1;
    int bytes = pgp_unarmor((const char *)armored, size, bin, size);
    if (bytes < 2 || packet_type(bin[0]) != SIGNATURE_PACKET) {
        free(bin);
        return -1;
    }
    size_t header_len = packet_header_len(bin[0]);
    if ((header_len != 1 && header_len != 2 && header_len != 4) ||
        header_len + 1 > (size_t)bytes) {
        free(bin);
        return -1;
    }
    size_t len = scalar_number(bin + 1, header_len);
    if (len + header_len + 1 != (size_t)bytes) {
        free(bin);
        return -1;
    }
    int ret = parse_signature_packet(sig, bin + 1 + header_len, len);
    free(bin);
    if (ret != VLC_SUCCESS)
        return -1;
    if (sig->type != BINARY_SIGNATURE && sig->type != TEXT_SIGNATURE) {
        if (sig->version == 4) {
            free(sig->specific.v4.hashed_data);
            free(sig->specific.v4.unhashed_data);
        }
        return -1;
    }
    return 0;
}

static void free_sig(signature_packet_t *sig)
{
    if (sig->version == 4) {
        free(sig->specific.v4.hashed_data);
        free(sig->specific.v4.unhashed_data);
    }
}

static void free_key(public_key_t *key)
{
    if (key->sig.version == 4) {
        free(key->sig.specific.v4.hashed_data);
        free(key->sig.specific.v4.unhashed_data);
    }
    free(key->psz_username);
}

/* The authentication of GetUpdateFile() in src/misc/update.c, once the status text
 * and the armored signature are downloaded: the embedded key, the issuer, the hash
 * check bytes, the signature. true when the status file is accepted. */
static bool status_accepted(const uint8_t *key_armored, size_t key_size,
                            const uint8_t *key_longid, const char *status,
                            const uint8_t *sig_armored)
{
    signature_packet_t sign;
    if (parse_sig(&sign, sig_armored))
        return false;

    public_key_t key;
    if (parse_public_key(key_armored, key_size, &key, NULL) != VLC_SUCCESS) {
        free_sig(&sign);
        return false;
    }
    memcpy(key.longid, key_longid, 8);

    bool ok = false;
    /* another issuer: update.c refuses the file ("Status file signed by an unknown key");
     * the fork fetches no key from anywhere, VideoLAN's servers included */
    if (!memcmp(sign.issuer_longid, key.longid, 8)) {
        uint8_t *hash = hash_from_text(status, &sign);
        if (hash) {
            ok = hash[0] == sign.hash_verification[0] &&
                 hash[1] == sign.hash_verification[1] &&
                 verify_signature(&sign, &key.key, hash) == VLC_SUCCESS;
            free(hash);
        }
    }
    free_sig(&sign);
    free_key(&key);
    return ok;
}

/* the 20 bytes fingerprint (SHA-1 of the key packet) of a parsed v4 DSA key */
static void dsa_fingerprint(const public_key_t *key, uint8_t out[20])
{
    const public_key_packet_t *k = &key->key;
    size_t lp = mpi_len(k->sig.dsa.p), lq = mpi_len(k->sig.dsa.q),
           lg = mpi_len(k->sig.dsa.g), ly = mpi_len(k->sig.dsa.y);
    size_t size = 6 + 2 * 4 + lp + lq + lg + ly;

    gcry_md_hd_t hd;
    if (gcry_md_open(&hd, GCRY_MD_SHA1, 0)) {
        memset(out, 0, 20);
        return;
    }
    gcry_md_putc(hd, 0x99);
    gcry_md_putc(hd, (size >> 8) & 0xff);
    gcry_md_putc(hd, size & 0xff);
    gcry_md_putc(hd, k->version);
    gcry_md_write(hd, k->timestamp, 4);
    gcry_md_putc(hd, k->algo);
    gcry_md_write(hd, k->sig.dsa.p, 2 + lp);
    gcry_md_write(hd, k->sig.dsa.q, 2 + lq);
    gcry_md_write(hd, k->sig.dsa.g, 2 + lg);
    gcry_md_write(hd, k->sig.dsa.y, 2 + ly);
    memcpy(out, gcry_md_read(hd, GCRY_MD_SHA1), 20);
    gcry_md_close(hd);
}

static void test_status_file(void)
{
    const size_t klen = sizeof(fixture_key_a);
    const size_t len = strlen(fixture_status);

    /* the fixtures are what make-status.sh writes: update.c's own format */
    int ma = 0, mi = 0, rev = 0, extra = 0;
    CHECK(sscanf(fixture_status, "%i.%i.%i.%i", &ma, &mi, &rev, &extra) == 4);
    CHECK(ma == 4 && mi == 0 && rev == 0 && extra == 7);
    CHECK(strstr(fixture_status, "\nhttps://example.invalid/vlc-reborn-7.exe\n") != NULL);

    /* the gpg-signed file is accepted (SHA-256, the default of a DSA-2048 key) ... */
    CHECK(status_accepted(fixture_key_a, klen, fixture_key_a_longid,
                          fixture_status, fixture_status_sig_a));
    /* ... also when gpg was set to another digest */
    CHECK(status_accepted(fixture_key_a, klen, fixture_key_a_longid,
                          fixture_status, fixture_status_sig_a_sha512));

    signature_packet_t sig;
    CHECK(parse_sig(&sig, fixture_status_sig_a) == 0);
    CHECK(sig.version == 4 && sig.public_key_algo == GCRY_PK_DSA &&
          sig.digest_algo == GCRY_MD_SHA256 && sig.type == BINARY_SIGNATURE);
    CHECK(!memcmp(sig.issuer_longid, fixture_key_a_longid, 8));
    free_sig(&sig);
    CHECK(parse_sig(&sig, fixture_status_sig_a_sha512) == 0);
    CHECK(sig.digest_algo == GCRY_MD_SHA512);
    free_sig(&sig);

    /* one changed byte, wherever it is: rejected */
    char *copy = malloc(len + 1);
    CHECK(copy != NULL);
    if (!copy)
        return;
    for (size_t i = 0; i < len; i++) {
        memcpy(copy, fixture_status, len + 1);
        copy[i] ^= 0x01;
        if (!status_accepted(fixture_key_a, klen, fixture_key_a_longid, copy,
                             fixture_status_sig_a)) {
            continue;
        }
        fprintf(stderr, "FAIL: a status file with byte %zu changed was accepted\n", i);
        failures++;
    }
    /* the last character replaced / the file cut / text appended */
    memcpy(copy, fixture_status, len + 1);
    copy[len - 2] = copy[len - 2] == 'x' ? 'y' : 'x';
    CHECK(!status_accepted(fixture_key_a, klen, fixture_key_a_longid, copy,
                           fixture_status_sig_a));
    memcpy(copy, fixture_status, len + 1);
    copy[len - 1] = '\0';
    CHECK(!status_accepted(fixture_key_a, klen, fixture_key_a_longid, copy,
                           fixture_status_sig_a));
    free(copy);

    /* a signature made by another key never passes, under the key of A */
    CHECK(!status_accepted(fixture_key_a, klen, fixture_key_a_longid,
                           fixture_status, fixture_status_sig_b));
    CHECK(parse_sig(&sig, fixture_status_sig_b) == 0);
    CHECK(memcmp(sig.issuer_longid, fixture_key_a_longid, 8) != 0);
    CHECK(!memcmp(sig.issuer_longid, fixture_key_b_longid, 8));
    {
        /* even with the issuer check out of the way, the maths must fail */
        public_key_t key;
        CHECK(parse_public_key(fixture_key_a, klen, &key, NULL) == VLC_SUCCESS);
        uint8_t *hash = hash_from_text(fixture_status, &sig);
        CHECK(hash != NULL);
        if (hash) {
            CHECK(verify_signature(&sig, &key.key, hash) != VLC_SUCCESS);
            free(hash);
        }
        free_key(&key);
    }
    free_sig(&sig);

    /* the signature itself changed (one armored character): the armor CRC or the
     * maths refuse it */
    uint8_t *badsig = (uint8_t *)strdup((const char *)fixture_status_sig_a);
    CHECK(badsig != NULL);
    if (badsig) {
        char *body = strstr((char *)badsig, "\n\n");
        CHECK(body != NULL);
        if (body) {
            body[4] = body[4] == 'A' ? 'B' : 'A';
            CHECK(!status_accepted(fixture_key_a, klen, fixture_key_a_longid,
                                   fixture_status, badsig));
        }
        free(badsig);
    }
}

static void test_installer(void)
{
    /* update.c hashes the downloaded installer file (hash_from_file) and verifies
     * its <installer>.asc with the same key */
    const char *tmp = getenv("TMPDIR");
    char dir[512];
    snprintf(dir, sizeof(dir), "%s/update_channel_XXXXXX", tmp && *tmp ? tmp : "/tmp");
    if (mkdtemp(dir) == NULL) {          /* a private directory, removed below */
        fprintf(stderr, "FAIL: cannot create a temporary directory\n");
        failures++;
        return;
    }
    char path[sizeof(dir) + 16];
    snprintf(path, sizeof(path), "%s/installer.exe", dir);
    int fd = open(path, O_WRONLY | O_CREAT | O_EXCL, 0600);
    CHECK(fd >= 0);
    if (fd < 0) {
        rmdir(dir);
        return;
    }
    size_t len = strlen(fixture_installer);
    CHECK(write(fd, fixture_installer, len) == (ssize_t)len);
    close(fd);

    signature_packet_t sig;
    CHECK(parse_sig(&sig, fixture_installer_sig_a) == 0);
    CHECK(sig.type == BINARY_SIGNATURE);                    /* update.c requires it */
    CHECK(!memcmp(sig.issuer_longid, fixture_key_a_longid, 8));

    public_key_t key;
    CHECK(parse_public_key(fixture_key_a, sizeof(fixture_key_a), &key, NULL) == VLC_SUCCESS);

    uint8_t *hash = hash_from_file(path, &sig);
    CHECK(hash != NULL);
    if (hash) {
        CHECK(hash[0] == sig.hash_verification[0] && hash[1] == sig.hash_verification[1]);
        CHECK(verify_signature(&sig, &key.key, hash) == VLC_SUCCESS);
        free(hash);
    }

    /* one byte of the installer changed */
    FILE *f = fopen(path, "r+b");
    CHECK(f != NULL);
    if (f) {
        fseek(f, 100, SEEK_SET);
        int c = fgetc(f);
        fseek(f, 100, SEEK_SET);
        fputc(c ^ 0x01, f);
        fclose(f);
        hash = hash_from_file(path, &sig);
        CHECK(hash != NULL);
        if (hash) {
            CHECK(verify_signature(&sig, &key.key, hash) != VLC_SUCCESS);
            free(hash);
        }
    }
    free_key(&key);
    free_sig(&sig);
    unlink(path);
    rmdir(dir);
}

static void test_embedded_key(void)
{
    /* the key the updater trusts (include/vlc_pgpkey.h) is parsed by the verifier */
    public_key_t key;
    CHECK(parse_public_key(videolan_public_key, sizeof(videolan_public_key), &key, NULL)
          == VLC_SUCCESS);
    CHECK(key.key.version == 4);
    CHECK(key.key.algo == GCRY_PK_DSA);
    CHECK(scalar_number(key.key.sig.dsa.p, 2) == 2048);
    CHECK(scalar_number(key.key.sig.dsa.q, 2) == 256);
    CHECK(key.psz_username != NULL &&
          strstr((const char *)key.psz_username, "VLC Reborn Updates") != NULL);

    /* the long id of the header is the tail of the fingerprint of that very key,
     * and it is the key of docs/redesign/reborn-update-public.asc, not VideoLAN's */
    static const uint8_t fingerprint[20] = {
        0xDE, 0xCB, 0x23, 0x70, 0x8C, 0xF9, 0x87, 0x7F, 0x07, 0xD8,
        0x15, 0x3F, 0xEF, 0xD2, 0xA5, 0xC7, 0xEB, 0xD6, 0x2B, 0xCD
    };
    static const uint8_t videolan_release_key_2026[8] = {
        0x1D, 0x77, 0xC0, 0xAE, 0x83, 0x5B, 0x91, 0x1E
    };
    uint8_t fpr[20];
    dsa_fingerprint(&key, fpr);
    CHECK(!memcmp(fpr, fingerprint, 20));
    CHECK(!memcmp(videolan_public_key_longid, fpr + 12, 8));
    CHECK(memcmp(videolan_public_key_longid, videolan_release_key_2026, 8) != 0);
    free_key(&key);

    /* VideoLAN's keys are not embedded: its key never authenticates our feed */
    CHECK(strstr((const char *)videolan_public_key, "videolan.org") == NULL);

    /* the stock update servers are not used */
    const char *url = REDESIGN_UPDATE_URL;
    CHECK(strncmp(url, "https://", 8) == 0);
    CHECK(strstr(url, "videolan") == NULL);
    size_t ul = strlen(url);
    CHECK(ul > 7 && !strcmp(url + ul - 7, "/status"));       /* update.c appends -win-x64 */
}

int main(void)
{
    gcry_check_version(NULL);
    gcry_control(GCRYCTL_INITIALIZATION_FINISHED, 0);

    test_status_file();
    test_installer();
    test_embedded_key();

    if (failures) {
        fprintf(stderr, "%d check(s) failed\n", failures);
        return 1;
    }
    fprintf(stderr, "update channel: all checks passed\n");
    return 0;
}
