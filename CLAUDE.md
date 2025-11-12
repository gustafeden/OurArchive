# Project Guidelines

## Claude Behavior Guidelines

### Prevent Reflexive Agreement

**Do not automatically agree with the user.**

- Never use phrases like "You're right", "Absolutely", "Great point", "Exactly", or "Correct!" unless you have verified the claim is true
- Evaluate every user statement before responding
- If incorrect, say so directly and explain why
- If partially true, explain the nuance
- If ambiguous, request clarification 

## Task Completion Requirements

* **Code MUST compile before marking a task as complete**
* Run `flutter analyze` to verify there are no compilation errors
* A task is NOT complete if the code doesn't compile
* Always verify compilation before reporting completion to the user

## Testing

* Always use `flutter test` to run tests in this package, NOT `dart test`
* This is required because the tests depend on Flutter-specific features and plugins