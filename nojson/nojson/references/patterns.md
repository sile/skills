# nojson Usage Patterns and Idioms

## Pattern: Flexible Object Parsing

When parsing objects with optional or variable fields, use `to_member()` for flexible handling:

```rust
use nojson::RawJson;

let json = RawJson::parse(r#"{"name": "Bob", "email": "bob@example.com"}"#)?;
let obj = json.value();

// Required field
let name: String = obj.to_member("name")?.required()?.try_into()?;

// Optional field
let phone: Option<String> = obj.to_member("phone")?.try_into()?;

// Field with custom default
let city: String = match obj.to_member("city")? {
    member => member.map(|v| v.try_into())?.unwrap_or_else(|| Ok("Unknown".to_string()))?
};
```

## Pattern: Strict Type Validation

When you need guaranteed type safety, validate early:

```rust
use nojson::{RawJson, JsonParseError};

fn parse_config(text: &str) -> Result<Config, JsonParseError> {
    let json = RawJson::parse(text)?;
    let value = json.value();
    
    // Validate it's an object
    if !value.kind().is_object() {
        return Err(value.invalid("Config must be a JSON object"));
    }
    
    let port: u16 = value.to_member("port")?.required()?
        .as_integer_str()?
        .parse()
        .map_err(|e| value.invalid(e))?;
    
    if port < 1024 {
        return Err(value.invalid("Port must be >= 1024"));
    }
    
    Ok(Config { port })
}
```

## Pattern: Conditional Parsing Based on Type

Use discriminator fields to handle different JSON structures:

```rust
use nojson::RawJson;

let json = RawJson::parse(r#"{"type": "user", "name": "Alice", "role": "admin"}"#)?;
let obj = json.value();

let type_str: String = obj.to_member("type")?.required()?.try_into()?;

match type_str.as_str() {
    "user" => {
        let name: String = obj.to_member("name")?.required()?.try_into()?;
        let role: String = obj.to_member("role")?.required()?.try_into()?;
        // Process user...
    },
    "admin" => {
        let name: String = obj.to_member("name")?.required()?.try_into()?;
        let permissions: Vec<String> = obj.to_member("permissions")?
            .required()?.try_into()?;
        // Process admin...
    },
    other => {
        return Err(obj.invalid(format!("Unknown type: {}", other)));
    }
}
```

## Pattern: Collecting Array Elements with Validation

When processing arrays with per-element validation:

```rust
use nojson::RawJson;

let json = RawJson::parse(r#"[1, 2, 3, "not a number", 5]"#)?;

let mut numbers = Vec::new();
for (i, element) in json.value().to_array()?.enumerate() {
    match element.as_integer_str() {
        Ok(num_str) => {
            let num: i32 = num_str.parse()
                .map_err(|e| element.invalid(e))?;
            if num < 0 {
                return Err(element.invalid(format!(
                    "Element {} must be non-negative", i
                )));
            }
            numbers.push(num);
        },
        Err(_) => {
            return Err(element.invalid(format!(
                "Element {} must be a number", i
            )));
        }
    }
}
```

## Pattern: Building JSON Incrementally

Use closures to build complex JSON structures:

```rust
use nojson::json;

let data = vec![("Alice", 30), ("Bob", 25)];

let result = json(|f| {
    f.set_indent_size(2);
    f.set_spacing(true);
    f.object(|f| {
        f.member("users", json(|f| {
            f.array(|f| {
                for (name, age) in &data {
                    f.element(json(|f| {
                        f.object(|f| {
                            f.member("name", *name)?;
                            f.member("age", *age)
                        })
                    }))?;
                }
                Ok(())
            })
        }))?;
        f.member("count", data.len())
    })
});
```

## Pattern: Custom Type with Nested Objects

Implement DisplayJson for nested structures:

```rust
use nojson::{DisplayJson, JsonFormatter};

struct Address {
    street: String,
    city: String,
}

struct User {
    name: String,
    address: Address,
}

impl DisplayJson for Address {
    fn fmt(&self, f: &mut JsonFormatter<'_, '_>) -> std::fmt::Result {
        f.object(|f| {
            f.member("street", &self.street)?;
            f.member("city", &self.city)
        })
    }
}

impl DisplayJson for User {
    fn fmt(&self, f: &mut JsonFormatter<'_, '_>) -> std::fmt::Result {
        f.object(|f| {
            f.member("name", &self.name)?;
            f.member("address", &self.address)
        })
    }
}
```

## Pattern: Parsing with Default Values

Use Option and unwrap_or for defaults:

