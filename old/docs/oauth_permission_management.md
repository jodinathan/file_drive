# Gerenciamento de Problemas de OAuth e Permissões

## Resumo das Mudanças Implementadas

### 1. Remoção do Botão "Resetar"
- **Local**: `lib/src/widgets/provider_content.dart:198`
- **Mudança**: Removido o botão "Resetar" do estado de erro
- **Motivo**: Manter contas mesmo com problemas para permitir correção de permissões

### 2. Flags de Problemas de Permissão no AuthResult
- **Local**: `lib/src/models/oauth_types.dart:93-104`
- **Adicionado**:
  - `hasPermissionIssues: bool` - Indica se há problemas de permissão
  - `needsReauth: bool` - Indica se precisa re-autenticação
  - Factory method `AuthResult.permissionIssue()` - Para criar resultado com problemas

### 3. Sistema de Detecção de Problemas de Permissão
- **Local**: `lib/src/providers/google_drive/google_drive_provider.dart:809-840`
- **Funcionalidade**: Método `_handlePermissionError()` que:
  - Detecta erros HTTP 403 ou mensagens de permissão
  - Marca a conta com flags de problema
  - Atualiza status para erro sem remover a conta
  - Integrado nos métodos de API (listFiles, upload, etc.)

### 4. Interface Visual para Problemas de Permissão
- **Local**: `lib/src/widgets/breadcrumb_navigation.dart:148-280`
- **Funcionalidades**:
  - **Indicador visual**: Ícone de aviso laranja no avatar do usuário
  - **Texto explicativo**: "Clique para reautenticar" quando há problemas
  - **Cor diferenciada**: Container laranja para usuários com problemas
  - **Clique direto**: Usuário pode clicar no próprio avatar para re-autenticar

### 5. Gerenciamento de Estado de Usuários
- **Local**: `lib/src/providers/base/oauth_cloud_provider.dart:72-82`
- **Mudanças**:
  - Adicionado getter `needsReauth` 
  - Método `switchToUser()` verifica flags de permissão
  - Status atualizado baseado em problemas de permissão

## Fluxo de Uso

### Cenário 1: Erro de OAuth na Primeira Autenticação
1. Usuário tenta autenticar mas não concede todos os escopos
2. Conta é adicionada mas marcada com `hasPermissionIssues = true`
3. Interface mostra indicador visual laranja no usuário
4. Usuário clica no avatar para re-autenticar
5. Nova autenticação com escopos corretos

### Cenário 2: Erro de Execução na API
1. API retorna 403 (Forbidden) por falta de permissões
2. `_handlePermissionError()` detecta o problema
3. Conta é marcada com flags de problema
4. Status muda para erro mantendo a conta
5. Interface atualiza mostrando indicador visual
6. Usuário pode re-autenticar clicando no avatar

### Cenário 3: Múltiplas Contas
1. Usuário pode ter várias contas, algumas com problemas
2. Menu dropdown mostra todas as contas
3. Contas com problemas têm indicador visual diferenciado
4. Troca entre contas mantém estado de problemas individual
5. Re-autenticação é específica por conta

## Arquivos Modificados

1. **oauth_types.dart** - Flags de permissão no AuthResult
2. **provider_content.dart** - Remoção do botão resetar
3. **oauth_cloud_provider.dart** - Gerenciamento de estado de permissão
4. **google_drive_provider.dart** - Detecção de erros de API
5. **breadcrumb_navigation.dart** - Interface visual para problemas
6. **file_explorer.dart** - Passagem do provider para navegação

## Benefícios

- **Recuperação automática**: Contas não são perdidas por problemas temporários
- **UX intuitiva**: Indicadores visuais claros dos problemas
- **Re-autenticação fácil**: Um clique resolve problemas de permissão
- **Gerenciamento granular**: Cada conta mantém seu próprio estado
- **Detecção automática**: Problemas são detectados em tempo real durante uso da API