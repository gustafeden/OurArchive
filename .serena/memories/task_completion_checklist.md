# Task Completion Checklist

## Before Marking Task Complete

1. **Compilation Check (MANDATORY)**
   - Run `fvm flutter analyze`
   - Verify NO compilation errors
   - Fix any errors before claiming completion

2. **Testing**
   - Use `fvm flutter test` (never `dart test`)
   - Verify affected tests pass

3. **Code Quality**
   - Follow existing code patterns
   - Maintain separation of concerns (models, services, repositories, UI)
   - Use Riverpod for state management

## Critical Rule
**Code MUST compile before marking a task as complete**
A task is NOT complete if the code doesn't compile.
