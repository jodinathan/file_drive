# Configuração OAuth - Setup de Desenvolvimento

## 🚀 Setup Rápido

### 1. Configure as Credenciais OAuth

```bash
# Copie o template de configuração
cp lib/src/config/config.example.dart lib/src/config/config.dart
```

### 2. Edite suas Credenciais

Abra `lib/src/config/config.dart` e substitua:

```dart
static const String clientId = 'SUA_CLIENT_ID_REAL.apps.googleusercontent.com';
```

### 3. Configure o Example Server (Opcional)

Para desenvolvimento local, você pode usar o servidor OAuth incluído:

```bash
# Execução básica (porta 8080)
cd example_server
dart run

# Execução com porta customizada
dart run -p 3000
dart run --port=9000

# Ver todas as opções
dart run --help
```

### 4. Configure o macOS (se necessário)

```bash
# Configure a variável de ambiente (opcional)
export GOOGLE_CLIENT_ID="sua_client_id_real.apps.googleusercontent.com"

# Execute o script de configuração para macOS
./scripts/configure_macos_oauth.sh
```

### 5. Execute o Projeto

```bash
flutter run
```

## 📁 Estrutura de Arquivos

```
lib/src/config/
├── config.dart          # ❌ NUNCA commitar (suas credenciais)
└── config.example.dart  # ✅ Template público
```

## 🔒 Segurança

- ✅ `config.dart` está no `.gitignore`
- ✅ Apenas o template `config.example.dart` vai para o git
- ✅ Suas credenciais ficam apenas na sua máquina local

## 🛠️ Como Obter Credenciais Google

1. Acesse [Google Cloud Console](https://console.cloud.google.com/)
2. Crie um projeto ou selecione um existente
3. Vá em **APIs & Services > Credentials**
4. Clique em **Create Credentials > OAuth 2.0 Client IDs**
5. Configure para aplicação **Desktop application**
6. Copie o **Client ID** gerado

## 🎯 Redirect URIs

O sistema calcula automaticamente o redirect URI baseado no seu clientId:

```dart
// Se seu clientId for: 123456789-abc.apps.googleusercontent.com
// O redirect URI será: com.googleusercontent.apps.123456789
```

## ❓ Problemas Comuns

### ClientId não encontrado
- Verifique se copiou o template: `cp lib/src/config/config.example.dart lib/src/config/config.dart`
- Verifique se editou o clientId em `config.dart`

### OAuth não funciona
- Verifique se o clientId está correto
- Verifique se configurou os redirect URIs no Google Console

### Projeto não compila
- Execute `flutter clean && flutter pub get`
- Verifique se o arquivo `config.dart` existe