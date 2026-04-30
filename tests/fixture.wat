(module
  (memory (export "memory") 1)
  (func $alloc (export "malloc") (param i32) (result i32)
    i32.const 1024)
  (func $free (export "free") (param i32))
  (func $add (export "add") (param i32 i32) (result i32)
    local.get 0
    local.get 1
    i32.add)
  (func $start (export "_start"))
)
