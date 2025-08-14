# Detecção Automática de Dimensões de Imagem e Configuração de Crop

## Problema Resolvido

O problema estava relacionado ao workflow de crop de imagens onde o servidor local não fornecia metadados completos das imagens, resultando em dimensões 0x0 sendo exibidas na interface do usuário.

## Solução Implementada

### 1. CropConfig (Nova Classe de Configuração)

Criada em `lib/src/models/crop_config.dart`, esta classe fornece configuração flexível para operações de crop:

#### Funcionalidades:
- **Aspect Ratio Customizável**: Define proporções específicas (ex: 9:6, 16:9, 1:1)
- **Constraintes de Dimensão**: Define limites mínimos e máximos para largura/altura
- **Modos de Operação**: Enforcement estrito ou free-form
- **Factory Methods**: Métodos de conveniência para configurações comuns

#### Exemplos de Uso:
```dart
// Crop quadrado com tamanho mínimo
CropConfig.square(minSize: 200)

// Crop landscape 16:9
CropConfig.landscape(minWidth: 640, minHeight: 360)

// Crop customizado 9:6 com mínimo de 300px
CropConfig.custom(
  aspectRatio: 9.0 / 6.0,
  minWidth: 300,
  minHeight: 200,
  enforceAspectRatio: true,
)

// Crop livre com constraintes
CropConfig.freeForm(
  minRatio: 0.5,
  maxRatio: 2.0,
  minWidth: 100,
)
```

### 2. ImageDimensionDetector (Utilitário de Detecção)

Criado em `lib/src/utils/image_dimension_detector.dart`, este utilitário fornece métodos para detectar automaticamente as dimensões de imagens:

- **`detectNetworkImageDimensions(String imageUrl)`**: Detecta dimensões de imagens via URL de rede
- **`detectLocalImageDimensions(String filePath)`**: Detecta dimensões de imagens locais
- **`detectAssetImageDimensions(String assetPath)`**: Detecta dimensões de assets
- **`buildCompleteUrl(String url)`**: Constrói URLs completas para URLs relativas

### 3. CropPanelWidget Aprimorado

Modificações em `lib/src/widgets/crop_panel_widget.dart`:

#### Mudanças na API:
- **Removido**: Parâmetros individuais (`minRatio`, `maxRatio`, `minWidth`, `minHeight`)
- **Adicionado**: Parâmetro `cropConfig` do tipo `CropConfig?`
- **Melhor Validação**: Usa `CropConfig.isValidCrop()` para validação completa
- **Feedback Detalhado**: Mensagens de erro específicas para cada constrainte

#### Funcionalidades Mantidas:
- **Cache de Dimensões**: `_detectedDimensions` armazena dimensões detectadas
- **Detecção Automática**: `_detectMissingDimensions()` executa no `initState()`
- **Estado de Carregamento**: Exibe "Detectando..." enquanto detecta dimensões
- **Atualização Dinâmica**: Interface atualiza automaticamente quando dimensões são detectadas

#### Novas Funcionalidades:
- **Exibição de Configuração**: Mostra a descrição da configuração de crop no cabeçalho
- **Validação Avançada**: Mensagens de erro detalhadas com valores atuais vs. esperados

### 4. Exemplo Atualizado

Atualizado `example/crop_example.dart` para demonstrar:
- Uso da nova API `CropConfig`
- Configuração 9:6 aspect ratio com mínimo de 300px de largura
- Enforcement estrito do aspect ratio

## Fluxo de Funcionamento

1. **Configuração**: Define `CropConfig` com aspect ratio 9:6 e mínimo de 300px
2. **Carregamento**: CropPanel carrega e identifica imagens sem dimensões
3. **Detecção**: Sistema baixa automaticamente cada imagem e detecta suas dimensões
4. **Validação**: Usa `CropConfig.isValidCrop()` para validar dimensões do crop
5. **Feedback**: Mostra mensagens de erro detalhadas se crop não atender aos requisitos
6. **Atualização**: Interface atualiza dinamicamente conforme dimensões são detectadas

## Benefícios

1. **API Mais Limpa**: Um único objeto de configuração em vez de múltiplos parâmetros
2. **Flexibilidade**: Suporte a configurações complexas com factory methods convenientes
3. **Validação Robusta**: Verificação completa de todas as constraintes
4. **Feedback Melhor**: Mensagens de erro específicas e informativas
5. **Transparência**: O usuário não precisa saber que o servidor não fornece dimensões
6. **Performance**: Cache evita re-detecção desnecessária
7. **UX Melhorada**: Feedback visual claro durante o processo de detecção

## Uso em Produção

A solução é completamente transparente e backwards-compatible. Mesmo quando o servidor começar a fornecer metadados de imagem no futuro, o sistema continuará funcionando normalmente, simplesmente usando os metadados fornecidos em vez de detectar automaticamente.

## Arquivos Modificados

- `lib/src/models/crop_config.dart` (novo)
- `lib/src/utils/image_dimension_detector.dart` (novo)
- `lib/src/widgets/crop_panel_widget.dart` (modificado - API atualizada)
- `example/crop_example.dart` (atualizado para nova API)

## Migração

Para migrar código existente:

```dart
// Antes
CropPanelWidget(
  minRatio: 0.5,
  maxRatio: 2.0,
  minWidth: 100,
  minHeight: 100,
  // ...
)

// Depois
CropPanelWidget(
  cropConfig: CropConfig.freeForm(
    minRatio: 0.5,
    maxRatio: 2.0,
    minWidth: 100,
    minHeight: 100,
  ),
  // ...
)
```

## Dependências

Utiliza a dependência `http: ^1.2.0` já presente no projeto para download de imagens de rede.