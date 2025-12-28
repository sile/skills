# nojson Comprehensive Examples

## Example 1: Complete User Profile Parser

Parse and validate a user profile with nested data:

```rust
use nojson::{RawJson, JsonParseError};
use std::collections::HashMap;

#[derive(Debug)]
struct UserProfile {
    id: u32,
    name: String,
    email: String,
    age: Option<u32>,
    tags: Vec<String>,
    metadata: HashMap<String, String>,
}

fn parse_user_profile(json_text: &str) -> Result<UserProfile, JsonParseError> {
    let json = RawJson::parse(json_text)?;
    let obj = json.value();
    
    // Parse required fields
    let id: u32 = obj.to_member("id")?.required()?.try_into()?;
    let name: String = obj.to_member("name")?.required()?.try_into()?;
    let email: String = obj.to_member("email")?.required()?.try_into()?;
    
    // Validate email format (simple check)
    if !email.contains('@') {
        let email_value = obj.to_member("email")?.required()?;
        return Err(email_value.invalid("Invalid email format"));
    }
    
    // Parse optional field
    let age: Option<u32> = obj.to_member("age")?.try_into()?;
    
    // Parse array
    let tags: Vec<String> = obj.to_member("tags")?.required()?.try_into()?;
    
    // Parse object/map
    let metadata: HashMap<String, String> = 
        obj.to_member("metadata")?.required()?.try_into()?;
    
    Ok(UserProfile {
        id,
        name,
        email,
        age,
        tags,
        metadata,
    })
}

// Usage
fn main() -> Result<(), JsonParseError> {
    let json = r#"{
        "id": 42,
        "name": "Alice",
        "email": "alice@example.com",
        "age": 30,
        "tags": ["admin", "developer", "team-lead"],
        "metadata": {
            "department": "Engineering",
            "team": "Platform"
        }
    }"#;
    
    let profile = parse_user_profile(json)?;
    println!("{:?}", profile);
    Ok(())
}
```

## Example 2: API Response Handling with Errors

Parse API response with error handling:

```rust
use nojson::{RawJson, JsonParseError};

#[derive(Debug)]
enum ApiResponse<T> {
    Success(T),
    Error { code: u32, message: String },
}

fn parse_api_response<T: for<'text, 'raw> TryFrom<
    nojson::RawJsonValue<'text, 'raw>,
    Error = JsonParseError,
>>(json_text: &str) -> Result<ApiResponse<T>, JsonParseError> {
    let json = RawJson::parse(json_text)?;
    let obj = json.value();
    
    let status: String = obj.to_member("status")?.required()?.try_into()?;
    
    match status.as_str() {
        "success" => {
            let data: T = obj.to_member("data")?.required()?.try_into()?;
            Ok(ApiResponse::Success(data))
        },
        "error" => {
            let code: u32 = obj.to_member("code")?.required()?.try_into()?;
            let message: String = obj.to_member("message")?.required()?.try_into()?;
            Ok(ApiResponse::Error { code, message })
        },
        other => {
            let status_value = obj.to_member("status")?.required()?;
            Err(status_value.invalid(format!("Unknown status: {}", other)))
        }
    }
}

// Usage
fn main() -> Result<(), JsonParseError> {
    let success_response = r#"{
        "status": "success",
        "data": {"id": 1, "name": "Example"}
    }"#;
    
    match parse_api_response::<serde_json::Value>(success_response)? {
        ApiResponse::Success(_) => println!("Success!"),
        ApiResponse::Error { code, message } => 
            println!("Error {}: {}", code, message),
    }
    Ok(())
}
```

## Example 3: Generate Complex Formatted JSON

Build and format a complex JSON structure:

```rust
use nojson::json;

fn generate_config() -> String {
    json(|f| {
        f.set_indent_size(2);
        f.set_spacing(true);
        
        f.object(|f| {
            f.member("version", "1.0")?;
            
            f.member("server", json(|f| {
                f.object(|f| {
                    f.member("host", "localhost")?;
                    f.member("port", 8080)?;
                    f.member("ssl", true)
                })
            }))?;
            
            f.member("database", json(|f| {
                f.object(|f| {
                    f.member("driver", "postgres")?;
                    f.member("connection_pool", 20)?;
                    f.member("replicas", json(|f| {
                        f.array(|f| {
                            f.element("db1.example.com")?;
                            f.element("db2.example.com")?;
                            f.element("db3.example.com")
                        })
                    }))?
                })
            }))?;
            
            f.member("logging", json(|f| {
                f.object(|f| {
                    f.member("level", "info")?;
                    f.member("format", "json")
                })
            }))?;
            
            f.member("features", json(|f| {
                f.array(|f| {
                    f.element("authentication")?;
                    f.element("caching")?;
                    f.element("metrics")
                })
            }))
        })
    }).to_string()
}

// Output (formatted):
// {
//   "version": "1.0",
//   "server": {
//     "host": "localhost",
//     "port": 8080,
//     "ssl": true
//   },
//   ...
// }
```

