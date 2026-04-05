# Privacy-Aware Profile Card Design Documentation

## 🎨 Card Design Overview

मैले **3 प्रकारका card layouts** बनाएको छु, सबैमा **automatic privacy enforcement** छ।

---

## 📱 Design 1: VERTICAL CARD LAYOUT

```
┌─────────────────────────────┐
│  ┌───────────────────────┐  │
│  │                       │  │  ← Photo Section (200px height)
│  │     PROFILE PHOTO     │  │
│  │   (Clear or Blurred)  │  │
│  │                       │  │
│  │  👑 Premium  ✓ Verified│ ← Badges (only if photo clear)
│  └───────────────────────┘  │
│                             │
│  राम शर्मा, 28             │  ← Name & Age
│  💼 Software Engineer       │  ← Profession (only if clear)
│  📍 Kathmandu, Nepal        │  ← Location (only if clear)
│  📏 175 cm                  │  ← Height (only if clear)
│                             │
│  ┌───────┐  ┌───────────┐  │
│  │  ❤️   │  │ 💬 Message│  │  ← Action Buttons
│  └───────┘  └───────────┘  │
└─────────────────────────────┘

जब Photo BLURRED हुन्छ:
┌─────────────────────────────┐
│  ┌───────────────────────┐  │
│  │  ╔════════════════╗   │  │
│  │  ║  [Blurred Img] ║   │  │
│  │  ║                ║   │  │
│  │  ║   🔒 Lock      ║   │  ← Lock Icon
│  │  ║ Photo Protected║   │  ← Status Message
│  │  ╚════════════════╝   │  │
│  └───────────────────────┘  │
│                             │
│  राम शर्मा, 28             │  ← Name only
│  (Details hidden)           │  ← Other info hidden
│                             │
│  ┌─────────────────────┐   │
│  │  View Profile       │   │  ← Action Button
│  └─────────────────────┘   │
└─────────────────────────────┘
```

**Use Case:** Profile lists, search results, general listings

---

## 🎯 Design 2: GRID CARD LAYOUT

```
┌──────────────────────┐
│ ┌──────────────────┐ │
│ │                  │ │
│ │  PROFILE PHOTO   │ │  ← Photo (180px height)
│ │                  │ │
│ │  ┌──────────────┐│ │
│ │  │ राम शर्मा, 28││ │  ← Name overlay on photo
│ │  │ 📍 Kathmandu ││ │  ← Location overlay
│ │  └──────────────┘│ │
│ │      👑  ✓       │ │  ← Badges (top-right)
│ └──────────────────┘ │
│                      │
│ 🎸 Music  ⚽ Sports │  ← Interests (only if clear)
│                      │
│ ┌──────────────────┐ │
│ │  Send Request    │ │  ← Action Button
│ └──────────────────┘ │
└──────────────────────┘

जब Photo BLURRED हुन्छ:
┌──────────────────────┐
│ ┌──────────────────┐ │
│ │ [Blurred Photo]  │ │
│ │                  │ │
│ │      🔒         │ │  ← Lock Icon
│ │  Photo Protected │ │  ← Status
│ │                  │ │
│ │  (No overlay)    │ │  ← No name/location shown
│ └──────────────────┘ │
│                      │
│ (No interests shown) │  ← Interests hidden
│                      │
│ ┌──────────────────┐ │
│ │  Send Request    │ │  ← Button still visible
│ └──────────────────┘ │
└──────────────────────┘
```

**Use Case:** Premium members grid, recent members grid, responsive 2-4 column layouts

---

## ➡️ Design 3: HORIZONTAL CARD LAYOUT

```
┌────────────────────────────┐
│ ┌──────────────────┐       │
│ │                  │       │  ← Photo (140px height)
│ │  PROFILE PHOTO   │       │
│ │                  │       │
│ │ ┌──────────────┐ │       │
│ │ │ राम शर्मा    │ │       │  ← Name on photo
│ │ └──────────────┘ │       │
│ └──────────────────┘       │
│ Age 28 yrs, 175 cm         │  ← Details (only if clear)
│ 💼 Software Engineer       │
│ 📍 Kathmandu               │
│                            │
│ ┌──────────────────────┐   │
│ │  📤 Send Request     │   │  ← Action Button
│ └──────────────────────┘   │
└────────────────────────────┘
Width: 200px (for carousel)

जब Photo BLURRED हुन्छ:
┌────────────────────────────┐
│ ┌──────────────────┐       │
│ │ [Blurred Photo]  │       │
│ │                  │       │
│ │      🔒         │       │  ← Lock Icon
│ │  Photo Protected │       │
│ │                  │       │
│ └──────────────────┘       │
│ Photo Protected - Send     │  ← Minimal message
│ Request to View            │
│                            │
│ ┌──────────────────────┐   │
│ │  📤 Send Request     │   │  ← Button visible
│ └──────────────────────┘   │
└────────────────────────────┘
```

**Use Case:** Matched profiles carousel, horizontal scrolling lists

---

## 🔒 Privacy Rules (सबै cards मा same)

### Rule 1: Clear Photo (फोटो क्लियर देखाउने)
```
✅ privacy == 'free'  OR  ✅ photo_request == 'accepted'
    ⬇️
  📸 Clear Photo
  ✓ All Details Visible
  ✓ Badges Shown
  ✓ Interests Visible
```

### Rule 2: Blurred Photo (फोटो blur गर्ने)
```
❌ privacy != 'free'  AND  ❌ photo_request != 'accepted'
    ⬇️
  🔒 Blurred Photo (sigma: 15.0)
  🔐 Lock Icon Overlay
  📝 Status Message
  ✗ Badges Hidden
  ✗ Interests Hidden
  ✗ Details Minimal
```

