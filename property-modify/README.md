# property-modify

A simple tool to modify JAVA properties files like `local.properties`.

# Usage

## Build

```bash
go build -o gpm ./cmd
```

## Run

```bash
gpm --input local.properties --set "app.channel=google" --set "app.version=1.0.0" --rm "app.id"
```


```
Usage: gpm [options]
version: 0.0.1
  -input string
        Input property file (default "local.properties")
  -output string
        Output property file, default is the same file as input
  -rm value
        Remove property by key (can be used multiple times)
  -set value
        Set property in format 'key=value' or 'key=value#comment' (can be used multiple times)
```