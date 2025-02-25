# Ever - Task and Note Management System

A reactive task and note management system built with clean architecture principles.

## Architecture Overview

Ever follows a clean architecture pattern with three main layers:

1. **Domain Layer**
   - Entities (Task, Note, User)
   - Use Cases (business logic)
   - Repository Interfaces
   - Domain Events

2. **Data Layer**
   - Repositories (implementation)
   - Data Sources
   - Models
   - API Integration

3. **Presentation Layer**
   - Presenters
   - UI Components
   - State Management
   - Event Handling

## Key Features

- Reactive data flow with event-driven updates
- Clean separation of concerns
- Robust error handling and retry mechanisms
- Circuit breaker pattern for API resilience
- Comprehensive state management

## Development Guidelines

### Adding New Features

1. Define domain entities and interfaces
2. Implement data layer components
3. Create use cases for business logic
4. Add presentation layer components
5. Update documentation

See `docs/guides/adding_features.md` for detailed steps.

### Architecture Guidelines

- Follow clean architecture principles
- Maintain layer separation
- Use reactive patterns
- Handle errors gracefully

For more details, see:
- `docs/guides/domain-arch.md`
- `docs/guides/presentation-architecture.md`
- `docs/guides/reactive-architecture.md`

## Getting Started

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```

## Documentation

Comprehensive documentation is available in the `docs/guides` directory:

- Domain Architecture (`domain-arch.md`)
- Presentation Architecture (`presentation-architecture.md`)
- Reactive Architecture (`reactive-architecture.md`)
- Adding Features Guide (`adding_features.md`)

## Contributing

1. Follow the architecture guidelines
2. Maintain test coverage
3. Update documentation
4. Submit pull requests

## License

[Add your license information here]
