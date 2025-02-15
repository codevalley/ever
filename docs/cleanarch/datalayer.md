# PayZapp Data Layer Architecture: Repositories and Context Services
Version 1.0

## Introduction

The data layer in PayZapp's architecture is responsible for managing data operations and implementing repository interfaces defined in the domain layer. A key aspect of this layer is its interaction with context services, which provide access to shared application state without tight coupling.

## Context Services in the Data Layer

### 1. Repository Implementation with Context Services

```dart
class BankingDirectoryRepositoryImpl implements BankingDirectoryRepository {
  final BankingDirectoryDataSource _dataSource;
  final UserContextService _userContext;

  const BankingDirectoryRepositoryImpl({
    required BankingDirectoryDataSource dataSource,
    required UserContextService userContext,
  })  : _dataSource = dataSource,
        _userContext = userContext;

  @override
  Future<List<BankProduct>> getProducts() async {
    // Use context to filter products
    final products = await _dataSource.getProducts();
    return products.where((product) => 
      product.eligibility == _userContext.currentEligibility
    ).toList();
  }
}
```

### 2. Context Service Implementation

Context services in the data layer coordinate between different data sources:

```dart
class AppUserContextService implements UserContextService {
  final UserProfileRepository _profileRepo;
  final AuthService _authService;

  @override
  EligibilityType get currentEligibility {
    final profile = _profileRepo.getCurrentProfile();
    return profile?.eligibility ?? EligibilityType.all;
  }

  @override
  Stream<EligibilityType> watchEligibility() {
    return _profileRepo.watchCurrentProfile()
        .map((profile) => profile?.eligibility ?? EligibilityType.all);
  }
}
```

## Best Practices

1. **Context Service Usage**
   - Inject context services through constructor
   - Use interfaces from domain layer
   - Handle missing context gracefully
   - Cache context values when appropriate

2. **Repository Implementation**
   - Keep context usage internal to repository
   - Use context for filtering and validation
   - Don't expose context details to data sources

3. **Data Source Design**
   - Keep data sources context-unaware
   - Pass relevant context as parameters
   - Handle default cases

## Anti-Patterns to Avoid

1. **Global State Access**
```dart
// BAD: Accessing global state
class BadRepository {
  void someOperation() {
    final eligibility = GlobalUserState.eligibility; // Don't do this!
  }
}

// GOOD: Using injected context service
class GoodRepository {
  final UserContextService _userContext;
  
  void someOperation() {
    final eligibility = _userContext.currentEligibility;
  }
}
```

2. **Context Leakage**
```dart
// BAD: Exposing context to data sources
class BadRepository {
  Future<List<Product>> getProducts() {
    return _dataSource.getProducts(_userContext); // Don't do this!
  }
}

// GOOD: Keeping context internal
class GoodRepository {
  Future<List<Product>> getProducts() {
    final products = await _dataSource.getProducts();
    return products.where((p) => 
      p.eligibility == _userContext.currentEligibility
    ).toList();
  }
}
```

## Testing

1. **Repository Tests with Context**
```dart
void main() {
  group('BankingDirectoryRepository', () {
    late BankingDirectoryRepository repository;
    late MockDataSource dataSource;
    late MockUserContextService userContext;

    setUp(() {
      dataSource = MockDataSource();
      userContext = MockUserContextService();
      repository = BankingDirectoryRepositoryImpl(
        dataSource: dataSource,
        userContext: userContext,
      );
    });

    test('filters products by eligibility', () async {
      // Arrange
      when(userContext.currentEligibility)
          .thenReturn(EligibilityType.premium);
      
      // Act
      final products = await repository.getProducts();
      
      // Assert
      expect(
        products.every((p) => p.eligibility == EligibilityType.premium),
        isTrue,
      );
    });
  });
}
```

## Version History
- 1.0: Initial version - [01 Dec 2024]