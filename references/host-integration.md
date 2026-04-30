# Host Integration Reference

How to consume compiled `.wasm` modules from host runtimes.

## Memory Passing Conventions

Wasm modules use **linear memory** — a flat byte array shared between host and guest. To pass data:

### Host → Guest (sending data in)
1. Call `malloc(len)` → get a pointer `ptr` into wasm memory
2. Write bytes at `ptr` in the wasm memory
3. Call the target function with `(ptr, len)`
4. Call `free(ptr)` when done

### Guest → Host (getting data out)
Two patterns:

**Return value**: Function returns an `i32` result directly. Use for simple cases (booleans, counts, error codes).

**Callee-allocates**: Function allocates memory for the result, writes to it, returns a pointer. Host reads from the returned pointer (typically null-terminated for strings, or with a known length), then calls `free(ptr)`.

### String Encoding
- C modules: null-terminated strings (read until `\0`)
- Rust modules: pointer + length pairs (no null terminator, explicit length)

## Wasmtime (Rust)

### CLI — Command-mode modules
```bash
# Run a CLI tool with stdin/stdout
echo "input data" | wasmtime run module.wasm

# Pass arguments
wasmtime run module.wasm -- --flag value

# Map a directory for file access
wasmtime run --dir . module.wasm
```

### Rust API — Reactor-mode modules
```rust
use wasmtime::*;

let engine = Engine::default();
let module = Module::from_file(&engine, "module.wasm")?;
let linker = Linker::new(&engine);
let wasi = wasmtime_wasi::WasiCtxBuilder::new().build();
let mut store = Store::new(&engine, wasi);
let instance = linker.instantiate(&mut store, &module)?;

// Get exports
let memory = instance.get_memory(&mut store, "memory").unwrap();
let malloc = instance.get_typed_func::<i32, i32>(&mut store, "malloc")?;
let free = instance.get_typed_func::<i32, ()>(&mut store, "free")?;
let my_func = instance.get_typed_func::<(i32, i32), i32>(&mut store, "my_func")?;

// Write data to wasm memory
let input = b"hello";
let ptr = malloc.call(&mut store, input.len() as i32)?;
memory.write(&mut store, ptr as usize, input)?;

// Call function
let result = my_func.call(&mut store, (ptr, input.len() as i32))?;

// Read result (null-terminated string)
let mem_data = memory.data(&store);
let start = result as usize;
let end = mem_data[start..].iter().position(|&b| b == 0).unwrap() + start;
let output = std::str::from_utf8(&mem_data[start..end])?;

// Cleanup
free.call(&mut store, ptr)?;
free.call(&mut store, result)?;
```

See `examples/consume-wasmtime/` for a complete working example.

## Chicory (Java)

Chicory supports two execution modes:
- **Interpreter**: pure Java, no native code, works everywhere
- **Compiler**: JIT-compiles wasm to JVM bytecode at load time (~10x faster)

### Interpreter mode
```java
import com.dylibso.chicory.runtime.Instance;
import com.dylibso.chicory.wasm.Parser;

var module = Parser.parse(Path.of("module.wasm"));
var instance = Instance.builder(module).build();
```

### Compiler mode
```java
import com.dylibso.chicory.compiler.MachineFactoryCompiler;

var module = Parser.parse(Path.of("module.wasm"));
var instance = Instance.builder(module)
        .withMachineFactory(MachineFactoryCompiler::compile)
        .build();
```

### Calling exports and passing data
```java
var memory = instance.memory();
var malloc = instance.export("malloc");
var free = instance.export("free");
var myFunc = instance.export("my_func");

// Write data to wasm memory
byte[] input = "hello".getBytes(StandardCharsets.UTF_8);
long ptr = malloc.apply(input.length)[0];
memory.write((int) ptr, input);

// Call function
long result = myFunc.apply(ptr, input.length)[0];

// Read result (null-terminated C string)
String output = memory.readCString((int) result);

// Cleanup
free.apply(ptr);
free.apply(result);
```

### Maven dependencies
```xml
<dependency>
    <groupId>com.dylibso.chicory</groupId>
    <artifactId>runtime</artifactId>
    <version>${chicory.version}</version>
</dependency>
<dependency>
    <groupId>com.dylibso.chicory</groupId>
    <artifactId>wasm</artifactId>
    <version>${chicory.version}</version>
</dependency>
<!-- Add for compiler mode -->
<dependency>
    <groupId>com.dylibso.chicory</groupId>
    <artifactId>compiler</artifactId>
    <version>${chicory.version}</version>
</dependency>
<!-- Add if the wasm module uses WASI -->
<dependency>
    <groupId>com.dylibso.chicory</groupId>
    <artifactId>wasi</artifactId>
    <version>${chicory.version}</version>
</dependency>
```

See `examples/consume-chicory/` for a complete working example with JUnit tests.

## Choosing a Runtime

| Criteria | Wasmtime | Chicory |
|----------|----------|---------|
| Language | Rust, C, Python bindings | Java |
| Speed | Native execution | Interpreter or JVM JIT |
| Portability | Needs native library per platform | Pure Java (interpreter) |
| WASI support | Full P1 + P2 | P1 |
| Best for | CLI tools, high-throughput | JVM applications, portability |
