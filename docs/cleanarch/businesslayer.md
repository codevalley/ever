# PayZapp Business Layer Architecture: Repositories and Use Cases
Version 1.0

## Introduction

The business layer is the heart of PayZapp's application architecture. While other layers handle data persistence (data layer) or user interaction (presentation layer), the business layer encapsulates what PayZapp actually does - the rules, workflows, and operations that make it a payment application rather than just a data management system.

This layer consists of repositories and use cases that together form a boundary protecting business rules and domain logic from external concerns. By creating this clear separation, we ensure our business logic remains pure, testable, and independent of implementation details like databases or UI frameworks.

## Core Philosophy

### Domain-Driven Focus
The business layer thinks in terms of domain concepts, not technical implementations. For example:
- It works with `Payment` entities, not `PaymentModel` data models
- It enforces business rules like "verified users can make payments"
- It orchestrates complex workflows like "process refund"

### Clear Responsibility Separation
```dart
// Repository handles basic business-aware operations
class PaymentRepository {
  Future<Payment> createPayment(Payment payment) async {
    // Business rule: Payment amount validation
    if (payment.amount <= 0) {
      throw InvalidPaymentException('Amount must be positive');
    }
    
    final model = PaymentModel.fromDomain(payment);
    final result = await _dataSource.create(model);
    return result.toDomain();
  }
}

// Use case handles complex business workflows
class ProcessRefundUseCase {
  Future<void> execute(String paymentId) async {
    // Complex business workflow
    final payment = await _paymentRepo.getPayment(paymentId);
    if (!payment.isRefundable()) {
      throw BusinessException('Payment not eligible for refund');
    }
    
    final refund = await _refundRepo.createRefund(payment);
    await _notificationRepo.notifyRefundInitiated(refund);
    await _paymentRepo.updateStatus(paymentId, PaymentStatus.refunded);
  }
}
```

### Reactive by Default
Business operations that might change over time should be reactive:

```dart
abstract class PaymentRepository {
  // One-time operations
  Future<void> createPayment(Payment payment);
  
  // Operations that need real-time updates
  Stream<Payment> watchPayment(String id);
  Stream<List<Payment>> watchUserPayments();
}
```

## Layer Components

### 1. Domain Entities

Domain entities are pure business objects, completely unaware of persistence or UI concerns:

```dart
class Payment {
  final String id;
  final Money amount;
  final PaymentStatus status;
  final DateTime timestamp;
  final PaymentMethod method;

  const Payment({
    required this.id,
    required this.amount,
    required this.status,
    required this.timestamp,
    required this.method,
  });

  // Business rules as methods
  bool isRefundable() {
    final refundWindow = Duration(days: 30);
    return status == PaymentStatus.completed &&
           DateTime.now().difference(timestamp) <= refundWindow;
  }

  bool requiresAdditionalVerification() {
    return amount.value >= 10000 || method == PaymentMethod.internationalCard;
  }
}

// Value objects for business concepts
class Money {
  final double value;
  final String currency;

  const Money({required this.value, required this.currency});

  // Business rules
  bool isValidTransactionAmount() {
    return value > 0 && value <= 100000;
  }
}
```

### 2. Repository Interfaces

Repository interfaces define contracts for business operations:

```dart
abstract class PaymentRepository {
  // Basic CRUD with business context
  Future<Payment> createPayment(Payment payment);
  Future<void> updatePayment(Payment payment);
  Future<void> cancelPayment(String id, CancellationReason reason);
  
  // Queries
  Future<Payment?> getPayment(String id);
  Future<List<Payment>> getUserPayments();
  
  // Reactive operations
  Stream<Payment?> watchPayment(String id);
  Stream<List<Payment>> watchUserPayments();
  
  // Business-specific operations
  Future<bool> isUserEligibleForPayment(String userId, Money amount);
  Future<void> markPaymentDisputed(String id, DisputeReason reason);
}
```

### 3. Repository Implementations

Repositories implement business rules and coordinate with data sources:

```dart
class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentDataSource _paymentDataSource;
  final UserDataSource _userDataSource;
  
  const PaymentRepositoryImpl({
    required PaymentDataSource paymentDataSource,
    required UserDataSource userDataSource,
  })  : _paymentDataSource = paymentDataSource,
        _userDataSource = userDataSource;

  @override
  Future<Payment> createPayment(Payment payment) async {
    // Business validation
    if (!payment.amount.isValidTransactionAmount()) {
      throw InvalidAmountException('Amount exceeds transaction limits');
    }

    // User eligibility check
    final user = await _userDataSource.getCurrentUser();
    if (user == null || !user.isVerified) {
      throw UnauthorizedOperationException(
        'User must be verified to make payments'
      );
    }

    // Additional verifications based on amount
    if (payment.requiresAdditionalVerification()) {
      await _initiateEnhancedVerification(payment);
    }

    // Create payment through data source
    final model = PaymentModel.fromDomain(payment);
    final result = await _paymentDataSource.create(model);
    return result.toDomain();
  }

  @override
  Stream<Payment?> watchPayment(String id) {
    return _paymentDataSource
        .watch(id)
        .map((state) => state.value?.toDomain());
  }

  // Helper methods for business logic
  Future<void> _initiateEnhancedVerification(Payment payment) async {
    // Business logic for enhanced verification
  }
}
```

