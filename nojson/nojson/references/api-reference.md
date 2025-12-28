# nojson API Reference

## Core Types

### `Json<T>`

A marker struct that enables JSON parsing and generation through standard Rust traits.

**Methods:**
- Implements `FromStr` for parsing: `"[1,2,3]".parse::<Json<Vec<i32>>>()?`
- Implements `Display` for formatting: `Json(value).to_string()`
- Field: `Json::0` - Contains the parsed/formatted value

**Usage:**
```rust
let value: Json<[u32; 3]> = "[1, 2, 3]".parse()?;
println!("{}", Json(&value.0)); // Generate JSON
```

### `RawJson<'text>`

Parsed JSON text in its original form, maintaining index information about each value.

**Methods:**
- `parse(text: &'text str) -> Result<Self, JsonParseError>` - Parse standard JSON
- `parse_jsonc(text: &'text str) -> Result<(Self, Vec<Range<usize>>), JsonParseError>` - Parse JSON with comments
- `text(&self) -> &'text str` - Get original JSON text
- `value(&self) -> RawJsonValue<'text, '_>` - Get top-level JSON value
- `get_value_by_position(&self, position: usize) -> Option<RawJsonValue>` - Find value at byte position
- `into_owned(self) -> RawJsonOwned` - Convert to owned version

### `RawJsonOwned`

Owned version of `RawJson`, allowing JSON data to outlive the source text.

**Methods:**
- `parse(text: impl Into<String>) -> Result<Self, JsonParseError>` - Parse and own text
- `parse_jsonc(text: impl Into<String>) -> Result<(Self, Vec<Range<usize>>), JsonParseError>` - Parse JSONC and own text
- `text(&self) -> &str` - Get owned JSON text
- `value(&self) -> RawJsonValue<'_, '_>` - Get top-level value
- `get_value_by_position(&self, position: usize) -> Option<RawJsonValue>` - Find value at position

### `RawJsonValue<'text, 'raw>`

A single JSON value with methods for type checking, conversion, and traversal.

**Type Information:**
- `kind(&self) -> JsonValueKind` - Get value type (Null, Boolean, Integer, Float, String, Array, Object)
- `position(&self) -> usize` - Get byte position in original text
- `as_raw_str(&self) -> &'text str` - Get raw JSON text representation

**Type-Specific Methods:**
- `as_boolean_str(&self) -> Result<&'text str, JsonParseError>` - Get boolean text
- `as_integer_str(&self) -> Result<&'text str, JsonParseError>` - Get integer text
- `as_float_str(&self) -> Result<&'text str, JsonParseError>` - Get float text
- `as_number_str(&self) -> Result<&'text str, JsonParseError>` - Get integer or float text
- `to_unquoted_string_str(&self) -> Result<Cow<'text, str>, JsonParseError>` - Get string content (unquoted)

**Collection Methods:**
- `to_array(&self) -> Result<impl Iterator<Item = Self>, JsonParseError>` - Iterate array elements
- `to_object(&self) -> Result<impl Iterator<Item = (Self, Self)>, JsonParseError>` - Iterate object members (key-value pairs)
- `to_member(&self, name: &str) -> Result<RawJsonMember, JsonParseError>` - Access object member by name

**Navigation:**
- `parent(&self) -> Option<Self>` - Get containing array/object
- `root(&self) -> Self` - Get top-level value
- `extract(&self) -> RawJson<'text>` - Extract as independent RawJson

**Utilities:**
- `map<F, T>(&self, f: F) -> Result<T, JsonParseError>` - Apply function transformation
- `invalid<E>(&self, error: E) -> JsonParseError` - Create error at this value's position

**Conversions:**
Implements `TryFrom<RawJsonValue<'_, '_>>` for:
- Primitives: `bool`, `i8`-`i128`, `u8`-`u128`, `isize`, `usize`
- Floats: `f32`, `f64`
- Strings: `char`, `String`, `Cow<str>`
- Collections: `Vec<T>`, `[T; N]`, `HashSet<T>`, `BTreeSet<T>`, `VecDeque<T>`
- Maps: `HashMap<K, V>`, `BTreeMap<K, V>`
- Wrappers: `Option<T>`, `Box<T>`, `Rc<T>`, `Arc<T>`
- Network: `IpAddr`, `Ipv4Addr`, `Ipv6Addr`, `SocketAddr`, `SocketAddrV4`, `SocketAddrV6`
- Paths: `PathBuf`
- NonZero: `NonZeroI8`, `NonZeroU8`, etc.

### `RawJsonMember<'text, 'raw, 'a>`

Represents result of object member access—may exist or be missing.

**Methods:**
- `required(&self) -> Result<RawJsonValue, JsonParseError>` - Get member or error if missing
- `get(&self) -> Option<RawJsonValue>` - Get as Option
- `map<F, T>(&self, f: F) -> Result<Option<T>, JsonParseError>` - Apply function if present

**Conversions:**
Implements `TryFrom<RawJsonMember>` for `Option<T>` where `T: TryFrom<RawJsonValue>`

