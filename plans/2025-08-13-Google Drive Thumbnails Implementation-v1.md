# Implementação de Thumbnails do Google Drive

## Objetivo
Implementar suporte completo a thumbnails fornecidos pela API do Google Drive, incluindo correções nos campos solicitados e exibição nos widgets.

## Análise da Situação Atual

### ✅ O que já está funcionando:
1. **FileEntry suporta thumbnails**: Campo `thumbnailUrl` já existe no modelo
2. **Provider captura thumbnailLink**: `thumbnailUrl: driveFile.thumbnailLink` na linha 85
3. **API solicita thumbnailLink**: Campo incluído na requisição da API

### ❌ Problemas identificados:
1. **Campo `createdTime` ausente**: A API não está solicitando `createdTime`, causando `createdAt` null
2. **Thumbnails não são exibidos**: FileItemCard não usa o campo `thumbnailUrl`
3. **Campos inconsistentes**: Outras operações (createFolder, search) também não solicitam `createdTime`

## Implementação Plan

### 1. Corrigir Campos da API do Google Drive
**Arquivo**: `lib/src/providers/google_drive_provider.dart`

#### 1.1 Método `listFolder` (linha ~157)
```dart
// ANTES:
$fields: 'nextPageToken,files(id,name,mimeType,size,modifiedTime,parents,thumbnailLink,webContentLink,capabilities)'

// DEPOIS:
$fields: 'nextPageToken,files(id,name,mimeType,size,createdTime,modifiedTime,parents,thumbnailLink,webContentLink,capabilities)'
```

#### 1.2 Método `createFolder` (linha ~206)
```dart
// ANTES:
$fields: 'id,name,mimeType,modifiedTime,parents'

// DEPOIS:
$fields: 'id,name,mimeType,createdTime,modifiedTime,parents'
```

#### 1.3 Método `searchFiles` (linha ~320)
```dart
// ANTES:
$fields: 'nextPageToken,files(id,name,mimeType,size,modifiedTime,parents,thumbnailLink,webContentLink,capabilities)'

// DEPOIS:
$fields: 'nextPageToken,files(id,name,mimeType,size,createdTime,modifiedTime,parents,thumbnailLink,webContentLink,capabilities)'
```

### 2. Implementar Exibição de Thumbnails

#### 2.1 Atualizar FileItemCard
**Arquivo**: `lib/src/widgets/file_item_card.dart`

**Modificar método `_buildFileIcon`:**
```dart
Widget _buildFileIcon(ThemeData theme) {
  // Se tem thumbnail e não é pasta, mostrar thumbnail
  if (!file.isFolder && file.thumbnailUrl != null) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        file.thumbnailUrl!,
        width: 24,
        height: 24,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Fallback para ícone padrão se thumbnail falhar
          return Icon(
            Icons.description,
            color: theme.colorScheme.onSurface,
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / 
                    loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      ),
    );
  }
  
  // Ícone padrão para pastas ou quando não há thumbnail
  return Icon(
    file.isFolder ? Icons.folder : Icons.description,
    color: file.isFolder
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface,
  );
}
```

#### 2.2 Configuração Opcional de Thumbnail
**Adicionar parâmetro ao FileItemCard:**
```dart
class FileItemCard extends StatelessWidget {
  // ... campos existentes
  
  /// Whether to show thumbnails when available
  final bool showThumbnails;

  const FileItemCard({
    // ... parâmetros existentes
    this.showThumbnails = true,
  });
}
```

### 3. Otimizações e Melhorias

#### 3.1 Cache de Thumbnails
**Consideração**: Para melhor performance, implementar cache de thumbnails:
```dart
class ThumbnailCache {
  static final Map<String, Image> _cache = {};
  
  static Widget getThumbnail(String url, {required Widget fallback}) {
    if (_cache.containsKey(url)) {
      return _cache[url]!;
    }
    
    // Implementar lógica de cache...
  }
}
```

#### 3.2 Tamanhos de Thumbnail Responsivos
**Para diferentes contextos:**
- **Lista normal**: 24x24px
- **Dialog detalhado**: 32x32px  
- **Modo compacto**: 20x20px

### 4. Informações sobre Thumbnails do Google Drive

#### 4.1 Tipos de Arquivo Suportados
O Google Drive fornece thumbnails para:
- ✅ **Imagens**: JPG, PNG, GIF, BMP, WebP
- ✅ **Documentos**: PDF, DOC, DOCX, TXT
- ✅ **Planilhas**: XLS, XLSX, CSV
- ✅ **Apresentações**: PPT, PPTX
- ✅ **Vídeos**: MP4, AVI, MOV (frame preview)
- ❌ **Pastas**: Não têm thumbnail
- ❌ **Arquivos grandes/específicos**: Podem não ter thumbnail

#### 4.2 Formato das URLs de Thumbnail
```
https://drive.google.com/thumbnail?id={FILE_ID}&sz=w{WIDTH}-h{HEIGHT}
```

**Exemplo real:**
```
https://drive.google.com/thumbnail?id=1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms&sz=w120-h120
```

#### 4.3 Parâmetros de Tamanho
- `sz=w120-h120`: 120x120 pixels
- `sz=w200-h200`: 200x200 pixels
- `sz=w400-h400`: 400x400 pixels
- `sz=s220`: Square 220x220 pixels

### 5. Tratamento de Erros

#### 5.1 Fallbacks para Thumbnails
1. **Erro de rede**: Mostrar ícone padrão
2. **Thumbnail não disponível**: Ícone baseado no MIME type
3. **Timeout**: Placeholder com loading

#### 5.2 Logs de Debug
```dart
if (file.thumbnailUrl != null) {
  AppLogger.debug('Thumbnail disponível: ${file.name}', 
    component: 'Thumbnail', 
    data: {'url': file.thumbnailUrl}
  );
} else {
  AppLogger.info('Thumbnail não disponível: ${file.name}', 
    component: 'Thumbnail'
  );
}
```

## Verificação Criteria

### ✅ Funcionalidade Básica
- [ ] `createdTime` é solicitado em todas as chamadas da API
- [ ] `createdAt` não é mais null para arquivos do Google Drive
- [ ] Thumbnails são exibidos quando disponíveis
- [ ] Fallback funciona corretamente para arquivos sem thumbnail

### ✅ Experiência do Usuário
- [ ] Thumbnails carregam sem bloquear a UI
- [ ] Loading state é mostrado durante carregamento
- [ ] Erro de thumbnail não quebra a interface
- [ ] Layout permanece consistente com e sem thumbnails

### ✅ Performance
- [ ] Thumbnails não causam lag na rolagem
- [ ] Requests de thumbnail são otimizados
- [ ] Cache evita downloads desnecessários

## Riscos e Mitigações

### 1. **Performance**: Muitos thumbnails podem causar lag
**Mitigação**: Implementar lazy loading e cache

### 2. **Quota da API**: Thumbnails consomem cota do Google Drive
**Mitigação**: Cache local e loading sob demanda

### 3. **Falhas de Rede**: Thumbnails podem falhar ao carregar
**Mitigação**: Fallbacks robustos e timeouts apropriados

## Próximos Passos

1. **Implementar correções dos campos da API** (alta prioridade)
2. **Adicionar suporte a thumbnails no FileItemCard** (média prioridade)
3. **Implementar cache e otimizações** (baixa prioridade)
4. **Testes com diferentes tipos de arquivo** (verificação)