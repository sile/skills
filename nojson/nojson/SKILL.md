---
name: nojson
description: Rust JSON library for flexible parsing and generation without dependencies or macros. Use when working with Rust JSON processing, data validation, or custom JSON parsing that requires dynamic flexibility combined with type safety. Supports parsing to Rust types, generating JSON with formatting options, handling comments (JSONC), custom validations, and rich error messages with position information.
---

# nojson Skill

A comprehensive guide for using the `nojson` Rust crate—a flexible JSON library that combines type-level programming with imperative code flexibility.

## Core Concepts

### What is nojson?

`nojson` is a JSON library that offers balance between Rust's type-safety and JSON's dynamic nature. Unlike `serde`, it doesn't require strict one-to-one type mapping, allowing you to:

- Parse JSON into typed Rust structures with `TryFrom<RawJsonValue>`
- Generate JSON from Rust types with `DisplayJson` trait
- Validate with custom rules and rich error context
- Handle JSONC (JSON with comments and trailing commas)
- Format output with customizable indentation and spacing

Key features:
- **No dependencies** - Zero external crates required
- **No macros** - Pure trait-based design
- **Flexible parsing** - Mix type-level and imperative approaches
- **Rich errors** - Position information (line/column) for debugging
- **Low-level access** - Work with raw JSON structure when needed

## Quick Reference

### Parsing JSON to Rust Types

```rust
use nojson::Json;

// Parse with strong typing
let json: Json<[Option<u32>; 3]> = "[1, null, 2]".parse()?;
assert_eq!(json.0, [Some(1), None, Some(2)]);

// Access object members
let text = r#"{"name": "Alice", "age": 30}"#;
let json = nojson::RawJson::parse(text)?;
let name: String = json.value().to_member("name")?.required()?.try_into()?;
let age: u32 = json.value().to_member("age")?.required()?.try_into()?;
```

### Generating JSON

```rust
use nojson::{Json, json};

// From Rust types (compact)
let arr = [Some(1), None, Some(2)];
assert_eq!(Json(arr).to_string(), "[1,null,2]");

// In-place generation (formatted)
let formatted = json(|f| {
    f.set_indent_size(2);
    f.set_spacing(true);
    f.array(|f| {
        f.element(1)?;
        f.element(2)?;
        f.element(3)
    })
});
```

### Custom Type Implementation

Implement both `DisplayJson` and `TryFrom<RawJsonValue<'_, '_>>`:

```rust
impl DisplayJson for MyType {
    fn fmt(&self, f: &mut JsonFormatter<'_, '_>) -> std::fmt::Result {
        f.object(|f| {
            f.member("field1", &self.field1)?;
            f.member("field2", self.field2)
        })
    }
}

impl<'text, 'raw> TryFrom<RawJsonValue<'text, 'raw>> for MyType {
    type Error = JsonParseError;
    fn try_from(value: RawJsonValue<'text, 'raw>) -> Result<Self, Self::Error> {
        let field1 = value.to_member("field1")?.required()?;
        // ... convert fields
    }
}
```

## Common Patterns

### Error Handling with Context

```rust
use nojson::{JsonParseError, RawJson};

let text = r#"{"invalid": 123e++}"#;
if let Err(error) = RawJson::parse(text) {
    // Get position
    if let Some((line, column)) = error.get_line_and_column_numbers(text) {
        println!("Line {}, column {}", line.get(), column.get());
    }
    // Get line content
    if let Some(line_text) = error.get_line(text) {
        println!("Line: {}", line_text);
    }
}
```

### Custom Validation

```rust
use nojson::{JsonParseError, RawJson, RawJsonValue};

fn parse_positive_number(text: &str) -> Result<u32, JsonParseError> {
    let json = RawJson::parse(text)?;
    let raw_value = json.value();
    
    let num: u32 = raw_value.as_number_str()?
        .parse()
        .map_err(|e| raw_value.invalid(e))?;
    
    if num == 0 {
        return Err(raw_value.invalid("Expected a positive number, got 0"));
    }
    Ok(num)
}
```

### JSONC Parsing (JSON with Comments)

```rust
use nojson::RawJson;

let text = r#"{
    "name": "John", // Comment here
    "age": 30, // Trailing comma allowed
}
"#;

let (json, comment_ranges) = RawJson::parse_jsonc(text)?;
// Use json normally, comment_ranges shows where comments were
for range in comment_ranges {
    println!("Comment: {}", &text[range]);
}
```

### Working with Dynamic JSON

When you don't know the structure beforehand, use `RawJson` for low-level access:

```rust
use nojson::RawJson;

let json = RawJson::parse(r#"[1, "text", {"key": true}]"#)?;

// Iterate array
for (i, element) in json.value().to_array()?.enumerate() {
    println!("Element {}: {}", i, element.as_raw_str());
}

// Iterate object
for (key, value) in json.value().to_object()? {
    let key_str = key.to_unquoted_string_str()?;
    println!("{}: {}", key_str, value.as_raw_str());
}
```