### 4. Use Cases

Use cases handle complex business workflows that might involve multiple repositories:

```dart
class InitiateRefundUseCase {
  final PaymentRepository _paymentRepo;
  final RefundRepository _refundRepo;
  final UserRepository _userRepo;
  final NotificationRepository _notificationRepo;

  const InitiateRefundUseCase({
    required PaymentRepository paymentRepo,
    required RefundRepository refundRepo,
    required UserRepository userRepo,
    required NotificationRepository notificationRepo,
  })  : _paymentRepo = paymentRepo,
        _refundRepo = refundRepo,
        _userRepo = userRepo,
        _notificationRepo = notificationRepo;

  Future<Refund> execute({
    required String paymentId,
    required RefundReason reason,
    String? comment,
  }) async {
    // 1. Validate refund eligibility
    final payment = await _paymentRepo.getPayment(paymentId);
    if (payment == null) {
      throw PaymentNotFoundException();
    }

    if (!payment.isRefundable()) {
      throw RefundNotAllowedException(
        'Payment is not eligible for refund'
      );
    }

    // 2. Check user permissions
    final user = await _userRepo.getCurrentUser();
    if (!await _userRepo.canInitiateRefund(user.id)) {
      throw UnauthorizedOperationException(
        'User is not authorized to initiate refunds'
      );
    }

    // 3. Create refund record
    final refund = await _refundRepo.createRefund(
      Refund(
        paymentId: paymentId,
        amount: payment.amount,
        reason: reason,
        comment: comment,
        initiatedBy: user.id,
      )
    );

    // 4. Update payment status
    await _paymentRepo.updateStatus(
      paymentId,
      PaymentStatus.refundInProgress
    );

    // 5. Notify stakeholders
    await Future.wait([
      _notificationRepo.notifyCustomerRefundInitiated(payment.customerId),
      _notificationRepo.notifyMerchantRefundInitiated(payment.merchantId),
    ]);

    return refund;
  }
}
```

### 5. Business Exceptions

Custom exceptions for business-specific errors:

```dart
// Base class for all business exceptions
abstract class BusinessException implements Exception {
  final String message;
  const BusinessException(this.message);
}

// Specific business exceptions
class PaymentValidationException extends BusinessException {
  const PaymentValidationException(String message) : super(message);
}

class UnauthorizedOperationException extends BusinessException {
  const UnauthorizedOperationException(String message) : super(message);
}

class BusinessRuleViolationException extends BusinessException {
  final String rule;
  const BusinessRuleViolationException(String message, this.rule) 
    : super(message);
}
```

## Testing Strategy

### 1. Repository Tests

```dart
void main() {
  group('PaymentRepository', () {
    late PaymentRepository repository;
    late MockPaymentDataSource paymentDataSource;
    late MockUserDataSource userDataSource;

    setUp(() {
      paymentDataSource = MockPaymentDataSource();
      userDataSource = MockUserDataSource();
      repository = PaymentRepositoryImpl(
        paymentDataSource: paymentDataSource,
        userDataSource: userDataSource,
      );
    });

    test('createPayment enforces business rules', () async {
      // Arrange
      final payment = Payment(
        amount: Money(value: 1000, currency: 'USD'),
        // ... other fields
      );
      
      when(userDataSource.getCurrentUser())
          .thenAnswer((_) async => UnverifiedUser());

      // Act & Assert
      expect(
        () => repository.createPayment(payment),
        throwsA(isA<UnauthorizedOperationException>()),
      );
    });

    test('watchPayment emits domain entities', () {
      // Arrange
      final paymentModel = PaymentModel(/* ... */);
      when(paymentDataSource.watch(any))
          .thenAnswer((_) => Stream.value(
            DataState(value: paymentModel, metadata: DataMetadata(/* ... */))
          ));

      // Act
      final stream = repository.watchPayment('123');

      // Assert
      expect(
        stream,
        emits(isA<Payment>()),
      );
    });
  });
}
```

### 2. Use Case Tests