---

## 🎨 Visual Elements

### Colors & Styling

**Lock Overlay:**
- Background: Black gradient (0.3 → 0.5 opacity)
- Lock Icon: White, 50px (vertical), 32px (horizontal)
- Text: White, bold (14-16px)

**Badges:**
- Premium: Gold gradient 👑
- Verified: Blue checkmark ✓
- New: Green badge 🆕
- Only shown when photo is clear

**Status Messages:**
- "Photo Protected" - default
- "Request Pending" - when pending
- "Request Rejected" - when rejected
- "Access Granted" - when accepted

---

## 📝 Code Usage Examples

### Example 1: Vertical Card
```dart
PrivacyAwareProfileCard(
  imageUrl: user.profilePicture,
  name: user.name,
  age: user.age,
  privacy: user.privacy,           // Required!
  photoRequest: user.photoRequest, // Required!
  location: user.location,
  profession: user.profession,
  height: user.height,
  isPremium: user.isPremium,
  isVerified: user.isVerified,
  layout: CardLayout.vertical,     // Default
  onTap: () => viewProfile(user),
  onLike: () => likeUser(user),
  onMessage: () => messageUser(user),
)
```

### Example 2: Grid Card (Premium Members)
```dart
PrivacyAwareProfileCard(
  imageUrl: user.profilePicture,
  name: user.name,
  age: user.age,
  privacy: user.privacy,
  photoRequest: user.photoRequest,
  location: user.location,
  isPremium: true,
  isVerified: true,
  interests: ['Music', 'Sports', 'Travel'],
  layout: CardLayout.grid,         // Grid layout
  customActionButton: ElevatedButton(
    onPressed: () => sendRequest(user),
    child: Text('Send Request'),
  ),
  onTap: () => viewProfile(user),
)
```

### Example 3: Horizontal Card (Matched Profiles)
```dart
PrivacyAwareProfileCard(
  imageUrl: user.profilePicture,
  name: user.name,
  age: user.age,
  privacy: user.privacy,
  photoRequest: user.photoRequest,
  profession: user.profession,
  location: user.location,
  height: user.height,
  layout: CardLayout.horizontal,   // Horizontal layout
  customActionButton: SendRequestButton(user: user),
  onTap: () => viewProfile(user),
)
```

---

## 🔄 Privacy State Visual Guide

```
┌─────────────────────────────────────────────────┐
│  PRIVACY STATES                                 │
├─────────────────────────────────────────────────┤
│                                                 │
│  1. 🟢 FREE (privacy='free')                   │
│     └─→ Always shows CLEAR photo              │
│     └─→ All details visible                   │
│     └─→ No blur, no lock                      │
│                                                 │
│  2. 🟡 PRIVATE + ACCEPTED                      │
│     (privacy='private' + photo_request=        │
│      'accepted')                               │
│     └─→ Shows CLEAR photo                     │
│     └─→ All details visible                   │
│     └─→ User has access                       │
│                                                 │
│  3. 🔴 PRIVATE + NOT ACCEPTED                  │
│     (privacy='private' + photo_request !=      │
│      'accepted')                               │
│     └─→ Shows BLURRED photo                   │
│     └─→ Lock icon overlay                     │
│     └─→ Minimal details                       │
│     └─→ Status message shown                  │
│                                                 │
│  Sub-states for 🔴:                            │
│  • photo_request='pending'                     │
│    → "Request Pending"                         │
│  • photo_request='rejected'                    │
│    → "Request Rejected"                        │
│  • photo_request='not_sent' or null            │
│    → "Photo Protected"                         │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## 🎯 Main Benefits

### 1. Consistency (एकरूपता)
- ✅ Same privacy logic everywhere
- ✅ Same blur intensity (15.0)
- ✅ Same visual indicators

### 2. Reusability (पुन: प्रयोग)
- ✅ One component, multiple uses
- ✅ Easy to maintain
- ✅ Less code duplication

### 3. Flexibility (लचिलोपन)
- ✅ 3 different layouts
- ✅ Customizable buttons
- ✅ Optional fields

### 4. Security (सुरक्षा)
- ✅ Automatic privacy enforcement
- ✅ No manual blur logic needed
- ✅ Centralized control

---

## 📂 File Location

**New Reusable Card:**
```
/msfinal/lib/ReUsable/privacy_aware_profile_card.dart
```

**Updated Cards:**
```
/msfinal/lib/Home/Screen/MatchesProfile.dart
/msfinal/lib/ReUsable/card_widgets.dart
```

**Privacy Utility:**
```
/msfinal/lib/utils/privacy_utils.dart
```

---

## ✅ Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| PrivacyAwareProfileCard | ✅ Created | Ready to use |
| MatchesProfile.dart | ✅ Updated | Privacy added |
| card_widgets.dart | ✅ Updated | Privacy added |
| Existing cards | ✅ Verified | Already privacy-aware |
| Documentation | ✅ Complete | This file |

---

## 🚀 Next Steps

**To use in your profile cards:**

1. Import the new card:
```dart
import 'package:ms2026/ReUsable/privacy_aware_profile_card.dart';
```

2. Replace old card widget with:
```dart
PrivacyAwareProfileCard(
  // ... your parameters
  layout: CardLayout.vertical, // or grid, or horizontal
)
```

3. Make sure API returns:
```json
{
  "privacy": "free|private|paid|verified",
  "photo_request": "accepted|pending|rejected|not_sent"
}
```

---

**तपाईंको नयाँ card design तयार छ!** 🎉

सबै cards मा automatic privacy enforcement छ। कुनै layout चाहिए पनि, privacy rules automatic apply हुन्छ!
