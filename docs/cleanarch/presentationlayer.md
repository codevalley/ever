# PayZapp Presentation Layer Architecture
Version 1.0

## Introduction

The presentation layer in PayZapp's Flutter application is designed to enable rapid UI development while maintaining clean architecture principles. This document explains how UI developers can work efficiently and independently, while ensuring their code naturally fits into the larger architectural picture.

## Core Principles

### 1. Independent UI Development
UI developers can build and refine screens without waiting for backend implementations by using mock data sources. This independence is achieved through our clean architecture's dependency injection system.

### 2. State-Based UI
Rather than managing loading states and error handling manually, our UI reacts to state changes from the business layer. This aligns with Flutter's reactive nature and our no-loader philosophy.

### 3. Platform Agnostic Design
While supporting platform-specific features, our core UI architecture remains platform-agnostic, enabling consistent behavior across Android, iOS, and web platforms.

## Implementation Structure

```
lib/
├── presentation/
│   ├── screens/
│   │   └── payment/
│   │       ├── payment_screen.dart
│   │       ├── payment_view_model.dart
│   │       └── widgets/
│   │           ├── payment_amount_input.dart
│   │           └── payment_method_selector.dart
│   ├── common/
│   │   ├── widgets/
│   │   │   ├── pz_button.dart
│   │   │   └── pz_text_field.dart
│   │   └── theme/
│   │       ├── colors.dart
│   │       └── typography.dart
│   └── utils/
│       └── platform_utils.dart
```

## Screen Development Workflow

Let's walk through creating a new payment screen to illustrate the development workflow:

### 1. Define Screen State

```dart
// States that UI can be in
sealed class PaymentScreenState {
  const PaymentScreenState();
}

class PaymentInitial extends PaymentScreenState {
  final List<PaymentMethod> availableMethods;
  const PaymentInitial({required this.availableMethods});
}

class PaymentInProgress extends PaymentScreenState {
  final PaymentMethod selectedMethod;
  final double amount;
  const PaymentInProgress({
    required this.selectedMethod,
    required this.amount,
  });
}

class PaymentSuccess extends PaymentScreenState {
  final String transactionId;
  const PaymentSuccess({required this.transactionId});
}
```

### 2. Create ViewModel

```dart
class PaymentViewModel extends ChangeNotifier {
  final PaymentRepository _paymentRepository;
  
  PaymentScreenState _state = PaymentInitial(
    availableMethods: PaymentMethod.values,
  );
  PaymentScreenState get state => _state;

  // During development, use mock repository
  PaymentViewModel({
    PaymentRepository? paymentRepository,
  }) : _paymentRepository = paymentRepository ?? MockPaymentRepository();

  // UI events
  Future<void> initiatePayment({
    required double amount,
    required PaymentMethod method,
  }) async {
    try {
      _state = PaymentInProgress(
        selectedMethod: method,
        amount: amount,
      );
      notifyListeners();

      final payment = await _paymentRepository.createPayment(
        Payment(
          amount: Money(value: amount, currency: 'INR'),
          method: method,
          timestamp: DateTime.now(),
        ),
      );

      _state = PaymentSuccess(transactionId: payment.id);
      notifyListeners();
    } catch (e) {
      // Handle errors
    }
  }
}
```

### 3. Create Screen Widget

```dart
class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PaymentViewModel(),
      child: const PaymentScreenContent(),
    );
  }
}

class PaymentScreenContent extends StatelessWidget {
  const PaymentScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to state changes
    final state = context.watch<PaymentViewModel>().state;

    return Scaffold(
      appBar: AppBar(title: const Text('Make Payment')),
      body: switch (state) {
        PaymentInitial(:final availableMethods) => PaymentInitialView(
          methods: availableMethods,
          onPaymentInitiated: (amount, method) {
            context.read<PaymentViewModel>().initiatePayment(
              amount: amount,
              method: method,
            );
          },
        ),
        PaymentInProgress(:final amount, :final selectedMethod) => 
          PaymentProgressView(
            amount: amount,
            method: selectedMethod,
          ),
        PaymentSuccess(:final transactionId) => PaymentSuccessView(
          transactionId: transactionId,
        ),
      },
    );
  }
}
```

### 4. Mock Implementation for Development

```dart
class MockPaymentRepository implements PaymentRepository {
  @override
  Future<Payment> createPayment(Payment payment) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    return Payment(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      amount: payment.amount,
      method: payment.method,
      status: PaymentStatus.completed,
      timestamp: DateTime.now(),
    );
  }

  @override
  Stream<Payment?> watchPayment(String id) {
    // Return mock payment updates
    return Stream.periodic(
      const Duration(seconds: 1),
      (_) => Payment(
        id: id,
        amount: Money(value: 1000, currency: 'INR'),
        method: PaymentMethod.upi,
        status: PaymentStatus.completed,
        timestamp: DateTime.now(),
      ),
    );
  }
}
```