## Example 4: Process Array with Mixed Types

Handle heterogeneous arrays:

```rust
use nojson::{RawJson, JsonValueKind};

fn process_mixed_array(json_text: &str) -> Result<(), Box<dyn std::error::Error>> {
    let json = RawJson::parse(json_text)?;
    
    for (i, element) in json.value().to_array()?.enumerate() {
        match element.kind() {
            JsonValueKind::String => {
                let s: String = element.try_into()?;
                println!("String [{}]: {}", i, s);
            },
            JsonValueKind::Integer => {
                let n: i32 = element.try_into()?;
                println!("Integer [{}]: {}", i, n);
            },
            JsonValueKind::Object => {
                let obj_name: String = element
                    .to_member("type")?.required()?.try_into()?;
                println!("Object [{}]: type = {}", i, obj_name);
            },
            JsonValueKind::Array => {
                let len = element.to_array()?.count();
                println!("Array [{}]: length = {}", i, len);
            },
            kind => println!("Other [{}]: {:?}", i, kind),
        }
    }
    
    Ok(())
}

// Usage
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let json = r#"[
        "hello",
        42,
        {"type": "special"},
        [1, 2, 3],
        null,
        true
    ]"#;
    
    process_mixed_array(json)?;
    Ok(())
}
```

## Example 5: JSONC with Comments and Trailing Commas

Parse configuration with helpful comments:

```rust
use nojson::RawJson;

fn load_config_with_comments(json_text: &str) -> Result<(), Box<dyn std::error::Error>> {
    // Parse JSONC format
    let (json, comment_ranges) = RawJson::parse_jsonc(json_text)?;
    
    // Process JSON normally
    let obj = json.value();
    
    let debug: bool = obj.to_member("debug")?
        .required()?.try_into()?;
    let level: String = obj.to_member("log_level")?
        .required()?.try_into()?;
    
    println!("Debug: {}, Level: {}", debug, level);
    
    // Show where comments were found
    println!("Found {} comments:", comment_ranges.len());
    for range in comment_ranges {
        println!("  - {}", &json_text[range]);
    }
    
    Ok(())
}

// Usage
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config = r#"{
        // Development configuration
        "debug": true,
        "log_level": "debug", // Very verbose
        "features": [
            "auth",    // Authentication
            "cache",   // Caching layer
            "metrics", // Monitoring
        ], // End features
    }"#;
    
    load_config_with_comments(config)?;
    Ok(())
}
```

## Example 6: Custom Type with TryFrom and DisplayJson

Implement parsing and formatting for custom type:

```rust
use nojson::{DisplayJson, Json, JsonFormatter, JsonParseError, RawJsonValue};

#[derive(Debug, PartialEq)]
struct Point {
    x: f64,
    y: f64,
}

impl DisplayJson for Point {
    fn fmt(&self, f: &mut JsonFormatter<'_, '_>) -> std::fmt::Result {
        f.array(|f| {
            f.element(self.x)?;
            f.element(self.y)
        })
    }
}

impl<'text, 'raw> TryFrom<RawJsonValue<'text, 'raw>> for Point {
    type Error = JsonParseError;
    
    fn try_from(value: RawJsonValue<'text, 'raw>) -> Result<Self, Self::Error> {
        let arr: [f64; 2] = value.try_into()?;
        Ok(Point { x: arr[0], y: arr[1] })
    }
}

// Usage
fn main() -> Result<(), JsonParseError> {
    // Parse
    let point: Json<Point> = "[3.5, 4.2]".parse()?;
    assert_eq!(point.0, Point { x: 3.5, y: 4.2 });
    
    // Generate
    let p = Point { x: 10.0, y: 20.0 };
    assert_eq!(Json(&p).to_string(), "[10,20]");
    
    Ok(())
}
```

## Example 7: Error Handling with Context

Detailed error reporting with position information:

