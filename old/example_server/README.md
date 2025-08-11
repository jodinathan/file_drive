# 🖥️ Example Server - Servidor OAuth para Google Drive

Servidor simples que facilita a autenticação OAuth com Google Drive para desenvolvimento local.

## 🚀 Como usar

### Execução básica (porta padrão 8080):
```bash
cd example_server
dart run
```

### Execução com porta customizada:
```bash
# Usando -p ou --port
dart run -p 3000
dart run --port 3000

# Usando formato --port=
dart run --port=8080
```

### Ver ajuda:
```bash
dart run --help
dart run -h
```

## 📋 Opções disponíveis

| Opção | Descrição | Exemplo |
|-------|-----------|---------|
| `-p <porta>` | Define a porta do servidor | `dart run -p 3000` |
| `--port <porta>` | Define a porta do servidor | `dart run --port 3000` |
| `--port=<porta>` | Define a porta do servidor (formato alternativo) | `dart run --port=8080` |
| `-h, --help` | Mostra mensagem de ajuda | `dart run -h` |

## ⚙️ Configuração

Antes de executar, certifique-se de ter configurado o arquivo `config.dart` com suas credenciais OAuth do Google.

## 🔗 URLs importantes

Quando o servidor estiver rodando, você verá algo como:
```
✅ Servidor rodando em localhost:8080
🔗 OAuth URL: http://localhost:8080/auth/google
```

Use a URL OAuth mostrada para configurar seu cliente Flutter.

## 🛠️ Desenvolvimento

Para desenvolvimento com hot reload do servidor:
```bash
dart run --enable-vm-service -p 3000
```