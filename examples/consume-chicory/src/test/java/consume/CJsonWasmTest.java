package consume;

import static org.junit.jupiter.api.Assertions.*;

import java.nio.file.Path;
import java.util.stream.Stream;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

/**
 * Integration test demonstrating the full roundtrip: Java -> wasm export -> result.
 *
 * <p>Runs every test in both INTERPRETER and COMPILER modes to verify both backends work
 * identically with the same wasm module.
 *
 * <p>Requires the cJSON .wasm module to be built first: make -C ../c-local release
 */
class CJsonWasmTest {

    static final Path WASM_PATH =
            Path.of(System.getProperty("cjson.wasm.path", "../c-local/wasm/cjson.wasm"));

    @BeforeAll
    static void checkWasmExists() {
        assertTrue(WASM_PATH.toFile().exists(), "cjson.wasm not found at " + WASM_PATH
                + " — run 'make -C ../c-local release' first");
    }

    private CJsonWasm create(CJsonWasm.Mode mode) {
        return new CJsonWasm(WASM_PATH, mode);
    }

    @ParameterizedTest(name = "prettyPrint [{0}]")
    @EnumSource(CJsonWasm.Mode.class)
    void prettyPrintSimpleObject(CJsonWasm.Mode mode) {
        try (var cjson = create(mode)) {
            String result = cjson.prettyPrint("{\"name\":\"Alice\",\"age\":30}");
            assertNotNull(result);
            assertTrue(result.contains("\"name\""));
            assertTrue(result.contains("Alice"));
            assertTrue(result.contains("\"age\""));
            assertTrue(result.contains("\n"), "pretty-printed output should have newlines");
        }
    }

    @ParameterizedTest(name = "prettyPrintArray [{0}]")
    @EnumSource(CJsonWasm.Mode.class)
    void prettyPrintArray(CJsonWasm.Mode mode) {
        try (var cjson = create(mode)) {
            String result = cjson.prettyPrint("[1,2,3]");
            assertNotNull(result);
            assertTrue(result.contains("1"));
            assertTrue(result.contains("2"));
            assertTrue(result.contains("3"));
        }
    }

    @ParameterizedTest(name = "prettyPrintInvalid [{0}]")
    @EnumSource(CJsonWasm.Mode.class)
    void prettyPrintInvalidJsonReturnsNull(CJsonWasm.Mode mode) {
        try (var cjson = create(mode)) {
            assertNull(cjson.prettyPrint("not valid json"));
        }
    }

    @ParameterizedTest(name = "validateValid [{0}]")
    @EnumSource(CJsonWasm.Mode.class)
    void validateValidJson(CJsonWasm.Mode mode) {
        try (var cjson = create(mode)) {
            assertTrue(cjson.isValid("{\"key\":\"value\"}"));
            assertTrue(cjson.isValid("[1,2,3]"));
            assertTrue(cjson.isValid("\"hello\""));
            assertTrue(cjson.isValid("42"));
            assertTrue(cjson.isValid("null"));
        }
    }

    @ParameterizedTest(name = "validateInvalid [{0}]")
    @EnumSource(CJsonWasm.Mode.class)
    void validateInvalidJson(CJsonWasm.Mode mode) {
        try (var cjson = create(mode)) {
            assertFalse(cjson.isValid("not json"));
            assertFalse(cjson.isValid("{missing quotes}"));
        }
    }

    @ParameterizedTest(name = "minify [{0}]")
    @EnumSource(CJsonWasm.Mode.class)
    void minifyRemovesWhitespace(CJsonWasm.Mode mode) {
        try (var cjson = create(mode)) {
            String result = cjson.minify("{ \"name\" : \"Alice\" , \"age\" : 30 }");
            assertNotNull(result);
            assertTrue(result.contains("\"name\""));
            assertTrue(result.contains("\"Alice\""));
        }
    }

    @ParameterizedTest(name = "minifyInvalid [{0}]")
    @EnumSource(CJsonWasm.Mode.class)
    void minifyInvalidJsonReturnsNull(CJsonWasm.Mode mode) {
        try (var cjson = create(mode)) {
            assertNull(cjson.minify("bad json"));
        }
    }

    @ParameterizedTest(name = "roundtrip [{0}]")
    @EnumSource(CJsonWasm.Mode.class)
    void roundtripMinifyThenPrettyPrint(CJsonWasm.Mode mode) {
        try (var cjson = create(mode)) {
            String original = "{\"a\":1,\"b\":[2,3]}";
            String minified = cjson.minify(original);
            assertNotNull(minified);
            String pretty = cjson.prettyPrint(minified);
            assertNotNull(pretty);
            assertTrue(pretty.contains("\"a\""));
            assertTrue(pretty.contains("\"b\""));
        }
    }
}
