# Exemplo de Uso - Informações de Data

## Criando FileEntry com Datas

```dart
import 'package:file_cloud/file_cloud.dart';

// Exemplo de arquivo com informações de data
final fileEntry = FileEntry(
  id: 'example_file_123',
  name: 'relatório_mensal.pdf',
  isFolder: false,
  size: 2048576, // 2 MB
  mimeType: 'application/pdf',
  createdAt: DateTime(2024, 1, 15, 14, 30), // 15 jan 2024 às 14:30
  modifiedAt: DateTime.now().subtract(Duration(hours: 2)), // 2 horas atrás
  canDownload: true,
  canDelete: true,
);
```

## Usando FileItemCard com Informações de Data

```dart
// Listagem normal (sem datas)
FileItemCard(
  file: fileEntry,
  isSelected: false,
  showCheckbox: true,
  showDateInfo: false, // Padrão - não mostra datas
)

// Listagem detalhada (com datas)
FileItemCard(
  file: fileEntry,
  isSelected: false,
  showCheckbox: true,
  showDateInfo: true, // Mostra datas de criação e modificação
)
```

## Resultado Visual

### Listagem normal E dialog de confirmação (layout idêntico):
```
📄 relatório_mensal.pdf
   2.0 MB
   Criado: 15 jan • Modificado: hoje às 16:30

📁 Documentos Antigos  
   Pasta
   Criado: 20 fev • Modificado: ontem
```

## Formatação Automática de Datas

A formatação das datas é automática e inteligente:

| Quando | Formato de Exibição |
|--------|-------------------|
| Hoje | "hoje às 14:30" |
| Ontem | "ontem" |
| Esta semana | "terça", "quarta", "sexta" |
| Este ano | "15 mar", "22 jul", "30 dez" |
| Anos anteriores | "15/03/2023", "22/07/2022" |

## Uso no Dialog de Confirmação

O dialog de confirmação de exclusão automaticamente usa `showDateInfo: true` para fornecer informações completas sobre os arquivos que serão excluídos:

```
🗑️ Confirmar exclusão de 3 itens

Deseja realmente excluir os seguintes arquivos?

📄 relatório_mensal.pdf
   2.0 MB • Modificado: hoje às 16:30 • Criado: 15 jan

📁 Documentos Antigos
   Pasta • Modificado: ontem • Criado: 20 fev

📄 planilha_vendas.xlsx
   4.5 MB • Modificado: segunda • Criado: 10 mar

⚠️ Esta ação não pode ser desfeita.

[Cancelar] [Excluir]
```

## Integração com Providers

### Google Drive Provider
Automaticamente captura `createdTime` e `modifiedTime` da API do Google Drive:

```dart
// No GoogleDriveProvider
FileEntry _convertToFileEntry(drive.File driveFile) {
  return FileEntry(
    // ... outros campos
    createdAt: driveFile.createdTime,    // ✅ Capturado automaticamente
    modifiedAt: driveFile.modifiedTime,  // ✅ Já existia
    // ...
  );
}
```

### Outros Providers (Futuro)
Quando implementados, outros providers seguirão o mesmo padrão:

```dart
// Exemplo para Dropbox (futuro)
FileEntry _convertToFileEntry(DropboxFile dropboxFile) {
  return FileEntry(
    // ... outros campos
    createdAt: dropboxFile.clientModified,
    modifiedAt: dropboxFile.serverModified,
    // ...
  );
}
```