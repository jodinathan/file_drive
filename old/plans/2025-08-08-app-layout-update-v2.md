# App Layout Update with Account Carousel

## Objective
Update the application layout to a two-column structure: the first column remains as the existing list of providers. The second column consists of two rows. The first row features a carousel of integrated account cards with an add new account button. Each card has no padding, a left radius of 40, and three internal columns: first with a 40x40 photo, second with padded information including name, email, and integration status icon, third with a menu button for remove account and reauthenticate options. Extend token storage in shared_preferences to save basic account data (name, photo, email) alongside tokens to handle cases where integration is removed externally. Refactor as needed, removing unused code; no legacy compatibility required.

## Implementation Plan
1. **Extend token storage for account details**
  - Dependencies: None
  - Notes: Modify storage classes (e.g., shared_preferences_token_storage.dart, web_token_storage.dart) to include name, email, photo during auth flows. Use shared_preferences as specified. Refactor to remove any unused methods or variables.
  - Files: lib/src/storage/shared_preferences_token_storage.dart, lib/src/storage/web_token_storage.dart
  - Status: Not Started

2. **Create AccountCard widget**
  - Dependencies: Step 1
  - Notes: New stateless widget with specified design: no padding, border radius left 40, 3 columns layout. Remove any old account display code if refactoring.
  - Files: lib/src/widgets/account_card.dart
  - Status: Not Started

3. **Implement accounts carousel**
  - Dependencies: Step 2
  - Notes: Add carousel_slider dependency to pubspec.yaml for carousel implementation; include add button; integrate in second column first row. Use horizontal carousel for accounts.
  - Files: lib/src/widgets/account_carousel.dart (update or new), pubspec.yaml
  - Status: Not Started

4. **Update main layout to 2 columns**
  - Dependencies: Step 3
  - Notes: Use Row for columns, Column for right side: first row carousel, second row existing file/folder navigation (unchanged).
  - Files: lib/src/widgets/file_drive_widget.dart
  - Status: Not Started

5. **Add data fetching and caching**
  - Dependencies: Step 1 and 4
  - Notes: Fetch account info during auth and store in shared_preferences; display from cache if token invalid. Refactor auth flows to integrate this.
  - Files: lib/src/providers/base/oauth_cloud_provider.dart, provider-specific files
  - Status: Not Started

6. **Verification and testing**
  - Dependencies: All previous
  - Notes: Run dart analyze, flutter test (ignore old failing tests for now), manual UI checks. Remove unused code post-refactor.
  - Files: All modified
  - Status: Not Started

## Verification Criteria
- App compiles without errors (dart analyze passes).
- Layout shows 2 columns with provider list left, carousel top-right, existing navigation bottom-right.
- Account cards display correctly with cached data even after external removal.
- No unused code remains after refactor.

## Potential Risks and Mitigations
1. **Storage changes affect auth flows**
  Mitigation: Thoroughly test auth after modifications.
2. **New dependency integration issues**
  Mitigation: Add carousel_slider and run pub get; test compatibility.
3. **UI responsiveness on different platforms**
  Mitigation: Test on web and macos, use MediaQuery for adaptive sizing.

## Alternative Approaches
1. Custom horizontal scroll: Use ListView.horizontal instead of adding carousel_slider to avoid new dependencies.
2. State management: Integrate Provider or Riverpod for better handling of account list updates.
