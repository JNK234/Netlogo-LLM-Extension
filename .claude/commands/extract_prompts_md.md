# Extract Implementation Prompts from Plan

**Purpose**: Convert the high-level plan.md into detailed, executable implementation prompts for step-by-step development.

## Process

1. **Read and Parse plan.md**
   - Identify all major components, features, and implementation steps
   - Note dependencies between components
   - Extract any existing prompt-like sections

2. **Analyze Project Structure**
   - Check if pyproject.toml exists (determine if Python project)
   - Identify testing framework needed
   - Check for existing code structure

3. **Generate Implementation Prompts**
   - Break each plan section into small, testable implementation steps
   - Each prompt should:
     - Build on previous prompts (no orphaned code)
     - Include TDD requirements (write tests first)
     - Have clear acceptance criteria
     - Be completable in 30-60 minutes
     - End with working, tested code

4. **Create prompt_plan.md**
   ```markdown
   # Implementation Prompt Plan
   
   - [ ] **Prompt 1: Project Setup & Basic Structure**
     - Prerequisites: None
     - Creates: pyproject.toml, basic project structure, initial tests
     - Tests: Project builds and basic imports work
   
   - [ ] **Prompt 2: [Next Component]**
     - Prerequisites: Prompt 1 completed
     - Creates: [specific files/functionality]
     - Tests: [specific test requirements]
   
   [Continue for each implementation step...]
   ```

5. **Validation**
   - Ensure each prompt builds incrementally on previous ones
   - Verify no implementation gaps or jumps
   - Confirm all prompts together will complete the full plan
   - Check that final prompt integrates everything into working system

6. **Integration Check**
   - Cross-reference with todo.md to avoid duplication
   - Link related GitHub issues to specific prompts
   - Mark prompt_plan.md as ready for @do-prompt-plan.md

## Output Format

The prompt_plan.md file should use this exact format for compatibility with @do-prompt-plan.md:

```markdown
# Implementation Prompt Plan

## Project: [Project Name]
Generated from: plan.md
Date: [Current Date]

---

- [ ] **Prompt 1: [Title]**
  ```
  [Detailed implementation instructions for LLM]
  
  Prerequisites:
  - [List any previous prompts that must be completed]
  
  Implementation Steps:
  1. Write failing tests for [specific functionality]
  2. Implement minimal code to pass tests
  3. Refactor and improve
  4. Verify integration with existing code
  
  Expected Outputs:
  - [List specific files to be created/modified]
  - [List tests that should pass]
  
  Acceptance Criteria:
  - [ ] All tests pass
  - [ ] Code follows project conventions
  - [ ] Documentation updated if needed
  - [ ] Changes committed with clear message
  ```

- [ ] **Prompt 2: [Title]**
  ```
  [Next implementation instructions...]
  ```

[Continue for all implementation steps...]

---

## Status
- Total Prompts: [X]
- Completed: [Y] 
- Remaining: [Z]
```

## Notes for Implementer

- Each prompt should be self-contained but build on previous work
- Follow TDD: tests first, then minimal implementation, then refactor
- Maintain the "no big jumps" principle from the original plan
- Ensure every prompt ends with working, tested, integrated code
- Use the project's established patterns and conventions
- Reference the original plan.md for context when needed