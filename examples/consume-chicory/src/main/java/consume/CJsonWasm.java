package consume;

import com.dylibso.chicory.compiler.MachineFactoryCompiler;
import com.dylibso.chicory.runtime.ExportFunction;
import com.dylibso.chicory.runtime.ImportValues;
import com.dylibso.chicory.runtime.Instance;
import com.dylibso.chicory.runtime.Memory;
import com.dylibso.chicory.wasi.WasiPreview1;
import com.dylibso.chicory.wasm.Parser;
import com.dylibso.chicory.wasm.WasmModule;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;

/**
 * Demonstrates consuming a reactor-mode .wasm module from Java via Chicory.
 *
 * <p>Supports two execution modes:
 * <ul>
 *   <li><b>Interpreter</b> (default): pure Java wasm interpreter, no native code
 *   <li><b>Compiler</b>: JIT-compiles wasm to JVM bytecode at load time for ~10x faster execution
 * </ul>
 *
 * <p>The host interaction pattern is the same for both modes:
 * <ol>
 *   <li>Call malloc() to allocate space in the wasm module's memory
 *   <li>Write JSON bytes into that allocation
 *   <li>Call the export function with pointer + length
 *   <li>Read the result string from the returned pointer (null-terminated)
 *   <li>Call free() to release both allocations
 * </ol>
 */
public class CJsonWasm implements AutoCloseable {

    public enum Mode { INTERPRETER, COMPILER }

    private final WasiPreview1 wasi;
    private final Instance instance;
    private final Memory memory;
    private final ExportFunction malloc;
    private final ExportFunction free;
    private final ExportFunction parseAndPrettyPrint;
    private final ExportFunction validateJson;
    private final ExportFunction minifyJson;

    public CJsonWasm(Path wasmPath) {
        this(wasmPath, Mode.INTERPRETER);
    }

    public CJsonWasm(Path wasmPath, Mode mode) {
        WasmModule module = Parser.parse(wasmPath);

        wasi = WasiPreview1.builder().build();

        Instance.Builder builder = Instance.builder(module)
                .withImportValues(
                        ImportValues.builder()
                                .addFunction(wasi.toHostFunctions())
                                .build());
        if (mode == Mode.COMPILER) {
            builder = builder.withMachineFactory(MachineFactoryCompiler::compile);
        }
        instance = builder.build();

        memory = instance.memory();
        malloc = instance.export("malloc");
        free = instance.export("free");
        parseAndPrettyPrint = instance.export("parse_and_pretty_print");
        validateJson = instance.export("validate_json");
        minifyJson = instance.export("minify_json");
    }

    /** Pretty-print a JSON string. Returns null if the input is invalid JSON. */
    public String prettyPrint(String json) {
        byte[] input = json.getBytes(StandardCharsets.UTF_8);

        long inputPtr = malloc.apply(input.length)[0];
        memory.write((int) inputPtr, input);

        long resultPtr = parseAndPrettyPrint.apply(inputPtr, input.length)[0];
        free.apply(inputPtr);

        if (resultPtr == 0) {
            return null;
        }

        String result = memory.readCString((int) resultPtr);
        free.apply(resultPtr);
        return result;
    }

    /** Check if a string is valid JSON. */
    public boolean isValid(String json) {
        byte[] input = json.getBytes(StandardCharsets.UTF_8);
        long inputPtr = malloc.apply(input.length)[0];
        memory.write((int) inputPtr, input);

        long result = validateJson.apply(inputPtr, input.length)[0];
        free.apply(inputPtr);
        return result == 1;
    }

    /** Minify a JSON string. Returns null if the input is invalid JSON. */
    public String minify(String json) {
        byte[] input = json.getBytes(StandardCharsets.UTF_8);
        long inputPtr = malloc.apply(input.length)[0];
        memory.write((int) inputPtr, input);

        long resultPtr = minifyJson.apply(inputPtr, input.length)[0];
        free.apply(inputPtr);

        if (resultPtr == 0) {
            return null;
        }

        String result = memory.readCString((int) resultPtr);
        free.apply(resultPtr);
        return result;
    }

    @Override
    public void close() {
        wasi.close();
    }
}