```dart
void main() {
  group('InitiateRefundUseCase', () {
    late InitiateRefundUseCase useCase;
    late MockPaymentRepository paymentRepo;
    late MockRefundRepository refundRepo;
    late MockUserRepository userRepo;
    late MockNotificationRepository notificationRepo;

    setUp(() {
      paymentRepo = MockPaymentRepository();
      refundRepo = MockRefundRepository();
      userRepo = MockUserRepository();
      notificationRepo = MockNotificationRepository();
      
      useCase = InitiateRefundUseCase(
        paymentRepo: paymentRepo,
        refundRepo: refundRepo,
        userRepo: userRepo,
        notificationRepo: notificationRepo,
      );
    });

    test('executes refund workflow successfully', () async {
      // Arrange
      final payment = Payment(/* ... */);
      when(paymentRepo.getPayment(any))
          .thenAnswer((_) async => payment);
      when(userRepo.canInitiateRefund(any))
          .thenAnswer((_) async => true);

      // Act
      final result = await useCase.execute(
        paymentId: '123',
        reason: RefundReason.customerRequest,
      );

      // Assert
      verify(paymentRepo.updateStatus(
        '123',
        PaymentStatus.refundInProgress,
      )).called(1);
      verify(notificationRepo.notifyCustomerRefundInitiated(any)).called(1);
      verify(notificationRepo.notifyMerchantRefundInitiated(any)).called(1);
    });
  });
}
```

## Best Practices

1. **Keep Domain Entities Pure**
   - No references to data layer concepts
   - No serialization logic
   - Only business rules and behavior

2. **Repository Guidelines**
   - Handle single entity type
   - Coordinate simple multi-source operations
   - Implement basic business rules
   - Provide reactive interfaces where needed

3. **Use Case Guidelines**
   - Handle complex workflows
   - Coordinate multiple repositories
   - Implement complex business rules
   - Maintain transactional integrity

4. **Error Handling**
   - Use specific business exceptions
   - Provide meaningful error messages
   - Handle edge cases explicitly
   - Maintain audit trail where needed

## Version History
- 1.0: Initial version - [01 Dec 2024]

## Use Cases with Context Services

Use cases often need access to shared application context. Here's how to properly integrate context services:

```dart
/// Use case that requires user context
class GetUserPaymentsUseCase {
  final PaymentRepository _paymentRepo;
  final UserContextService _userContext;

  const GetUserPaymentsUseCase({
    required PaymentRepository paymentRepo,
    required UserContextService userContext,
  })  : _paymentRepo = paymentRepo,
        _userContext = userContext;

  Future<List<Payment>> execute() async {
    // Use context to get user-specific data
    if (!_userContext.isAuthenticated) {
      throw UnauthenticatedError();
    }
    return _paymentRepo.getUserPayments(_userContext.userId);
  }
}

/// Use case that requires multiple contexts
class GetEligibleProductsUseCase {
  final ProductRepository _productRepo;
  final UserContextService _userContext;
  final AppContextService _appContext;
  final FeatureFlagService _featureFlags;

  Future<List<Product>> execute() async {
    // Combine multiple contexts
    final products = await _productRepo.getProducts(
      eligibility: _userContext.currentEligibility,
      region: _appContext.currentRegion,
    );

    // Apply feature flag filtering
    if (_featureFlags.isEnabled('new_products_enabled')) {
      return products;
    } else {
      return products.where((p) => !p.isNew).toList();
    }
  }
}

### Context Service Guidelines

1. **Injection**
   - Always inject context services through constructor
   - Make them required parameters
   - Use interfaces defined in domain layer

2. **Usage**
   - Access context at execution time, not construction
   - Handle missing or invalid context gracefully
   - Consider caching context if expensive to retrieve

3. **Testing**
   ```dart
   test('should throw when user not authenticated', () {
     final mockUserContext = MockUserContextService();
     when(mockUserContext.isAuthenticated).thenReturn(false);
     
     final useCase = GetUserPaymentsUseCase(
       paymentRepo: mockRepo,
       userContext: mockUserContext,
     );
     
     expect(
       () => useCase.execute(),
       throwsA(isA<UnauthenticatedError>()),
     );
   });
   ```

### Anti-Patterns to Avoid

1. **Global State**
   ```dart
   // BAD: Using global state
   class BadUseCase {
     Future<void> execute() {
       final userId = GlobalUserState.userId; // Don't do this!
     }
   }
   
   // GOOD: Injecting context
   class GoodUseCase {
     final UserContextService _userContext;
     
     Future<void> execute() {
       final userId = _userContext.userId;
     }
   }
   ```

2. **Direct Dependencies**
   ```dart
   // BAD: Depending on concrete implementation
   class BadUseCase {
     final AppUserContextService _userContext; // Don't do this!
   }
   
   // GOOD: Depending on interface
   class GoodUseCase {
     final UserContextService _userContext;
   }
   ```

3. **Mixed Responsibilities**
   ```dart
   // BAD: Use case managing context
   class BadUseCase {
     Future<void> execute() {
       if (await checkUserEligibility()) { // Don't do this!
         // ...
       }
     }
   }
   
   // GOOD: Using context service
   class GoodUseCase {
     final UserContextService _userContext;
     
     Future<void> execute() {
       if (_userContext.currentEligibility.isEligible) {
         // ...
       }
     }
   }
   ```