### Formatting Options

```rust
use nojson::json;

// Compact (default)
let compact = json(|f| f.value([1, 2, 3]));
// Output: [1,2,3]

// With spacing
let spaced = json(|f| {
    f.set_spacing(true);
    f.value([1, 2, 3])
});
// Output: [ 1, 2, 3 ]

// Pretty-printed with indentation
let pretty = json(|f| {
    f.set_indent_size(2);
    f.set_spacing(true);
    f.value([1, 2, 3])
});
// Output (with newlines):
// [
//   1,
//   2,
//   3
// ]
```

## Type Conversions

### Built-in Support

`nojson` provides `TryFrom<RawJsonValue>` implementations for:

- **Primitives**: `bool`, integers, floats, `char`
- **Collections**: `Vec<T>`, `[T; N]`, `HashSet<T>`, `BTreeSet<T>`, `VecDeque<T>`
- **Maps**: `HashMap<K, V>`, `BTreeMap<K, V>`
- **Wrappers**: `Option<T>`, `Box<T>`, `Rc<T>`, `Arc<T>`
- **Standard types**: `String`, `PathBuf`, IP addresses (`IpAddr`, `Ipv4Addr`, etc.)
- **NonZero types**: `NonZeroI8`, `NonZeroU32`, etc.

### Nullable Values

Use `Option<T>` to handle optional JSON values:

```rust
use nojson::Json;

let text = r#"{"optional": null, "present": 42}"#;
let json = nojson::RawJson::parse(text)?;

// Missing member converts to None
let missing: Option<i32> = json.value()
    .to_member("missing")?.try_into()?;
assert_eq!(missing, None);

// Null value also converts to None
let null_val: Option<i32> = json.value()
    .to_member("optional")?.try_into()?;
assert_eq!(null_val, None);

// Present value converts to Some
let present: Option<i32> = json.value()
    .to_member("present")?.try_into()?;
assert_eq!(present, Some(42));
```

## Advanced Features

### Extracting Subvalues

Extract a portion of JSON as an owned `RawJson`:

```rust
use nojson::RawJson;

let text = r#"{"user": {"name": "John", "age": 30}, "count": 42}"#;
let json = RawJson::parse(text)?;

let user_value = json.value()
    .to_member("user")?.required()?;

// Extract as independent RawJson
let user_json = user_value.extract();
// Now user_json.text() == r#"{"name": "John", "age": 30}"#
```

### Navigating JSON Structure

```rust
use nojson::RawJson;

let json = RawJson::parse(r#"[{"nested": true}]"#)?;

// Get value by position
if let Some(value) = json.get_value_by_position(5) {
    println!("Found: {}", value.as_raw_str());
}

// Get parent/root
let element = json.value().to_array()?.next().unwrap();
let parent = element.parent(); // Get containing array
let root = element.root();     // Get top-level value
```

### String Escaping

Strings are automatically escaped when generating JSON:

```rust
use nojson::json;

let text = "Line 1\nLine 2\tTabbed";
let output = json(|f| f.string(text));
// Automatically escapes: "Line 1\nLine 2\tTabbed"

let quote = r#"He said "hello""#;
let output = json(|f| f.string(quote));
// Automatically escapes: "He said \"hello\""
```

## Common Error Patterns

### Understanding JsonParseError

```rust
use nojson::{RawJson, JsonParseError};

match RawJson::parse("invalid json") {
    Ok(_) => {},
    Err(error) => {
        // Get error kind and position
        println!("Kind: {:?}", error.kind());
        println!("Position: {}", error.position());
        
        // Get contextual info
        if let Some((line, column)) = error.get_line_and_column_numbers("invalid json") {
            println!("At {}:{}", line.get(), column.get());
        }
    }
}
```

### Type Mismatch Handling

```rust
use nojson::RawJson;

let json = RawJson::parse(r#"{"value": "not a number"}"#)?;
let value = json.value().to_member("value")?.required()?;

// This will fail with helpful error
match value.as_integer_str() {
    Err(e) => println!("Error: {}", e),
    Ok(_) => {}
}
```

## Reference Documentation

For detailed API reference and advanced scenarios, see:

- [**API Reference**](references/api-reference.md) - Complete type and trait documentation
- [**Patterns**](references/patterns.md) - Common usage patterns and idioms
- [**Examples**](references/examples.md) - Comprehensive code examples

## When to Use nojson

✅ **Use nojson when:**
- You need flexible JSON parsing without boilerplate
- You want type safety but also dynamic handling
- You need rich error messages with position info
- You're building domain-specific JSON validators
- You need zero dependencies in your crate
- You want to mix imperative and declarative JSON handling

❌ **Consider alternatives when:**
- You need a one-to-one mapping to Rust types (use `serde_json`)
- You're working with serializing large data structures
- You need extensive ecosystem support for various formats
