# App Layout Update with Account Carousel

## Objective
Update the application layout to a two-column structure: the first column remains as the existing list of providers. The second column consists of two rows. The first row features a carousel of integrated account cards with an add new account button. Each card has no padding, a left radius of 40, and three internal columns: first with a 40x40 photo, second with padded information including name, email, and integration status icon, third with a menu button for remove account and reauthenticate options. Extend token storage to save basic account data (name, photo, email) alongside tokens to handle cases where integration is removed externally.

## Implementation Plan
1. **Extend token storage for account details**
  - Dependencies: None
  - Notes: Modify storage classes (e.g., shared_preferences_token_storage.dart, web_token_storage.dart) to include name, email, photo during auth flows. Ensure backward compatibility.
  - Files: lib/src/storage/shared_preferences_token_storage.dart, lib/src/storage/web_token_storage.dart
  - Status: Not Started

2. **Create AccountCard widget**
  - Dependencies: Step 1
  - Notes: New stateless widget with specified design: no padding, border radius left 40, 3 columns layout.
  - Files: lib/src/widgets/account_card.dart
  - Status: Not Started

3. **Implement accounts carousel**
  - Dependencies: Step 2
  - Notes: Use horizontal ListView or add carousel package; include add button; integrate in second column first row.
  - Files: lib/src/widgets/account_carousel.dart (update or new)
  - Status: Not Started

4. **Update main layout to 2 columns**
  - Dependencies: Step 3
  - Notes: Use Row for columns, Column for right side rows; keep provider list unchanged.
  - Files: lib/src/widgets/file_drive_widget.dart
  - Status: Not Started

5. **Add data fetching and caching**
  - Dependencies: Step 1 and 4
  - Notes: Fetch account info during auth and store; display from cache if token invalid.
  - Files: lib/src/providers/base/oauth_cloud_provider.dart, provider-specific files
  - Status: Not Started

6. **Verification and testing**
  - Dependencies: All previous
  - Notes: Run dart analyze, flutter test, manual UI checks.
  - Files: All modified
  - Status: Not Started

## Verification Criteria
- App compiles without errors (dart analyze passes).
- Layout shows 2 columns with provider list left, carousel top-right, empty bottom-right.
- Account cards display correctly with cached data even after external removal.
- Tests pass, no regressions in auth flows.

## Potential Risks and Mitigations
1. **Storage extension breaks existing tokens**
  Mitigation: Implement migration logic for old storage format.
2. **Carousel dependency issues**
  Mitigation: Use built-in widgets or test new package thoroughly.
3. **UI responsiveness on different platforms**
  Mitigation: Test on web and macos, use MediaQuery for adaptive sizing.

## Alternative Approaches
1. Custom horizontal scroll: Use ListView.horizontal instead of carousel package to avoid new dependencies.
2. State management: Integrate Provider or Riverpod for better handling of account list updates.
