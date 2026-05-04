/* wrapper.c — wraps upstream library for wasm export.
 *
 * Exports word_count as a wasm function. The upstream library also has
 * register_timeout() which uses signal() — see the Makefile for three
 * approaches to handle this incompatibility.
 */

#include <stdlib.h>
#include "upstream.h"

__attribute__((export_name("wasm_word_count")))
int wasm_word_count(const char* input_ptr, int input_len) {
    return word_count(input_ptr, input_len);
}