```rust
use nojson::RawJson;

fn parse_with_context(json_text: &str) -> Result<(), Box<dyn std::error::Error>> {
    match RawJson::parse(json_text) {
        Ok(json) => {
            // Process successfully parsed JSON
            println!("Valid JSON with {} bytes", json.text().len());
            Ok(())
        },
        Err(error) => {
            // Get detailed error information
            println!("Parse error: {}", error);
            
            // Get position information
            if let Some((line, col)) = error.get_line_and_column_numbers(json_text) {
                println!("Position: line {}, column {}", line.get(), col.get());
            }
            
            // Get the line containing the error
            if let Some(line_text) = error.get_line(json_text) {
                println!("Line content: {}", line_text);
            }
            
            // Get the value at error position if available
            if let Some(value) = RawJson::parse(json_text)
                .ok()
                .and_then(|j| j.get_value_by_position(error.position()))
            {
                println!("Found value at position: {}", value.as_raw_str());
            }
            
            Err(error.into())
        }
    }
}

// Usage
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let bad_json = r#"{
        "valid": true,
        "broken" 123
    }"#;
    
    parse_with_context(bad_json)?;
    Ok(())
}
```

## Example 8: Flatten Nested Structures

Transform nested JSON into flat structure:

```rust
use nojson::RawJson;
use std::collections::HashMap;

fn flatten_json(
    prefix: String,
    value: nojson::RawJsonValue,
    result: &mut HashMap<String, String>
) -> Result<(), Box<dyn std::error::Error>> {
    match value.kind() {
        nojson::JsonValueKind::Object => {
            for (key, val) in value.to_object()? {
                let key_str = key.to_unquoted_string_str()?;
                let new_prefix = if prefix.is_empty() {
                    key_str.into_owned()
                } else {
                    format!("{}.{}", prefix, key_str)
                };
                flatten_json(new_prefix, val, result)?;
            }
        },
        nojson::JsonValueKind::Array => {
            for (idx, val) in value.to_array()?.enumerate() {
                let new_prefix = format!("{}[{}]", prefix, idx);
                flatten_json(new_prefix, val, result)?;
            }
        },
        _ => {
            // Leaf value
            result.insert(prefix, value.as_raw_str().to_string());
        }
    }
    Ok(())
}

// Usage
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let json = r#"{
        "user": {
            "name": "Alice",
            "age": 30,
            "tags": ["admin", "dev"]
        },
        "active": true
    }"#;
    
    let parsed = RawJson::parse(json)?;
    let mut flat = HashMap::new();
    
    flatten_json(String::new(), parsed.value(), &mut flat)?;
    
    for (key, value) in flat {
        println!("{} = {}", key, value);
    }
    // Output:
    // user.name = "Alice"
    // user.age = 30
    // user.tags[0] = "admin"
    // user.tags[1] = "dev"
    // active = true
    
    Ok(())
}
```

## Example 9: Query-Like Selection

Select specific fields from JSON:

```rust
use nojson::{RawJson, json};
use std::collections::HashMap;

fn select_fields(json_text: &str, fields: &[&str]) 
    -> Result<String, Box<dyn std::error::Error>> 
{
    let json = RawJson::parse(json_text)?;
    let obj = json.value();
    
    let selected: HashMap<String, String> = fields
        .iter()
        .filter_map(|field| {
            obj.to_member(field)
                .ok()?
                .get()
                .map(|v| (field.to_string(), v.as_raw_str().to_string()))
        })
        .collect();
    
    Ok(json(|f| f.value(&selected)).to_string())
}

// Usage
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let json = r#"{"id": 1, "name": "Alice", "email": "alice@example.com", "age": 30}"#;
    
    // Select only id and name
    let result = select_fields(json, &["id", "name"])?;
    println!("{}", result);
    // Output: {"id":"1","name":"Alice"}
    
    Ok(())
}
```

## Example 10: Batch Processing with Error Recovery

Process multiple JSON documents with partial failure handling:

```rust
use nojson::Json;

#[derive(Debug)]
struct ProcessResult<T> {
    index: usize,
    success: Option<T>,
    error: Option<String>,
}

fn batch_parse<T: for<'text, 'raw> TryFrom<
    nojson::RawJsonValue<'text, 'raw>,
    Error = nojson::JsonParseError,
>>(json_texts: Vec<&str>) -> Vec<ProcessResult<T>> {
    json_texts
        .into_iter()
        .enumerate()
        .map(|(index, text)| {
            match Json::<T>::parse(text) {
                Ok(value) => ProcessResult {
                    index,
                    success: Some(value.0),
                    error: None,
                },
                Err(e) => ProcessResult {
                    index,
                    success: None,
                    error: Some(format!("{}", e)),
                },
            }
        })
        .collect()
}

// Usage
fn main() {
    let jsons = vec![
        r#"{"id": 1}"#,
        r#"{"id": 2}"#,
        r#"invalid"#,
        r#"{"id": 3}"#,
    ];
    
    let results = batch_parse::<serde_json::Value>(jsons);
    
    for result in results {
        match &result.success {
            Some(_) => println!("[{}] ✓ Success", result.index),
            None => println!("[{}] ✗ {}", result.index, 
                           result.error.as_ref().unwrap()),
        }
    }
}
```
