import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
    Locale('pt', 'BR'),
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'File Cloud'**
  String get appTitle;

  /// Google Drive provider name
  ///
  /// In en, this message translates to:
  /// **'Google Drive'**
  String get providerGoogleDrive;

  /// Dropbox provider name
  ///
  /// In en, this message translates to:
  /// **'Dropbox'**
  String get providerDropbox;

  /// OneDrive provider name
  ///
  /// In en, this message translates to:
  /// **'OneDrive'**
  String get providerOneDrive;

  /// Button text to add a new account
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get addAccount;

  /// Button text to remove an account
  ///
  /// In en, this message translates to:
  /// **'Remove Account'**
  String get removeAccount;

  /// Button text to reauthorize an account
  ///
  /// In en, this message translates to:
  /// **'Reauthorize'**
  String get reauthorizeAccount;

  /// Confirmation message for removing an account
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this account?'**
  String get confirmRemoveAccount;

  /// Title for remove account confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Remove Account'**
  String get confirmRemoveAccountTitle;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Remove button text
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// Home button text
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Home folder name
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeFolder;

  /// Root folder name
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get rootFolder;

  /// Upload button text
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// New folder button text
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get newFolder;

  /// Use selection button text
  ///
  /// In en, this message translates to:
  /// **'Use Selection'**
  String get useSelection;

  /// Delete selected items button text
  ///
  /// In en, this message translates to:
  /// **'Delete Selected'**
  String get deleteSelected;

  /// Search field placeholder text
  ///
  /// In en, this message translates to:
  /// **'Search files...'**
  String get searchFiles;

  /// Clear search button tooltip
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// Create folder dialog title
  ///
  /// In en, this message translates to:
  /// **'Create Folder'**
  String get createFolderTitle;

  /// Folder name input label
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderName;

  /// Create button text
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Delete confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Items'**
  String get confirmDeleteTitle;

  /// Confirmation message for deleting a single item
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this item?'**
  String get confirmDeleteSingle;

  /// Confirmation message for deleting multiple items
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} items?'**
  String confirmDeleteMultiple(int count);

  /// Delete button text
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Loading indicator text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Message when no files or folders are found
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get noItemsFound;

  /// Message when search returns no results
  ///
  /// In en, this message translates to:
  /// **'No files found matching \'{query}\''**
  String noSearchResults(String query);

  /// Button text to load more items
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// Upload progress message
  ///
  /// In en, this message translates to:
  /// **'Uploading... {percent}%'**
  String uploadProgress(int percent);

  /// Message when upload is complete
  ///
  /// In en, this message translates to:
  /// **'Upload complete'**
  String get uploadComplete;

  /// Message when upload fails
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get uploadFailed;

  /// Message when download fails
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailed;

  /// Status text for connected account
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get accountStatusOk;

  /// Status text for account with error
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get accountStatusError;

  /// Status text for revoked account
  ///
  /// In en, this message translates to:
  /// **'Access revoked'**
  String get accountStatusRevoked;

  /// Status text for account missing scopes
  ///
  /// In en, this message translates to:
  /// **'Permissions needed'**
  String get accountStatusMissingScopes;

  /// Error message for unauthorized account
  ///
  /// In en, this message translates to:
  /// **'Your account is not authorized. Please reauthorize to continue.'**
  String get errorAccountNotAuthorized;

  /// Error message for account missing permissions
  ///
  /// In en, this message translates to:
  /// **'Your account lacks required permissions. Please reauthorize with the necessary scopes.'**
  String get errorAccountMissingPermissions;

  /// Error message for revoked account
  ///
  /// In en, this message translates to:
  /// **'Account access has been revoked. Please reauthorize your account.'**
  String get errorAccountRevoked;

  /// Generic error message for account issues
  ///
  /// In en, this message translates to:
  /// **'There was an error with your account. Please try reauthorizing.'**
  String get errorAccountGeneric;

  /// Error message for network issues
  ///
  /// In en, this message translates to:
  /// **'Network connection error. Please check your internet connection and try again.'**
  String get errorNetworkConnection;

  /// Error message when file is not found
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get errorFileNotFound;

  /// Error message for insufficient storage
  ///
  /// In en, this message translates to:
  /// **'Insufficient storage space'**
  String get errorInsufficientStorage;

  /// Error message when quota is exceeded
  ///
  /// In en, this message translates to:
  /// **'Storage quota exceeded'**
  String get errorQuotaExceeded;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again.'**
  String get errorGeneric;

  /// Try again button text
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// Message when user cancels authentication
  ///
  /// In en, this message translates to:
  /// **'Authentication was cancelled'**
  String get authenticationCancelled;

  /// Message when authentication fails
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please try again.'**
  String get authenticationFailed;

  /// Message showing number of selected items
  ///
  /// In en, this message translates to:
  /// **'Selection mode: {count} items selected'**
  String selectionModeActive(int count);

  /// Message when minimum selection not met
  ///
  /// In en, this message translates to:
  /// **'Please select at least {min} items'**
  String selectionModeMinRequired(int min);

  /// Message when maximum selection exceeded
  ///
  /// In en, this message translates to:
  /// **'You can select at most {max} items'**
  String selectionModeMaxExceeded(int max);

  /// Message when selected file type is not allowed
  ///
  /// In en, this message translates to:
  /// **'This file type is not allowed'**
  String get selectionModeInvalidType;

  /// File type filter label for images
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get fileTypeImages;

  /// File type filter label for documents
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get fileTypeDocuments;

  /// File type filter label for videos
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get fileTypeVideos;

  /// File type filter label for audio files
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get fileTypeAudio;

  /// File size display
  ///
  /// In en, this message translates to:
  /// **'{size}'**
  String fileSize(String size);

  /// Last modified date display
  ///
  /// In en, this message translates to:
  /// **'Modified {date}'**
  String lastModified(String date);

  /// Text showing additional accounts count
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String moreAccounts(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'BR':
            return AppLocalizationsPtBr();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
