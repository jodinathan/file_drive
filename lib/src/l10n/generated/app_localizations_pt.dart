// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'File Cloud';

  @override
  String get providerGoogleDrive => 'Google Drive';

  @override
  String get providerDropbox => 'Dropbox';

  @override
  String get providerOneDrive => 'OneDrive';

  @override
  String get addAccount => 'Adicionar Conta';

  @override
  String get removeAccount => 'Remover Conta';

  @override
  String get reauthorizeAccount => 'Reautorizar';

  @override
  String get confirmRemoveAccount =>
      'Tem certeza que deseja remover esta conta?';

  @override
  String get confirmRemoveAccountTitle => 'Remover Conta';

  @override
  String get cancel => 'Cancelar';

  @override
  String get remove => 'Remover';

  @override
  String get home => 'Início';

  @override
  String get homeFolder => 'Início';

  @override
  String get rootFolder => 'Início';

  @override
  String get upload => 'Enviar';

  @override
  String get newFolder => 'Nova Pasta';

  @override
  String get useSelection => 'Usar Seleção';

  @override
  String get deleteSelected => 'Excluir Selecionados';

  @override
  String get searchFiles => 'Buscar arquivos...';

  @override
  String get clearSearch => 'Limpar busca';

  @override
  String get createFolderTitle => 'Criar Pasta';

  @override
  String get folderName => 'Nome da pasta';

  @override
  String get create => 'Criar';

  @override
  String get confirmDeleteTitle => 'Excluir Itens';

  @override
  String get confirmDeleteSingle => 'Tem certeza que deseja excluir este item?';

  @override
  String confirmDeleteMultiple(int count) {
    return 'Tem certeza que deseja excluir $count itens?';
  }

  @override
  String get delete => 'Excluir';

  @override
  String get loading => 'Carregando...';

  @override
  String get noItemsFound => 'Nenhum item encontrado';

  @override
  String noSearchResults(String query) {
    return 'Nenhum arquivo encontrado para \'$query\'';
  }

  @override
  String get loadMore => 'Carregar mais';

  @override
  String uploadProgress(int percent) {
    return 'Enviando... $percent%';
  }

  @override
  String get uploadComplete => 'Envio concluído';

  @override
  String get uploadFailed => 'Falha no envio';

  @override
  String get downloadFailed => 'Falha no download';

  @override
  String get accountStatusOk => 'Conectado';

  @override
  String get accountStatusError => 'Erro';

  @override
  String get accountStatusRevoked => 'Acesso revogado';

  @override
  String get accountStatusMissingScopes => 'Permissões necessárias';

  @override
  String get errorAccountNotAuthorized =>
      'Sua conta não está autorizada. Por favor, reautorize para continuar.';

  @override
  String get errorAccountMissingPermissions =>
      'Sua conta não possui as permissões necessárias. Por favor, reautorize com os escopos necessários.';

  @override
  String get errorAccountRevoked =>
      'O acesso da conta foi revogado. Por favor, reautorize sua conta.';

  @override
  String get errorAccountGeneric =>
      'Houve um erro com sua conta. Por favor, tente reautorizar.';

  @override
  String get errorNetworkConnection =>
      'Erro de conexão de rede. Verifique sua conexão com a internet e tente novamente.';

  @override
  String get errorFileNotFound => 'Arquivo não encontrado';

  @override
  String get errorInsufficientStorage => 'Espaço de armazenamento insuficiente';

  @override
  String get errorQuotaExceeded => 'Cota de armazenamento excedida';

  @override
  String get errorGeneric => 'Ocorreu um erro. Tente novamente.';

  @override
  String get tryAgain => 'Tentar novamente';

  @override
  String get authenticationCancelled => 'Autenticação foi cancelada';

  @override
  String get authenticationFailed => 'Falha na autenticação. Tente novamente.';

  @override
  String selectionModeActive(int count) {
    return 'Modo seleção: $count itens selecionados';
  }

  @override
  String selectionModeMinRequired(int min) {
    return 'Por favor, selecione pelo menos $min itens';
  }

  @override
  String selectionModeMaxExceeded(int max) {
    return 'Você pode selecionar no máximo $max itens';
  }

  @override
  String get selectionModeInvalidType => 'Este tipo de arquivo não é permitido';

  @override
  String get fileTypeImages => 'Imagens';

  @override
  String get fileTypeDocuments => 'Documentos';

  @override
  String get fileTypeVideos => 'Vídeos';

  @override
  String get fileTypeAudio => 'Áudio';

  @override
  String fileSize(String size) {
    return '$size';
  }

  @override
  String lastModified(String date) {
    return 'Modificado $date';
  }

  @override
  String moreAccounts(int count) {
    return '+$count mais';
  }
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class AppLocalizationsPtBr extends AppLocalizationsPt {
  AppLocalizationsPtBr() : super('pt_BR');

  @override
  String get appTitle => 'File Cloud';

  @override
  String get providerGoogleDrive => 'Google Drive';

  @override
  String get providerDropbox => 'Dropbox';

  @override
  String get providerOneDrive => 'OneDrive';

  @override
  String get addAccount => 'Adicionar Conta';

  @override
  String get removeAccount => 'Remover Conta';

  @override
  String get reauthorizeAccount => 'Reautorizar';

  @override
  String get confirmRemoveAccount =>
      'Tem certeza que deseja remover esta conta?';

  @override
  String get confirmRemoveAccountTitle => 'Remover Conta';

  @override
  String get cancel => 'Cancelar';

  @override
  String get remove => 'Remover';

  @override
  String get home => 'Início';

  @override
  String get homeFolder => 'Início';

  @override
  String get rootFolder => 'Início';

  @override
  String get upload => 'Enviar';

  @override
  String get newFolder => 'Nova Pasta';

  @override
  String get useSelection => 'Usar Seleção';

  @override
  String get deleteSelected => 'Excluir Selecionados';

  @override
  String get searchFiles => 'Buscar arquivos...';

  @override
  String get clearSearch => 'Limpar busca';

  @override
  String get createFolderTitle => 'Criar Pasta';

  @override
  String get folderName => 'Nome da pasta';

  @override
  String get create => 'Criar';

  @override
  String get confirmDeleteTitle => 'Excluir Itens';

  @override
  String get confirmDeleteSingle => 'Tem certeza que deseja excluir este item?';

  @override
  String confirmDeleteMultiple(int count) {
    return 'Tem certeza que deseja excluir $count itens?';
  }

  @override
  String get delete => 'Excluir';

  @override
  String get loading => 'Carregando...';

  @override
  String get noItemsFound => 'Nenhum item encontrado';

  @override
  String noSearchResults(String query) {
    return 'Nenhum arquivo encontrado para \'$query\'';
  }

  @override
  String get loadMore => 'Carregar mais';

  @override
  String uploadProgress(int percent) {
    return 'Enviando... $percent%';
  }

  @override
  String get uploadComplete => 'Envio concluído';

  @override
  String get uploadFailed => 'Falha no envio';

  @override
  String get downloadFailed => 'Falha no download';

  @override
  String get accountStatusOk => 'Conectado';

  @override
  String get accountStatusError => 'Erro';

  @override
  String get accountStatusRevoked => 'Acesso revogado';

  @override
  String get accountStatusMissingScopes => 'Permissões necessárias';

  @override
  String get errorAccountNotAuthorized =>
      'Sua conta não está autorizada. Por favor, reautorize para continuar.';

  @override
  String get errorAccountMissingPermissions =>
      'Sua conta não possui as permissões necessárias. Por favor, reautorize com os escopos necessários.';

  @override
  String get errorAccountRevoked =>
      'O acesso da conta foi revogado. Por favor, reautorize sua conta.';

  @override
  String get errorAccountGeneric =>
      'Houve um erro com sua conta. Por favor, tente reautorizar.';

  @override
  String get errorNetworkConnection =>
      'Erro de conexão de rede. Verifique sua conexão com a internet e tente novamente.';

  @override
  String get errorFileNotFound => 'Arquivo não encontrado';

  @override
  String get errorInsufficientStorage => 'Espaço de armazenamento insuficiente';

  @override
  String get errorQuotaExceeded => 'Cota de armazenamento excedida';

  @override
  String get errorGeneric => 'Ocorreu um erro. Tente novamente.';

  @override
  String get tryAgain => 'Tentar novamente';

  @override
  String get authenticationCancelled => 'Autenticação foi cancelada';

  @override
  String get authenticationFailed => 'Falha na autenticação. Tente novamente.';

  @override
  String selectionModeActive(int count) {
    return 'Modo seleção: $count itens selecionados';
  }

  @override
  String selectionModeMinRequired(int min) {
    return 'Por favor, selecione pelo menos $min itens';
  }

  @override
  String selectionModeMaxExceeded(int max) {
    return 'Você pode selecionar no máximo $max itens';
  }

  @override
  String get selectionModeInvalidType => 'Este tipo de arquivo não é permitido';

  @override
  String get fileTypeImages => 'Imagens';

  @override
  String get fileTypeDocuments => 'Documentos';

  @override
  String get fileTypeVideos => 'Vídeos';

  @override
  String get fileTypeAudio => 'Áudio';

  @override
  String fileSize(String size) {
    return '$size';
  }

  @override
  String lastModified(String date) {
    return 'Modificado $date';
  }

  @override
  String moreAccounts(int count) {
    return '+$count mais';
  }
}
