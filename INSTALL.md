# Installing the LLM Extension

## Installation Steps

### 1. Build the Extension

First, build the extension (see `BUILD.md`):

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
sbt clean assembly
```

### 2. Create Extension Folder

Create the `llm` folder in your NetLogo extensions directory:

```bash
mkdir -p "/Applications/NetLogo 7.0.0/extensions/llm"
```

**Note**: Adjust the path based on your NetLogo installation location.

### 3. Copy the JAR File

Copy `llm.jar` to the extension folder:

```bash
cp target/scala-3.7.0/llm.jar "/Applications/NetLogo 7.0.0/extensions/llm/"
```

## Verify Installation

### 1. Open NetLogo

Launch NetLogo 7.0.0 (or newer)

### 2. Test the Extension

Open the Command Center and type:

```netlogo
extensions [llm]
```

If no error appears, the extension is installed correctly.

## Using the Extension

### 1. Create a Config File

Create a `config.txt` file next to your NetLogo model with your API keys:

```
provider = openai
api_key = sk-your-api-key-here
model = gpt-4o
temperature = 0.7
max_tokens = 500
```

See `demos/config-reference.txt` for all options.

### 2. Load Config in Your Model

In your NetLogo code:

```netlogo
extensions [llm]

to setup
  llm:load-config "config.txt"
end

to test-llm
  let response llm:chat "Hello, what is 2+2?"
  print response
end
```

### 3. Run Your Model

Click Setup, then run `test-llm` from the Command Center.

## Installation Locations

**macOS:**
- `/Applications/NetLogo 7.0.0/extensions/llm/`

**Windows:**
- `C:\Program Files\NetLogo 7.0.0\extensions\llm\`

**Linux:**
- `/usr/local/NetLogo-7.0.0/extensions/llm/`

## Troubleshooting

**Problem**: "Extension llm not found"
**Solution**: Check that you have:
- Created the folder: `extensions/llm/`
- Copied the file: `extensions/llm/llm.jar`

**Problem**: "NoClassDefFoundError: ujson/Value"
**Solution**: You're using an old JAR. Rebuild with:
```bash
sbt clean assembly
```

**Problem**: Config file not found
**Solution**: Make sure `config.txt` is in the same folder as your `.nlogo` file, or use the full path:
```netlogo
llm:load-config "/full/path/to/config.txt"
```
