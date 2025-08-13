# Como usar o script find_class_definition.sh

## Instalação
```bash
# Tornar o script executável
chmod +x find_class_definition.sh
```

## Uso básico
```bash
# Procurar uma classe específica
./find_class_definition.sh NomeDaClasse

# Exemplos
./find_class_definition.sh ThumbnailImage
./find_class_definition.sh FileEntry
./find_class_definition.sh GoogleDriveProvider
```

## O que o script faz

1. **Verifica dependências**: Confirma se o Dart SDK está instalado
2. **Busca com grep**: Procura por definições de classe (class, abstract class, mixin, enum)
3. **Análise complementar**: Usa ferramentas do Dart para encontrar usos da classe
4. **Relatório detalhado**: Mostra arquivo, linha e contexto onde a classe foi encontrada

## Exemplo de saída
```
🔍 Procurando definição da classe: ThumbnailImage
📁 Diretório atual: /Users/jonathanrezende/Projects/dart/mkd/submodules/file_drive

════════════════════════════════════════════
🔍 Procurando com grep...
✅ Definições encontradas:
   📄 ./lib/src/widgets/thumbnail_image.dart:4
      class ThumbnailImage extends StatefulWidget {

════════════════════════════════════════════
🔍 Procurando com dart analyzer...
✅ Arquivos contendo 'ThumbnailImage':
   📄 ./lib/src/widgets/thumbnail_image.dart
      4:class ThumbnailImage extends StatefulWidget {
      26:  const ThumbnailImage({
      38:  State<ThumbnailImage> createState() => _ThumbnailImageState();
```

## Funcionalidades

- ✅ Encontra definições de classes
- ✅ Encontra usos da classe
- ✅ Mostra número da linha
- ✅ Exibe contexto do código
- ✅ Funciona sem LSP configurado
- ✅ Cria pubspec.yaml temporário se necessário
- ✅ Sugestões de comandos adicionais

## Tipos de definições encontradas

- `class NomeClasse`
- `abstract class NomeClasse`
- `mixin NomeClasse`
- `enum NomeClasse`

## Limitações

- Não usa LSP real (usa grep + dart analyzer básico)
- Limitado a busca textual
- Não resolve referências complexas
- Melhor para projetos Dart/Flutter organizados