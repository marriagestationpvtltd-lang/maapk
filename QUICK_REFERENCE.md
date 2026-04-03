# Quick Reference - Adding New Features Safely

## 🚀 Quick Start (5 Minutes)

### Step 1: Create Feature Folder
```bash
mkdir -p lib/features/your_feature/{models,services,providers,screens,widgets}
```

### Step 2: Copy Template Files
Copy from `lib/features/example_feature/`:
- `models/example_model.dart` → Rename and modify
- `services/example_service.dart` → Update API endpoints
- `providers/example_provider.dart` → Adapt state logic
- Add your screens in `screens/`

### Step 3: Add Feature Flag
```dart
// lib/config/feature_flags.dart
static const bool enableYourFeature = false; // Start disabled
```

### Step 4: Register Provider
```dart
// main.dart
MultiProvider(
  providers: [
    // Existing providers...
    ChangeNotifierProvider(create: (_) => YourFeatureProvider()),
  ],
  child: const MyApp(),
)
```

### Step 5: Use in UI
```dart
import 'package:ms2026/config/feature_flags.dart';

if (FeatureFlags.enableYourFeature) {
  // Show new feature
}
```

---

## 📋 Essential Patterns

### Data Model
```dart
class YourModel {
  final String id;
  final String name;

  YourModel({required this.id, required this.name});

  factory YourModel.fromJson(Map<String, dynamic> json) {
    return YourModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
```

### API Service
```dart
import '../../../core/api/api_response.dart';

class YourService {
  final String baseUrl = 'YOUR_API_URL';

  Future<ApiResponse<List<YourModel>>> fetchData() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/endpoint'))
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = (data['items'] as List)
            .map((item) => YourModel.fromJson(item))
            .toList();
        return ApiResponse.success(items);
      } else {
        return ApiResponse.error('Failed to load');
      }
    } catch (e) {
      return ApiResponse.error('Error: ${e.toString()}');
    }
  }
}
```

### Provider
```dart
class YourProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  List<YourModel>? _data;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<YourModel> get data => _data ?? [];

  Future<void> loadData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final response = await service.fetchData();

    if (response.isSuccess) {
      _data = response.data;
    } else {
      _error = response.error;
    }

    _isLoading = false;
    notifyListeners();
  }
}
```

### Screen with All States
```dart
class YourScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Your Feature')),
      body: Consumer<YourProvider>(
        builder: (context, provider, child) {
          // Loading
          if (provider.isLoading) {
            return LoadingWidget(message: 'Loading...');
          }

          // Error
          if (provider.error != null) {
            return ErrorStateWidget(
              message: provider.error!,
              onRetry: () => provider.loadData(),
            );
          }

          // Empty
          if (provider.data.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.inbox,
              title: 'No Data',
              message: 'Nothing to show',
            );
          }

          // Success
          return ListView.builder(
            itemCount: provider.data.length,
            itemBuilder: (context, index) {
              final item = provider.data[index];
              return ListTile(title: Text(item.name));
            },
          );
        },
      ),
    );
  }
}
```

---

## 🎨 Using Existing Components

### Buttons
```dart
import 'package:ms2026/ReUsable/custom_buttons.dart';

// Primary Button
PrimaryButton(
  text: 'Submit',
  onPressed: () {},
  isLoading: false,
)

// Secondary Button
SecondaryButton(
  text: 'Cancel',
  onPressed: () {},
)
```

### Input Fields
```dart
import 'package:ms2026/ReUsable/custom_textfields.dart';

CustomTextField(
  labelText: 'Name',
  controller: controller,
  validator: (value) => value?.isEmpty == true ? 'Required' : null,
)
```

### Cards
```dart
import 'package:ms2026/ReUsable/card_widgets.dart';

AppCard(
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Text('Content'),
  ),
)
```

### Colors
```dart
import 'package:ms2026/constant/app_colors.dart';

AppColors.primary        // #F90E18 Red
AppColors.success        // Green
AppColors.error          // Red
AppColors.textPrimary    // Dark grey
AppColors.background     // Light grey
```

---

## ✅ Pre-Launch Checklist

Before enabling your feature:

### Code Quality
- [ ] No modifications to existing features
- [ ] Uses AppColors for all colors
- [ ] Uses reusable components
- [ ] Feature flag exists and is false
- [ ] Provider registered in main.dart
- [ ] All async operations have try-catch
- [ ] API calls have 30s timeout
- [ ] Null safety checks everywhere

### UI States
- [ ] Loading state implemented
- [ ] Error state with retry implemented
- [ ] Empty state implemented
- [ ] Success state works correctly

### Testing
- [ ] Works with valid data
- [ ] Handles null/empty data
- [ ] Survives network errors
- [ ] Handles slow network
- [ ] No crashes on rapid clicks
- [ ] Works after app backgrounding

### Documentation
- [ ] Code has clear comments
- [ ] Complex logic explained
- [ ] API endpoints documented

---

## 🚢 Deployment Process

### 1. Development (Day 1-3)
```bash
git checkout -b feature/your-feature
# Develop feature
git commit -m "feat: Add your feature (disabled)"
git push origin feature/your-feature
```

### 2. Code Review (Day 4-5)
- Create pull request
- Team reviews code
- Address feedback
- Merge to main

### 3. Beta Testing (Day 6-10)
```dart
// Enable for beta
static const bool enableYourFeature = true;
```
- Deploy to internal testing
- Monitor crashes
- Fix issues

### 4. Production Rollout (Day 11+)
- 10% → Day 11-12
- 25% → Day 13-14
- 50% → Day 15-16
- 100% → Day 17+

### Emergency Rollback
```dart
static const bool enableYourFeature = false;
// Push hotfix immediately
```

---

## 🐛 Common Issues & Solutions

### Issue: "Provider not found"
**Solution:** Register provider in main.dart MultiProvider

### Issue: "setState called after dispose"
**Solution:** Check `if (mounted)` before setState

### Issue: "API timeout"
**Solution:** Increase timeout or check network

### Issue: "Null pointer exception"
**Solution:** Add null checks and use `?.` operator

### Issue: "Build errors"
**Solution:** Run `flutter clean && flutter pub get`

---

## 📚 Documentation Files

1. **SAFE_FEATURE_IMPLEMENTATION_GUIDE.md** - Complete guide (1,800+ lines)
2. **IMPLEMENTATION_COMPLETE.md** - Project summary and overview
3. **This file** - Quick reference for daily use

---

## 🎯 Remember

### Golden Rules
1. ✅ Isolate new features
2. ✅ Use feature flags
3. ✅ Handle all error states
4. ✅ Test thoroughly
5. ✅ Deploy gradually

### Never Do
1. ❌ Modify existing Providers
2. ❌ Change existing APIs
3. ❌ Skip error handling
4. ❌ Forget null checks
5. ❌ Deploy without testing

---

## 🆘 Need Help?

1. Check **SAFE_FEATURE_IMPLEMENTATION_GUIDE.md**
2. Review **features/example_feature/** code
3. Look at existing features for patterns
4. Ask team for guidance

---

**Keep this file handy for quick reference!**

🚀 Happy coding!
