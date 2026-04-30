/*
 * Wrapper for cJSON library — demonstrates the library wrapping pattern.
 *
 * This file shows how to wrap an existing C library for use as a wasm module:
 *   1. Export malloc/free so the host can allocate/read linear memory
 *   2. Write thin wrapper functions that accept pointer+length pairs
 *   3. Use callee-allocates convention: wrapper allocates result, host reads and frees
 */

#include <stdlib.h>
#include <string.h>
#include "cJSON.h"

/*
 * Parse a JSON string and return a pretty-printed version.
 *
 * Host calls:
 *   1. ptr = malloc(len)
 *   2. Write JSON bytes into memory at ptr
 *   3. result_ptr = parse_and_pretty_print(ptr, len)
 *   4. Read result string from result_ptr (null-terminated)
 *   5. free(ptr); free(result_ptr)
 *
 * Returns 0 (NULL) on parse error.
 */
__attribute__((export_name("parse_and_pretty_print")))
char* parse_and_pretty_print(const char* json_ptr, int json_len) {
    char* input = (char*)malloc(json_len + 1);
    if (!input) return NULL;
    memcpy(input, json_ptr, json_len);
    input[json_len] = '\0';

    cJSON* parsed = cJSON_Parse(input);
    free(input);
    if (!parsed) return NULL;

    char* result = cJSON_Print(parsed);
    cJSON_Delete(parsed);
    return result;
}

/*
 * Validate whether a string is valid JSON.
 * Returns 1 if valid, 0 if invalid.
 */
__attribute__((export_name("validate_json")))
int validate_json(const char* json_ptr, int json_len) {
    char* input = (char*)malloc(json_len + 1);
    if (!input) return 0;
    memcpy(input, json_ptr, json_len);
    input[json_len] = '\0';

    cJSON* parsed = cJSON_Parse(input);
    free(input);
    if (!parsed) return 0;

    cJSON_Delete(parsed);
    return 1;
}

/*
 * Minify a JSON string (remove whitespace).
 * Returns pointer to minified string, or 0 (NULL) on error.
 */
__attribute__((export_name("minify_json")))
char* minify_json(const char* json_ptr, int json_len) {
    char* input = (char*)malloc(json_len + 1);
    if (!input) return NULL;
    memcpy(input, json_ptr, json_len);
    input[json_len] = '\0';

    cJSON* parsed = cJSON_Parse(input);
    free(input);
    if (!parsed) return NULL;

    char* result = cJSON_PrintUnformatted(parsed);
    cJSON_Delete(parsed);
    return result;
}
