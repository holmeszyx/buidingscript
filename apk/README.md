# AAB to APK Converter

A Python script that wraps Google's bundletool to convert Android App Bundle (.aab) files to APK files with signing support.

## Requirements

- Python 3.6+
- Java Runtime Environment (JRE) 8 or higher
- Google bundletool JAR file (download from [GitHub releases](https://github.com/google/bundletool/releases))
- Android keystore file for signing

## Setup

1. Download bundletool JAR file (e.g., `bundletool-all-1.18.1.jar`)
2. Create a signing properties file based on `signing.properties.example`
3. Ensure Java is installed and accessible via `java` command or `JAVA_HOME`

## Usage

```bash
python aab_to_apk.py --aab input.aab --output output.apk --bundletool bundletool-all-1.18.1.jar --signing signing.properties
```

### Arguments

- `--aab`: Path to input AAB file
- `--output`: Path to output APK file
- `--bundletool`: Path to bundletool JAR file
- `--signing`: Path to signing properties file
- `--verbose` or `-v`: Enable verbose output (optional)

### Example

```bash
python aab_to_apk.py \
    --aab myapp.aab \
    --output myapp-universal.apk \
    --bundletool bundletool-all-1.18.1.jar \
    --signing signing.properties
```

## Signing Properties File

Create a `signing.properties` file with the following format:

```properties
release.keystore=path/to/your/keystore.jks
keystore.password=your_keystore_password
key.alias=your_key_alias
key.password=your_key_password
```

## Features

- ✅ Converts AAB to universal APK
- ✅ Signs APK with your keystore
- ✅ Uses only Python built-in libraries
- ✅ Automatic Java detection
- ✅ Input validation and error handling
- ✅ Cross-platform compatibility

## Notes

- The script generates a universal APK that works on all device architectures
- Temporary files are automatically cleaned up
- The output APK is ready for distribution
