# CLI UI Implementation Plan

## Project Structure

```
lib/
├── ui/
│   ├── cli/                    # CLI-specific UI implementation
│   │   ├── app.dart           # CLI app entry point
│   │   ├── commands/          # Command handlers
│   │   │   ├── base.dart      # Base command handler
│   │   │   └── user/          # User-related commands
│   │   │       ├── login.dart
│   │   │       ├── register.dart
│   │   │       ├── logout.dart
│   │   │       └── profile.dart
│   │   ├── formatters/        # Output formatters
│   │   │   ├── base.dart      # Base formatter
│   │   │   ├── error.dart     # Error message formatter
│   │   │   ├── success.dart   # Success message formatter
│   │   │   └── user.dart      # User info formatter
│   │   ├── prompts/           # Interactive prompts
│   │   │   ├── base.dart      # Base prompt
│   │   │   └── user/          # User-related prompts
│   │   │       ├── login.dart
│   │   │       └── register.dart
│   │   └── screens/           # CLI screens
│   │       ├── base.dart      # Base screen
│   │       └── user/          # User-related screens
│   │           ├── login.dart
│   │           ├── register.dart
│   │           └── profile.dart
│   └── shared/                # Shared UI components
```

## Phase 1: User Management Implementation

### 1. Core CLI Infrastructure

1. **Base Components**:
   ```dart
   // Base command handler
   abstract class CliCommand {
     final EverPresenter presenter;
     Future<void> execute(List<String> args);
   }

   // Base formatter
   abstract class OutputFormatter {
     String format(dynamic data);
   }

   // Base prompt
   abstract class CliPrompt {
     Future<String> prompt(String message);
     Future<String> promptSecret(String message);
   }
   ```

2. **CLI App Entry**:
   ```dart
   class CliApp {
     final EverPresenter presenter;
     final CommandRegistry commands;
     
     Future<void> run(List<String> args) async {
       // Parse and execute commands
     }
   }
   ```

### 2. User Commands Implementation

1. **Register Command**:
   ```dart
   class RegisterCommand extends CliCommand {
     @override
     Future<void> execute(List<String> args) async {
       final username = await promptUsername();
       await presenter.register(username);
       // Handle result via state stream
     }
   }
   ```

2. **Login Command**:
   ```dart
   class LoginCommand extends CliCommand {
     @override
     Future<void> execute(List<String> args) async {
       final secret = await promptSecret();
       await presenter.login(secret);
       // Handle result via state stream
     }
   }
   ```

3. **Logout Command**:
   ```dart
   class LogoutCommand extends CliCommand {
     @override
     Future<void> execute(List<String> args) async {
       await presenter.logout();
       // Handle result via state stream
     }
   }
   ```

### 3. State Handling

1. **State Subscription**:
   ```dart
   class CliStateHandler {
     final EverPresenter presenter;
     
     void initialize() {
       presenter.state.listen((state) {
         if (state.isLoading) {
           showSpinner();
         } else if (state.error != null) {
           showError(state.error!);
         } else if (state.currentUser != null) {
           showUserInfo(state.currentUser!);
         }
       });
     }
   }
   ```

2. **Output Formatters**:
   ```dart
   class UserFormatter extends OutputFormatter {
     String format(User user) {
       return '''
       Username: ${user.username}
       Created: ${user.createdAt}
       ''';
     }
   }
   ```

### 4. Interactive Prompts

1. **User Prompts**:
   ```dart
   class UserPrompts {
     Future<String> promptUsername() async {
       return prompt('Enter username: ');
     }
     
     Future<String> promptSecret() async {
       return promptSecret('Enter your secret: ');
     }
   }
   ```

## Implementation Plan

### Phase 1.1: Basic Infrastructure
- [✅] Create base command handler
- [✅] Implement command registry
- [✅] Add basic CLI app entry point
- [✅] Create state subscription handler
- [✅] Implement basic output formatters

### Phase 1.2: User Authentication
- [✅] Implement register command
- [✅] Add login command
- [✅] Create logout command
- [✅] Implement user prompts
- [✅] Add user info formatter
- [✅] Create authentication state handler

### Phase 1.3: User Profile
- [✅] Add profile command
- [✅] Implement profile screen
- [✅] Create profile formatter
- [✅] Add session management

### Phase 1.4: Error Handling
- [✅] Implement error formatters
- [✅] Add input validation
- [✅] Create error recovery flows
- [✅] Implement graceful exit

### Phase 1.5: Testing
- [✅] Add command tests
- [✅] Create formatter tests
- [✅] Implement prompt tests
- [✅] Add integration tests

### Additional Completed Features
- [✅] Logging system with configurable levels
- [✅] Circuit breaker implementation
- [✅] Retry logic for network operations
- [✅] Token refresh mechanism
- [✅] Interactive shell mode
- [✅] Command line argument parsing
- [✅] Progress indicators
- [✅] Error message formatting

## Usage Examples

1. **Registration**:
   ```bash
   ever register
   # Interactive prompt for username
   # Display success/error
   ```

2. **Login**:
   ```bash
   ever login
   # Interactive prompt for secret
   # Display success/error
   ```

3. **Profile**:
   ```bash
   ever profile
   # Display user information
   ```

4. **Logout**:
   ```bash
   ever logout
   # Confirm and logout
   ```

## Future Enhancements

1. **Command Line Arguments**:
   ```bash
   ever register --username john_doe
   ever login --secret mysecret123
   ```

2. **Interactive Mode**:
   ```bash
   ever
   > register
   Username: john_doe
   > login
   Secret: ****
   ```

3. **Rich Formatting**:
   - Colored output
   - Progress spinners
   - Tables for data display
   - Interactive menus

4. **Configuration**:
   - Custom prompts
   - Output format preferences
   - Saved credentials
   - Command aliases

## Testing Strategy

1. **Unit Tests**:
   - Command parsing
   - Input validation
   - Output formatting
   - State handling

2. **Integration Tests**:
   - Command execution
   - State transitions
   - Error scenarios
   - User flows

3. **Mock Tests**:
   - Presenter interactions
   - Input/output simulation
   - State updates
   - Error conditions