#!/usr/bin/env python3
"""
AAB to APK Converter using Google Bundletool

This script wraps Google's bundletool to convert Android App Bundle (.aab) files
to APK files with signing support. Signing information is read from a properties file.

Requirements:
- Java Runtime Environment (JRE) installed
- Google bundletool JAR file (e.g., bundletool-all-1.18.1.jar)
- Android keystore file for signing

Usage:
    python aab_to_apk.py --aab input.aab --output output.apk --bundletool bundletool-all-1.18.1.jar --signing signing.properties

Properties file format:
    release.keystore=path/to/keystore.jks
    keystore.password=your_keystore_password
    key.alias=your_key_alias
    key.password=your_key_password
"""

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

# Default configuration - modify these values as needed
DEFAULT_CONFIG = {
    'aab_file': 'app.aab',
    'output_file': 'app-universal.apk', 
    'bundletool_jar': 'bundletool-all-1.18.1.jar',
    'signing_properties': 'signing.properties'
}


class BundletoolWrapper:
    def __init__(self, bundletool_path):
        self.bundletool_path = Path(bundletool_path)
        self.java_cmd = self._find_java()
        
    def _find_java(self):
        """Find Java executable in system PATH or JAVA_HOME"""
        # Try java command directly
        try:
            subprocess.run(['java', '-version'], 
                         capture_output=True, check=True)
            return 'java'
        except (subprocess.CalledProcessError, FileNotFoundError):
            pass
        
        # Try JAVA_HOME environment variable
        java_home = os.environ.get('JAVA_HOME')
        if java_home:
            java_exe = Path(java_home) / 'bin' / 'java'
            if java_exe.exists():
                return str(java_exe)
        
        raise RuntimeError("Java not found. Please install Java or set JAVA_HOME environment variable.")
    
    def _read_signing_properties(self, properties_file):
        """Read signing properties from file"""
        properties = {}
        try:
            with open(properties_file, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        key, value = line.split('=', 1)
                        key = key.strip()
                        value = value.strip()
                        
                        # Handle escaped paths (especially for Windows paths)
                        # Convert escaped backslashes to regular backslashes
                        if key == 'release.keystore':
                            # Unescape common escape sequences in file paths
                            value = value.replace('\\\\', '\\')
                            value = value.replace('\\:', ':')
                            # Handle the specific case of C\:\\ -> C:\
                            # value = value.replace('C\\:', 'C:')
                            # More general approach: decode escape sequences
                            try:
                                # Try to decode as if it were a Python string literal
                                value = value.encode().decode('unicode_escape')
                            except (UnicodeDecodeError, UnicodeError):
                                # If decoding fails, use the value as-is
                                pass
                        
                        properties[key] = value
        except FileNotFoundError:
            raise FileNotFoundError(f"Properties file not found: {properties_file}")
        except Exception as e:
            raise RuntimeError(f"Error reading properties file: {e}")
        
        # Validate required properties
        required_keys = ['release.keystore', 'keystore.password', 'key.alias', 'key.password']
        missing_keys = [key for key in required_keys if key not in properties]
        if missing_keys:
            raise ValueError(f"Missing required properties: {', '.join(missing_keys)}")
        
        return properties
    
    def _validate_inputs(self, aab_file, output_file, signing_properties):
        """Validate input files and parameters"""
        # Check AAB file exists
        if not Path(aab_file).exists():
            raise FileNotFoundError(f"AAB file not found: {aab_file}")
        
        # Check bundletool exists
        if not self.bundletool_path.exists():
            raise FileNotFoundError(f"Bundletool JAR not found: {self.bundletool_path}")
        
        # Check keystore exists
        keystore_path = signing_properties['release.keystore']
        if not Path(keystore_path).exists():
            raise FileNotFoundError(f"Keystore file not found: {keystore_path}")
        
        # Create output directory if it doesn't exist
        output_path = Path(output_file)
        output_path.parent.mkdir(parents=True, exist_ok=True)
    
    def convert_aab_to_apk(self, aab_file, output_file, signing_properties_file):
        """Convert AAB to APK with signing"""
        print(f"Converting {aab_file} to {output_file}...")
        
        # Read signing properties
        signing_props = self._read_signing_properties(signing_properties_file)
        
        # Validate inputs
        self._validate_inputs(aab_file, output_file, signing_props)
        
        # Create temporary directory for intermediate files
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_apks = Path(temp_dir) / "temp.apks"
            
            # Step 1: Generate universal APK set
            print("Step 1: Generating universal APK set...")
            build_cmd = [
                self.java_cmd, '-jar', str(self.bundletool_path),
                'build-apks',
                '--bundle', str(aab_file),
                '--output', str(temp_apks),
                '--mode', 'universal',
                '--ks', signing_props['release.keystore'],
                '--ks-pass', f"pass:{signing_props['keystore.password']}",
                '--ks-key-alias', signing_props['key.alias'],
                '--key-pass', f"pass:{signing_props['key.password']}"
            ]
            
            try:
                result = subprocess.run(build_cmd, capture_output=True, text=True, check=True)
                print("✓ Universal APK set generated successfully")
            except subprocess.CalledProcessError as e:
                print(f"Error generating APK set: {e}")
                print(f"Command output: {e.stdout}")
                print(f"Command error: {e.stderr}")
                raise
            
            # Step 2: Extract universal APK
            print("Step 2: Extracting universal APK...")
            extract_cmd = [
                self.java_cmd, '-jar', str(self.bundletool_path),
                'extract-apks',
                '--apks', str(temp_apks),
                '--output-dir', temp_dir,
                '--device-spec', self._create_device_spec(temp_dir)
            ]
            
            try:
                result = subprocess.run(extract_cmd, capture_output=True, text=True, check=True)
                print("✓ Universal APK extracted successfully")
            except subprocess.CalledProcessError as e:
                print(f"Error extracting APK: {e}")
                print(f"Command output: {e.stdout}")
                print(f"Command error: {e.stderr}")
                raise
            
            # Step 3: Copy the universal APK to output location
            universal_apk = Path(temp_dir) / "universal.apk"
            if universal_apk.exists():
                import shutil
                shutil.copy2(universal_apk, output_file)
                print(f"✓ APK saved to: {output_file}")
            else:
                raise RuntimeError("Universal APK not found after extraction")
    
    def _create_device_spec(self, temp_dir):
        """Create a device specification file for universal APK extraction"""
        device_spec_path = Path(temp_dir) / "device_spec.json"
        device_spec_content = """{
  "supportedAbis": ["arm64-v8a"],
  "supportedLocales": ["en"],
  "screenDensity": 480,
  "sdkVersion": 34
}"""
        
        with open(device_spec_path, 'w', encoding='utf-8') as f:
            f.write(device_spec_content)
        
        return str(device_spec_path)


def main():
    parser = argparse.ArgumentParser(
        description='Convert Android App Bundle (.aab) to APK with signing',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    parser.add_argument('--aab', default=DEFAULT_CONFIG['aab_file'],
                       help=f'Path to input AAB file (default: {DEFAULT_CONFIG["aab_file"]})')
    parser.add_argument('--output', default=DEFAULT_CONFIG['output_file'],
                       help=f'Path to output APK file (default: {DEFAULT_CONFIG["output_file"]})')
    parser.add_argument('--bundletool', default=DEFAULT_CONFIG['bundletool_jar'],
                       help=f'Path to bundletool JAR file (default: {DEFAULT_CONFIG["bundletool_jar"]})')
    parser.add_argument('--signing', default=DEFAULT_CONFIG['signing_properties'],
                       help=f'Path to signing properties file (default: {DEFAULT_CONFIG["signing_properties"]})')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Enable verbose output')
    
    args = parser.parse_args()
    
    try:
        # Create bundletool wrapper
        wrapper = BundletoolWrapper(args.bundletool)
        
        # Convert AAB to APK
        wrapper.convert_aab_to_apk(args.aab, args.output, args.signing)
        
        print(f"\n🎉 Successfully converted {args.aab} to {args.output}")
        
    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