## Platform-Specific Features

Handle platform-specific features while maintaining clean architecture:

```dart
// Platform capability detection
class PlatformCapabilities {
  static bool get hasDynamicIsland => 
    Platform.isIOS && DeviceInfo.supportsFeature('dynamic_island');
  
  static bool get hasNotificationDotSupport =>
    Platform.isAndroid && DeviceInfo.androidVersion >= 26;
}

// Platform-specific widget
class PaymentStatusIndicator extends StatelessWidget {
  final PaymentStatus status;

  const PaymentStatusIndicator({
    required this.status,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformCapabilities.hasDynamicIsland) {
      return DynamicIslandPaymentStatus(status: status);
    }
    
    if (PlatformCapabilities.hasNotificationDotSupport) {
      return NotificationDotPaymentStatus(status: status);
    }
    
    return DefaultPaymentStatus(status: status);
  }
}
```

## Theming and Styling

Maintain consistent styling through theme system:

```dart
// Theme extension for custom properties
class PayZappTheme extends ThemeExtension<PayZappTheme> {
  final Color primaryButtonBackground;
  final Color secondaryButtonBackground;
  final TextStyle headerTextStyle;

  const PayZappTheme({
    required this.primaryButtonBackground,
    required this.secondaryButtonBackground,
    required this.headerTextStyle,
  });

  // Theme extension methods...
}

// Usage in widgets
class PZButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final ButtonType type;

  const PZButton({
    required this.text,
    required this.onPressed,
    this.type = ButtonType.primary,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<PayZappTheme>()!;
    
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: type == ButtonType.primary
          ? theme.primaryButtonBackground
          : theme.secondaryButtonBackground,
      ),
      child: Text(text),
    );
  }
}
```

## State Management Guidelines

1. **Local State**
   - Use `setState` for simple widget-level state
   - Keep state close to where it's used
   - Avoid passing state management too high up the tree

```dart
class PaymentAmountInput extends StatefulWidget {
  final ValueChanged<double> onAmountChanged;
  
  const PaymentAmountInput({
    required this.onAmountChanged,
    super.key,
  });

  @override
  State<PaymentAmountInput> createState() => _PaymentAmountInputState();
}

class _PaymentAmountInputState extends State<PaymentAmountInput> {
  String _amount = '';

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: (value) {
        setState(() => _amount = value);
        if (value.isNotEmpty) {
          widget.onAmountChanged(double.parse(value));
        }
      },
      decoration: InputDecoration(
        errorText: _validateAmount(_amount),
      ),
    );
  }
}
```

2. **Screen-Level State**
   - Use ViewModel pattern for screen-level state
   - Keep business logic in ViewModel
   - Make UI react to state changes

3. **App-Level State**
   - Use dependency injection for sharing repositories
   - Consider using providers for global state
   - Keep global state minimal

## Testing Strategy

### 1. Widget Tests

```dart
void main() {
  group('PaymentScreen', () {
    testWidgets('shows available payment methods', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentScreen(),
        ),
      );

      expect(find.text('UPI'), findsOneWidget);
      expect(find.text('Card'), findsOneWidget);
    });

    testWidgets('initiates payment on button press', (tester) async {
      final mockViewModel = MockPaymentViewModel();
      
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: mockViewModel,
            child: PaymentScreen(),
          ),
        ),
      );

      await tester.enterText(
        find.byType(PaymentAmountInput),
        '1000',
      );
      await tester.tap(find.text('Pay Now'));

      verify(mockViewModel.initiatePayment(
        amount: 1000,
        method: PaymentMethod.upi,
      )).called(1);
    });
  });
}
```

### 2. Integration Tests

```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Payment Flow', () {
    testWidgets('complete payment flow', (tester) async {
      await tester.pumpWidget(PayZappApp());

      // Navigate to payment screen
      await tester.tap(find.text('New Payment'));
      await tester.pumpAndSettle();

      // Enter payment details
      await tester.enterText(
        find.byType(PaymentAmountInput),
        '1000',
      );
      await tester.tap(find.text('UPI'));
      await tester.tap(find.text('Pay Now'));

      // Verify success
      await tester.pumpAndSettle();
      expect(find.text('Payment Successful'), findsOneWidget);
    });
  });
}
```

## Development Tips

1. **Start with Mock Data**
   - Use mock repositories during development
   - Create realistic mock data
   - Simulate different states and errors

2. **Component-First Development**
   - Build and test small components first
   - Compose larger screens from tested components
   - Use storybook-style development for components

3. **State Management**
   - Start with simple state management
   - Refactor to more complex solutions when needed
   - Keep state close to where it's used

4. **Platform Considerations**
   - Test on both Android and iOS regularly
   - Use platform-specific widgets when needed
   - Maintain consistent behavior across platforms

## Version History
- 1.0: Initial version - [01 Dec 2024]