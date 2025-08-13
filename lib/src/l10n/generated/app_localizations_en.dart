// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'File Cloud';

  @override
  String get providerGoogleDrive => 'Google Drive';

  @override
  String get providerDropbox => 'Dropbox';

  @override
  String get providerOneDrive => 'OneDrive';

  @override
  String get addAccount => 'Add Account';

  @override
  String get removeAccount => 'Remove Account';

  @override
  String get reauthorizeAccount => 'Reauthorize';

  @override
  String get confirmRemoveAccount =>
      'Are you sure you want to remove this account?';

  @override
  String get confirmRemoveAccountTitle => 'Remove Account';

  @override
  String get cancel => 'Cancel';

  @override
  String get remove => 'Remove';

  @override
  String get home => 'Home';

  @override
  String get homeFolder => 'Home';

  @override
  String get rootFolder => 'Home';

  @override
  String get upload => 'Upload';

  @override
  String get newFolder => 'New Folder';

  @override
  String get useSelection => 'Use Selection';

  @override
  String get deleteSelected => 'Delete Selected';

  @override
  String get searchFiles => 'Search files...';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get createFolderTitle => 'Create Folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get create => 'Create';

  @override
  String get confirmDeleteTitle => 'Delete Items';

  @override
  String get confirmDeleteSingle =>
      'Are you sure you want to delete this item?';

  @override
  String confirmDeleteMultiple(int count) {
    return 'Are you sure you want to delete $count items?';
  }

  @override
  String get delete => 'Delete';

  @override
  String get loading => 'Loading...';

  @override
  String get noItemsFound => 'No items found';

  @override
  String noSearchResults(String query) {
    return 'No files found matching \'$query\'';
  }

  @override
  String get loadMore => 'Load more';

  @override
  String uploadProgress(int percent) {
    return 'Uploading... $percent%';
  }

  @override
  String get uploadComplete => 'Upload complete';

  @override
  String get uploadFailed => 'Upload failed';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get accountStatusOk => 'Connected';

  @override
  String get accountStatusError => 'Error';

  @override
  String get accountStatusRevoked => 'Access revoked';

  @override
  String get accountStatusMissingScopes => 'Permissions needed';

  @override
  String get errorAccountNotAuthorized =>
      'Your account is not authorized. Please reauthorize to continue.';

  @override
  String get errorAccountMissingPermissions =>
      'Your account lacks required permissions. Please reauthorize with the necessary scopes.';

  @override
  String get errorAccountRevoked =>
      'Account access has been revoked. Please reauthorize your account.';

  @override
  String get errorAccountGeneric =>
      'There was an error with your account. Please try reauthorizing.';

  @override
  String get errorNetworkConnection =>
      'Network connection error. Please check your internet connection and try again.';

  @override
  String get errorFileNotFound => 'File not found';

  @override
  String get errorInsufficientStorage => 'Insufficient storage space';

  @override
  String get errorQuotaExceeded => 'Storage quota exceeded';

  @override
  String get errorGeneric => 'An error occurred. Please try again.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get authenticationCancelled => 'Authentication was cancelled';

  @override
  String get authenticationFailed => 'Authentication failed. Please try again.';

  @override
  String selectionModeActive(int count) {
    return 'Selection mode: $count items selected';
  }

  @override
  String selectionModeMinRequired(int min) {
    return 'Please select at least $min items';
  }

  @override
  String selectionModeMaxExceeded(int max) {
    return 'You can select at most $max items';
  }

  @override
  String get selectionModeInvalidType => 'This file type is not allowed';

  @override
  String get fileTypeImages => 'Images';

  @override
  String get fileTypeDocuments => 'Documents';

  @override
  String get fileTypeVideos => 'Videos';

  @override
  String get fileTypeAudio => 'Audio';

  @override
  String fileSize(String size) {
    return '$size';
  }

  @override
  String lastModified(String date) {
    return 'Modified $date';
  }

  @override
  String moreAccounts(int count) {
    return '+$count more';
  }
}
