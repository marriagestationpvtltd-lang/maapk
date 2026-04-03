# Smart Scrolling Implementation Guide

## Overview

Smart scrolling has been implemented across all registration pages to automatically scroll fields into view when they receive focus. This eliminates the need for users to manually scroll while filling out long forms.

## Features

- **Auto-scroll on focus**: When a user taps on a field, the page automatically scrolls to position that field optimally on the screen
- **Keyboard-aware**: Takes keyboard height into account and ensures the focused field remains visible above the keyboard
- **Smooth animations**: Uses smooth scroll animations (300ms with easeInOut curve) for a polished user experience
- **Customizable positioning**: Fields are positioned at 25% from the top of the viewport for comfortable viewing
- **Error scrolling**: Can scroll to the first error field for better validation feedback

## Implementation Steps

### Step 1: Import the Smart Scroll Behavior

Add the import to your signup screen:

```dart
import '../../ReUsable/smart_scroll_behavior.dart';
```

### Step 2: Add the Mixin

Update your State class to include the `SmartScrollBehavior` mixin:

```dart
class _YourPageState extends State<YourPage>
    with SingleTickerProviderStateMixin, SmartScrollBehavior {
  // ...
}
```

### Step 3: Create Focus Nodes and Global Keys

For each text field that should support smart scrolling, create a FocusNode and GlobalKey:

```dart
// Focus nodes for smart scrolling
late FocusNode _firstNameFocus;
late FocusNode _lastNameFocus;
late FocusNode _emailFocus;

// Global keys for smart scrolling
final GlobalKey _firstNameKey = GlobalKey();
final GlobalKey _lastNameKey = GlobalKey();
final GlobalKey _emailKey = GlobalKey();
```

### Step 4: Initialize and Register Fields

In your `initState` method, initialize the focus nodes and register them with the smart scroll behavior:

```dart
@override
void initState() {
  super.initState();

  // Initialize focus nodes
  _firstNameFocus = FocusNode();
  _lastNameFocus = FocusNode();
  _emailFocus = FocusNode();

  // Register fields for smart scrolling
  registerField(_firstNameFocus, _firstNameKey);
  registerField(_lastNameFocus, _lastNameKey);
  registerField(_emailFocus, _emailKey);

  // ... rest of initialization
}
```

### Step 5: Dispose Focus Nodes

Don't forget to dispose the focus nodes in your `dispose` method:

```dart
@override
void dispose() {
  // Dispose focus nodes
  _firstNameFocus.dispose();
  _lastNameFocus.dispose();
  _emailFocus.dispose();

  // ... rest of disposal
  super.dispose();
}
```

### Step 6: Pass ScrollController to RegistrationStepContainer

Update your `RegistrationStepContainer` to use the scroll controller from the mixin:

```dart
RegistrationStepContainer(
  scrollController: scrollController,  // Add this line
  onContinue: _submitForm,
  onBack: () => Navigator.pop(context),
  // ... other properties
  child: Column(
    // ... your form fields
  ),
)
```

### Step 7: Wrap Fields with Keys and Add FocusNodes

For each field, wrap it in a Container with the GlobalKey and add the focusNode parameter:

```dart
Container(
  key: _firstNameKey,
  child: EnhancedTextField(
    label: 'First Name',
    controller: _firstNameController,
    focusNode: _firstNameFocus,  // Add this line
    // ... other properties
  ),
)
```

## Complete Example

Here's a complete minimal example:

```dart
import 'package:flutter/material.dart';
import '../../ReUsable/smart_scroll_behavior.dart';
import '../../ReUsable/registration_progress.dart';
import '../../ReUsable/enhanced_form_fields.dart';

class MyRegistrationPage extends StatefulWidget {
  const MyRegistrationPage({Key? key}) : super(key: key);

  @override
  State<MyRegistrationPage> createState() => _MyRegistrationPageState();
}

class _MyRegistrationPageState extends State<MyRegistrationPage>
    with SmartScrollBehavior {

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _emailController;

  // Focus nodes
  late FocusNode _nameFocus;
  late FocusNode _emailFocus;

  // Global keys
  final GlobalKey _nameKey = GlobalKey();
  final GlobalKey _emailKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController();
    _emailController = TextEditingController();

    _nameFocus = FocusNode();
    _emailFocus = FocusNode();

    registerField(_nameFocus, _nameKey);
    registerField(_emailFocus, _emailKey);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RegistrationStepContainer(
          scrollController: scrollController,
          onContinue: _submit,
          child: Column(
            children: [
              Container(
                key: _nameKey,
                child: EnhancedTextField(
                  label: 'Name',
                  controller: _nameController,
                  focusNode: _nameFocus,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                key: _emailKey,
                child: EnhancedTextField(
                  label: 'Email',
                  controller: _emailController,
                  focusNode: _emailFocus,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    // Handle form submission
  }
}
```

## Advanced Features

### Scroll to First Error

You can use the `scrollToFirstError` method to automatically scroll to the first field with an error:

```dart
void _validateForm() {
  List<FocusNode> errorFields = [];

  if (_fieldErrors['firstName'] != null) {
    errorFields.add(_firstNameFocus);
  }
  if (_fieldErrors['email'] != null) {
    errorFields.add(_emailFocus);
  }

  if (errorFields.isNotEmpty) {
    scrollToFirstError(errorFields);
  }
}
```

### Manual Scrolling

You can also manually trigger scrolling:

```dart
// Scroll to top
scrollToTop();

// Scroll to bottom
scrollToBottom();

// Scroll to specific position
scrollToPosition(500.0);
```

## Technical Details

### How It Works

1. The `SmartScrollBehavior` mixin provides a `ScrollController` that is shared with the `RegistrationStepContainer`
2. When you register a field using `registerField()`, it adds a listener to the FocusNode
3. When the field gains focus, the listener calculates the optimal scroll position based on:
   - Field position on screen
   - Keyboard height (if visible)
   - Viewport dimensions
4. The page smoothly scrolls to position the field at 25% from the top of the visible area

### Performance

- The scrolling logic runs in a post-frame callback to ensure proper layout calculation
- Scroll only occurs if the field is not already fully visible
- Smooth 300ms animations prevent jarring movements

## Troubleshooting

### Field not scrolling

- Ensure you've registered the field with `registerField(focusNode, globalKey)`
- Check that the focusNode is passed to the TextField/EnhancedTextField
- Verify that the scrollController is passed to RegistrationStepContainer

### Scroll position is incorrect

- Make sure the GlobalKey is wrapped around the complete field (including label and error text)
- Check that the field has a fixed height or is properly constrained

### Multiple fields triggering at once

- Only one field should have focus at a time
- Check for programmatic focus changes that might conflict

## Files Modified

- `/msfinal/lib/ReUsable/smart_scroll_behavior.dart` - Core smart scrolling mixin
- `/msfinal/lib/ReUsable/registration_progress.dart` - Updated RegistrationStepContainer to support scrollController
- `/msfinal/lib/Auth/Screen/SignupScreen1.dart` - Example implementation in YourDetailsPage

## Next Steps

Apply this pattern to all remaining registration screens:
- signupscreen2.dart - PersonalDetailsPage
- signupscreen3.dart - CommunityDetailsPage
- signupscreen4.dart - LivingStatusPage
- signupscreen5.dart - FamilyDetailsPage
- signupscreen6.dart - EducationCareerPage
- signupscreen7-10.dart - Additional registration pages
