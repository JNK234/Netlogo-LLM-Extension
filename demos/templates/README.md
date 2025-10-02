# LLM Extension Templates

This directory contains YAML template files for structured prompting with the NetLogo LLM Extension.

## Available Templates

### Basic Templates
- `simple-template.yaml` - Basic template with task, input, and context variables
  - Use for general purpose prompting
  - Variables: `{task}`, `{input}`, `{context}`

### Evolution Templates
- `code-evolution-template.yaml` - For evolving agent behavior code
  - Variables: `{current_code}`, `{code_history}`, `{objective}`, `{constraints}`, `{performance_notes}`
- `movement-evolution.yaml` - Specific template for movement behavior evolution
  - Optimized for NetLogo movement commands

### Analysis Templates
- `analysis-template.yaml` - For agent environmental analysis
  - Variables: `{environment_state}`, `{agent_goals}`, `{observations}`
- `reasoning-template.yaml` - For complex reasoning tasks
  - Structured decision-making prompts

## Using Templates

Templates are used with the `llm:chat-with-template` primitive:

```netlogo
let result llm:chat-with-template "demos/templates/simple-template.yaml" (list
  ["task" "analyze data"]
  ["input" "sales: 100, 150, 200"]
  ["context" "quarterly review"]
)
```

## Template Structure

All templates follow this structure:
```yaml
system: "System prompt for the LLM"
template: |
  Main prompt with {variables} to be replaced
  Multi-line content supported
  {variable_name} placeholders
```

## Creating Custom Templates

1. Create a new `.yaml` file
2. Define `system` prompt (optional)
3. Define `template` with placeholders using `{variable_name}` format
4. Use `|` for multi-line templates
5. Variables are replaced at runtime from NetLogo
