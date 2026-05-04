/* upstream.h — simulates an upstream library with platform-specific code.
 *
 * This header demonstrates a common pattern: a library that works fine on
 * native platforms but fails to compile to wasm because it uses signal().
 *
 * The library provides two features:
 *   1. word_count() — pure computation, works everywhere
 *   2. register_timeout() — uses signal(), breaks on WASI
 */

#ifndef UPSTREAM_H
#define UPSTREAM_H

#include <string.h>

#ifndef UPSTREAM_NO_SIGNALS
#include <signal.h>
#endif

static int word_count(const char* text, int len) {
    int count = 0;
    int in_word = 0;
    for (int i = 0; i < len; i++) {
        if (text[i] == ' ' || text[i] == '\n' || text[i] == '\t') {
            in_word = 0;
        } else if (!in_word) {
            in_word = 1;
            count++;
        }
    }
    return count;
}

#ifndef UPSTREAM_NO_SIGNALS
static void timeout_handler(int sig) {
    (void)sig;
}

static void register_timeout(int seconds) {
    signal(SIGALRM, timeout_handler);
    (void)seconds;
}
#endif

#endif
