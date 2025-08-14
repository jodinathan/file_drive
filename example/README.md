# 🚀 Guia de Configuração - File Cloud Example

Este guia explica como configurar e executar o exemplo completo do File Cloud widget com integração Google Drive.

## 📋 Pré-requisitos

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.8.1)
- Conta Google (para Google Cloud Console)
- Editor de código (VS Code, Android Studio, etc.)

## 🔧 Configuração do Google Cloud Console

### 1. Criar/Configurar Projeto

1. Acesse [Google Cloud Console](https://console.cloud.google.com/)
2. Crie um novo projeto ou selecione um existente
3. Anote o **Project ID**

### 2. Ativar APIs Necessárias

1. Vá em **APIs & Services > Library**
2. Procure e ative:
   - **Google Drive API**
   - **Google+ API** (para perfil do usuário)

### 3. Configurar OAuth Consent Screen

1. Vá em **APIs & Services > OAuth consent screen**
2. Escolha **External** (para testes)
3. Preencha as informações obrigatórias:
   - **App name**: File Cloud Example
   - **User support email**: seu email
   - **Developer contact**: seu email
4. **Salve** e continue

### 4. Criar Credenciais OAuth 2.0

#### Para o Servidor (Web Application)
1. Vá em **APIs & Services > Credentials**
2. Click **Create Credentials > OAuth 2.0 Client IDs**
3. Tipo: **Web application**
4. Nome: **File Cloud Server**
5. **Authorized redirect URIs**: `http://localhost:8080/auth/callback`
6. **Salve** e anote o **Client ID** e **Client Secret**

#### Para Mobile (Opcional - apenas se testar em mobile)
1. Crie outra credencial
2. Tipo: **Android** ou **iOS**
3. Configure conforme sua plataforma
4. Para Android: adicione SHA-1 do certificado debug
5. Para iOS: configure Bundle ID

## 🖥️ Configuração do Servidor OAuth

### 1. Instalar Dependências

```bash
cd example/server
dart pub get
```

### 2. Configurar Credenciais

```bash
# Copie o template de configuração
cp lib/config.example.dart lib/config.dart

# Edite o arquivo config.dart
nano lib/config.dart  # ou use seu editor preferido
```

**Configure no `config.dart`:**
```dart
static const String googleClientId = 'SEU_CLIENT_ID.apps.googleusercontent.com';
static const String googleClientSecret = 'SEU_CLIENT_SECRET';
```

### 3. Executar o Servidor

```bash
dart run lib/main.dart
```

**Resultado esperado:**
```
🚀 Servidor OAuth iniciado!
📍 URL: http://localhost:8080
🔧 Health check: http://localhost:8080/health
🔐 Auth endpoint: http://localhost:8080/auth/google
```

### 4. Testar o Servidor

Abra no navegador: `http://localhost:8080/health`

Deve retornar:
```json
{
  "status": "healthy",
  "timestamp": "2025-01-XX...",
  "active_states": 0
}
```

## 📱 Configuração do App Flutter

### 1. Instalar Dependências

```bash
cd example/app
flutter pub get
```

### 2. Configurar o App (Opcional)

```bash
# Copie o template (se quiser personalizar)
cp lib/config.example.dart lib/config.dart

# Edite conforme necessário
nano lib/config.dart
```

### 3. Executar o App

#### Web (Recomendado para desenvolvimento)
```bash
flutter run -d chrome
```

#### Mobile (Android)
```bash
flutter run -d android
```

#### Mobile (iOS - apenas macOS)
```bash
flutter run -d ios
```

## 🖼️ Testando Funcionalidade de Crop de Imagens

O exemplo agora inclui suporte completo para crop de imagens. Use o arquivo `custom_provider_no_accounts_example.dart` configurado com crop ativado.

### Executar Exemplo com Crop

```bash
# No diretório submodules/file_drive
flutter run -t example/main.dart
```

### Funcionalidades de Crop Disponíveis

✅ **Crop Ativado**: `enableImageCrop: true`  
✅ **Proporções**: Min 0.5, Max 2.0  
✅ **Tamanho Mínimo**: 200x200 pixels  
✅ **Formatos Suportados**: JPEG, PNG, GIF, WebP  
✅ **Callbacks**: `onImageCropped` com informações detalhadas  

### Como Testar o Crop

1. **Execute o exemplo**: `flutter run -t example/main.dart`
2. **Navegue para a pasta Images**: Você verá uma pasta chamada "Images" na tela principal
3. **Acesse os arquivos de imagem**: Clique na pasta "Images" para ver arquivos de exemplo como:
   - Company Logo.png
   - Marketing Banner.jpg
4. **Encontre o botão de crop**: Em cada arquivo de imagem, clique no menu de **3 pontos (⋮)** no lado direito
5. **Selecione "Crop Image"**: No menu suspenso, escolha a opção "Crop Image" ou "Edit Crop"
6. **Ajuste a área**: Mova e redimensione a área de seleção na tela de crop
7. **Confirme**: Clique em "Confirmar" para aplicar o crop
8. **Veja o resultado**: Um dialog mostrará informações detalhadas do crop

### Onde Encontrar o Botão de Crop

🔍 **Localização do Botão**: 
- O botão de crop **NÃO** é um botão separado visível
- Está dentro do **menu de 3 pontos verticais (⋮)** no lado direito de cada arquivo de imagem
- Aparece apenas para arquivos de imagem (PNG, JPG, GIF, WebP)
- Só aparece quando `enableImageCrop: true` está configurado

📱 **Passos Visuais**:
1. Veja um arquivo de imagem na lista
2. No lado direito do arquivo, procure o ícone **⋮** (três pontos verticais)
3. Clique nos três pontos para abrir o menu
4. Selecione **"Crop Image"** ou **"Edit Crop"** no menu suspenso

⚠️ **Se não conseguir ver o menu**:
- Certifique-se de que está na pasta "Images"
- Verifique se é um arquivo de imagem (não uma pasta)
- O menu aparece apenas em arquivos, não em pastas

### Informações Exibidas no Crop

- Nome do arquivo
- Dimensões originais da imagem
- Dimensões da área cropada
- Posição do crop (x, y)

### Debugging do Crop

O console mostrará logs detalhados:
```
I/flutter: Image cropped: exemplo.jpg
I/flutter: Original size: 1920x1080
I/flutter: Crop area: 100,50 800x600
```

## 🧪 Testando a Integração

### 1. Verificar o Servidor
- Servidor deve estar rodando em `http://localhost:8080`
- Health check deve retornar status "healthy"

### 2. Executar o App
- App deve abrir sem erros
- Deve mostrar exemplos dos componentes
- Status do servidor deve estar visível

### 3. Testar OAuth (quando o widget principal estiver pronto)
1. Click no botão "Adicionar Conta Google Drive"
2. Deve abrir navegador com tela do Google
3. Faça login e autorize as permissões
4. Deve retornar ao app com a conta integrada

## 🐛 Resolução de Problemas

### Erro: "config.dart não encontrado"

**Solução:**
```bash
cp lib/config.example.dart lib/config.dart
# Configure suas credenciais no config.dart
```

### Erro: "redirect_uri_mismatch"

**Causa:** URI de redirect não configurado no Google Console

**Solução:**
1. Vá em Google Console > Credentials
2. Edite suas credenciais OAuth 2.0
3. Adicione: `http://localhost:8080/auth/callback`

### Erro: "invalid_client"

**Causa:** Client ID ou Client Secret incorretos

**Solução:**
1. Verifique se copiou corretamente do Google Console
2. Certifique-se que não há espaços extras
3. Recrie as credenciais se necessário

### Servidor não inicia na porta 8080

**Causa:** Porta já está em uso

**Solução:**
1. Pare outros serviços na porta 8080
2. Ou altere a porta no `config.dart`
3. Lembre de atualizar no Google Console também

### App Flutter não conecta ao servidor

**Verificações:**
1. Servidor está rodando?
2. Firewall bloqueando a porta?
3. URL do servidor está correta no app?

## 📂 Estrutura dos Arquivos

```
example/
├── server/                 # Servidor OAuth
│   ├── lib/
│   │   ├── main.dart      # Ponto de entrada
│   │   ├── oauth_server.dart  # Servidor OAuth
│   │   ├── config.dart    # Suas credenciais (não commitado)
│   │   └── config.example.dart  # Template
│   ├── pubspec.yaml
│   └── .gitignore
│
└── app/                   # App Flutter de exemplo
    ├── lib/
    │   ├── main.dart      # App principal
    │   ├── config.dart    # Configuração (opcional)
    │   └── config.example.dart  # Template
    ├── pubspec.yaml
    └── .gitignore
```

## 🔒 Segurança

- ⚠️ **NUNCA** commite arquivos `config.dart` com credenciais reais
- Use `.gitignore` para proteger credenciais
- Para produção, use variáveis de ambiente
- Revise permissões OAuth periodicamente

## 📚 Próximos Passos

1. **Teste os componentes**: Execute o app e veja os exemplos
2. **Configure OAuth**: Siga o guia para integração completa
3. **Explore o código**: Analise a implementação dos modelos
4. **Personalize**: Adapte para suas necessidades

## 🆘 Suporte

Se encontrar problemas:

1. Verifique os logs do servidor e do app
2. Confirme que as credenciais estão corretas
3. Teste os endpoints do servidor diretamente
4. Consulte a documentação do Google OAuth 2.0

---

**Feito com ❤️ para demonstrar o File Cloud widget**