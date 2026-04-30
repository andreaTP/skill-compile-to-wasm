/*
 * Wrapper for cJSON library — local toolchain variant.
 * Same wrapping pattern as c-docker/wrapper.c but built with local WASI SDK.
 *
 * See c-docker/wrapper.c for detailed comments on the wrapping pattern.
 */

#include <stdlib.h>
#include <string.h>
#include "cJSON.h"

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
