# Ever - CLI & Flutter App Project Guide

## Commands
- Run app: `flutter run`
- Run all tests: `flutter test`
- Run specific test: `flutter test test/path/to/test_file.dart`
- Run tests with pattern: `flutter test --name="pattern"`
- Lint: `flutter analyze`
- Format code: `dart format lib test`
- Generate models: `flutter pub run build_runner build --delete-conflicting-outputs`

## Code Style & Architecture
- **Imports**: Dart → External packages → Local imports (alphabetical within groups)
- **Naming**: snake_case (files), PascalCase (classes), camelCase (methods/vars)
- **Organization**: Properties → Constructor → Public methods → Private methods
- **Clean Architecture**: domain (entities, repos, usecases) → implementations → ui
- **Error Handling**: Domain exceptions, circuit breaker, retry policies, event-based error propagation
- **Patterns**: Repository, UseCase, Presenter, Command, Event streams
- **Reactivity**: Stream-based communication, event sourcing, BehaviorSubject for state
- **Testing**: Mockito mocks, arrange/act/assert pattern, proper subscription management
- **Documentation**: Doc comments for classes, methods and complex logic
- **Style**: Immutable entities, const constructors, dependency injection

Follow DDD principles with separate interfaces and implementations. Maintain proper stream subscription management. Use resilience patterns for network operations.