## Traits

### `DisplayJson`

Convert Rust types to JSON format.

**Method:**
```rust
pub trait DisplayJson {
    fn fmt(&self, f: &mut JsonFormatter<'_, '_>) -> std::fmt::Result;
}
```

**Built-in Implementations:** bool, integers, floats, String, Vec, HashMap, Option, and many more.

**Example:**
```rust
impl DisplayJson for MyType {
    fn fmt(&self, f: &mut JsonFormatter<'_, '_>) -> std::fmt::Result {
        f.object(|f| {
            f.member("key", "value")
        })
    }
}
```

## Formatting Types

### `JsonFormatter<'a, 'b>`

Main formatter for generating JSON with control over output.

**Methods:**
- `value<T: DisplayJson>(&mut self, value: T) -> std::fmt::Result` - Format any DisplayJson type
- `string<T: Display>(&mut self, content: T) -> std::fmt::Result` - Format as JSON string
- `array<F>(&mut self, f: F) -> std::fmt::Result` - Start array (F: FnOnce(&mut JsonArrayFormatter))
- `object<F>(&mut self, f: F) -> std::fmt::Result` - Start object (F: FnOnce(&mut JsonObjectFormatter))
- `inner_mut(&mut self) -> &mut std::fmt::Formatter<'b>` - Access wrapped formatter

**Configuration:**
- `set_indent_size(&mut self, size: usize)` - Set spaces per indentation level
- `get_indent_size(&self) -> usize` - Get current indent size
- `set_spacing(&mut self, enable: bool)` - Add space after ':' and ','
- `get_spacing(&self) -> bool` - Check if spacing enabled
- `get_level(&self) -> usize` - Get current indentation level

### `JsonArrayFormatter<'a, 'b, 'c>`

Formatter for array elements (created by `JsonFormatter::array`).

**Methods:**
- `element<T: DisplayJson>(&mut self, element: T) -> std::fmt::Result` - Add element
- `elements<I>(&mut self, elements: I) -> std::fmt::Result` - Add multiple elements (I: IntoIterator<Item: DisplayJson>)

### `JsonObjectFormatter<'a, 'b, 'c>`

Formatter for object members (created by `JsonFormatter::object`).

**Methods:**
- `member<N: Display, V: DisplayJson>(&mut self, name: N, value: V) -> std::fmt::Result` - Add member
- `members<I, N: Display, V: DisplayJson>(&mut self, members: I) -> std::fmt::Result` - Add multiple members (I: IntoIterator<Item = (N, V)>)

## Error Types

### `JsonParseError`

Enum representing parsing errors with position information.

**Variants:**
- `UnexpectedEos { kind: Option<JsonValueKind>, position: usize }` - Unexpected end of input
- `UnexpectedTrailingChar { kind: JsonValueKind, position: usize }` - Extra characters after JSON
- `UnexpectedValueChar { kind: Option<JsonValueKind>, position: usize }` - Invalid character during parsing
- `InvalidValue { kind: JsonValueKind, position: usize, error: Box<dyn Error> }` - Valid JSON but invalid value

**Methods:**
- `kind(&self) -> Option<JsonValueKind>` - Get kind of value being parsed
- `position(&self) -> usize` - Get byte position in input
- `get_line_and_column_numbers(&self, text: &str) -> Option<(NonZeroUsize, NonZeroUsize)>` - Get line and column
- `get_line(&self, text: &str) -> Option<&str>` - Get text of line with error
- `invalid_value(value: RawJsonValue, error: E) -> JsonParseError` - Create InvalidValue error

Implements `Display` and `std::error::Error`.

### `JsonValueKind`

Enum representing JSON value types.

**Variants:**
- `Null` - JSON null
- `Boolean` - JSON true/false
- `Integer` - JSON number without decimal
- `Float` - JSON number with decimal or exponent
- `String` - JSON string
- `Array` - JSON array
- `Object` - JSON object

**Methods:**
- `is_null(&self) -> bool`
- `is_bool(&self) -> bool`
- `is_integer(&self) -> bool`
- `is_float(&self) -> bool`
- `is_number(&self) -> bool` - True for Integer or Float
- `is_string(&self) -> bool`
- `is_array(&self) -> bool`
- `is_object(&self) -> bool`

## Helper Functions

### `json<F>(f: F) -> impl DisplayJson + Display`

Create JSON in-place with custom formatting.

```rust
let output = json(|f| {
    f.set_indent_size(2);
    f.object(|f| {
        f.member("key", "value")
    })
});
```

### `object<F>(fmt: F) -> impl DisplayJson + Display`

Shorthand for `json(|f| f.object(|f| fmt(f)))`.

```rust
let obj = object(|f| {
    f.member("name", "Alice")?;
    f.member("age", 30)
});
```

### `array<F>(fmt: F) -> impl DisplayJson + Display`

Shorthand for `json(|f| f.array(|f| fmt(f)))`.

```rust
let arr = array(|f| {
    f.element(1)?;
    f.element(2)?;
    f.element(3)
});
```