```rust
use nojson::RawJson;

let json = RawJson::parse(r#"{"name": "Alice"}"#)?;
let obj = json.value();

let name: String = obj.to_member("name")?.required()?.try_into()?;
let age: u32 = match obj.to_member("age")? {
    member => member.map(|v| v.try_into())?.unwrap_or(18)
};
let city: String = match obj.to_member("city")? {
    member => member.map(|v| v.try_into())?.unwrap_or_else(|_| Ok("Unknown".to_string()))?
};
```

## Pattern: Nested Object Navigation

Access deeply nested values:

```rust
use nojson::RawJson;

let json = RawJson::parse(r#"{
    "user": {
        "profile": {
            "location": {
                "city": "NYC"
            }
        }
    }
}"#)?;

let city: String = json.value()
    .to_member("user")?.required()?
    .to_member("profile")?.required()?
    .to_member("location")?.required()?
    .to_member("city")?.required()?
    .try_into()?;

assert_eq!(city, "NYC");
```

## Pattern: Array of Objects Filtering

Process array of objects with filtering:

```rust
use nojson::RawJson;

let json = RawJson::parse(r#"[
    {"name": "Alice", "active": true},
    {"name": "Bob", "active": false},
    {"name": "Carol", "active": true}
]"#)?;

let active_names: Vec<String> = json.value().to_array()?
    .filter_map(|item| {
        let active: bool = item.to_member("active")
            .ok()?
            .required()
            .ok()?
            .try_into()
            .ok()?;
        
        if active {
            let name: String = item.to_member("name")
                .ok()?
                .required()
                .ok()?
                .try_into()
                .ok()?;
            Some(name)
        } else {
            None
        }
    })
    .collect();
```

## Pattern: Error Recovery

Gracefully handle parsing errors:

```rust
use nojson::RawJson;

let results: Vec<Result<String, _>> = vec![
    r#"{"value": "test1"}"#,
    r#"{"value": "test2"}"#,
    r#"invalid json"#,
]
.into_iter()
.map(|text| {
    let json = RawJson::parse(text)?;
    json.value().to_member("value")?.required()?.try_into()
})
.collect();

// Process successfully parsed items
for (i, result) in results.into_iter().enumerate() {
    match result {
        Ok(value) => println!("Item {}: {}", i, value),
        Err(e) => println!("Item {} error: {}", i, e),
    }
}
```

## Pattern: Large File Streaming

For large JSON arrays, process incrementally:

```rust
use nojson::RawJson;

let json = RawJson::parse(large_array_text)?;

// Don't collect into Vec - iterate directly
for (i, item) in json.value().to_array()?.enumerate() {
    let value: MyType = item.try_into()?;
    process_item(value)?;
    
    if i % 1000 == 0 {
        println!("Processed {} items", i);
    }
}
```

## Pattern: Map with Complex Keys

Use BTreeMap or HashMap with custom key parsing:

```rust
use nojson::RawJson;
use std::collections::BTreeMap;

let json = RawJson::parse(r#"{"user:1": "Alice", "user:2": "Bob"}"#)?;

let user_map: BTreeMap<u32, String> = json.value().to_object()?
    .map(|(key, value)| {
        let key_str = key.to_unquoted_string_str()?;
        let user_id: u32 = key_str.strip_prefix("user:")
            .ok_or_else(|| key.invalid("Expected 'user:' prefix"))?
            .parse()
            .map_err(|e| key.invalid(e))?;
        
        let name: String = value.try_into()?;
        Ok((user_id, name))
    })
    .collect::<Result<_, _>>()?;
```

## Pattern: Schema Validation

Validate JSON against expected schema:

```rust
use nojson::{RawJson, JsonValueKind};

fn validate_user_schema(text: &str) -> Result<(), String> {
    let json = RawJson::parse(text)
        .map_err(|e| format!("Parse error: {}", e))?;
    
    let obj = json.value();
    if !obj.kind().is_object() {
        return Err("Root must be an object".to_string());
    }
    
    // Validate name field
    let name = obj.to_member("name")
        .map_err(|e| e.to_string())?
        .required()
        .map_err(|e| e.to_string())?;
    if !name.kind().is_string() {
        return Err("'name' must be a string".to_string());
    }
    
    // Validate age field
    let age = obj.to_member("age")
        .map_err(|e| e.to_string())?
        .required()
        .map_err(|e| e.to_string())?;
    if !age.kind().is_integer() {
        return Err("'age' must be an integer".to_string());
    }
    
    Ok(())
}
```
