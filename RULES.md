## OBJETIVO
- O objetivo deste projeto é facilitar o acesso aos arquivos de provedores de serviços de nuvem, como o Dropbox, Google Drive, OneDrive, provedores customizados, etc.

## CÓDIGO
- Código Nível senior. 
- Não pode haver gambiarras ou código desnecessário.
- Deve haver asserts() pelo sistema para garantir que as informações estejam conforme esperado. Por ex: strings que não podem ser vazias, inteiros que não podem ser negativos ou zero, etc.


## DIRETRIZES
- O projeto deve exportar apenas 1 widget e outras propriedades auxiliares necessárias para o funcionamento do widget (interfaces, callbacks etc). Este widget deve ser configurável para que todas funcionalidades funcionem como esperado.
- Deve existir uma classe base para provedores onde deve ficar o core das funcionalidades, restando aos provedores somente os percaussos necessários de cada um. Deve haver métodos ou variáveis abstratas (prefira métodos quando fizer sentido) que devem ser sobrescritos pelos provedores. Cada provedor deve ter nome e o nome da imagem para ser usada como logo. Lista de métodos abstratos necessários, porém, podem haver mais: listFolder, createFolder, deleteEntry, downloadFile, uploadFile(com progresso, pode retornar um Stream), searchByName, getUserProfile, refreshAuth, getCapabilities.
- O nome do arquivo baixado deve ser o nome do arquivo original. 
- Utilize as melhores práticas para o download funcionar em qualquer plataforma, mesmo os arquivos grandes.
- Nem todos provedores suportam todas operações (ex.: busca, exclusão permanente, upload em chunks). Deve-se padronizar via “capabilities” para o widget se adaptar
- A busca por nome deve ser global no provedor, ter um debounce(~400ms) e um botão para limpar o conteúdo do campo de busca.
- A lista de arquivos e pastas deve ter um infinite scroll (50 itens por página).
- O widget deve receber uma lista de provedores para poder ser configurado e ter ao menos um provedor. Nos parametros do provedor, deve-se enviar um método que gera a URL com parametros necessários para abrir o site de autenticação via oauth2. Normalmente essa URL é uma URL do servidor interno e que faz redirect para o site de autenticação. Fluxo esperado pelo servidor (sem PKCE): o app inicia o OAuth em /auth/google?state=<id>; o servidor faz a troca code→tokens e armazenapor state; após o redirect, o app captura state e busca os tokens em /auth/tokens/<state>. 
- O app não pode em hipótese alguma ter o client secret. A conversa com o provedor para autenticação deve ser feita via servidor interno pela URL que é passada para o widget como argumento.
- Deve-se utilizar o pacote `flutter_web_auth_2` para autenticação via oauth2: https://pub.dev/packages/flutter_web_auth_2
- Em Flutter Web deve-se utilizar https para redirect e scheme para mobile/desktop para autenticação via oauth2.
- O projeto deve ter os logos dos provedores embutidos.
- Este é um projeto standalone, portanto, classes e quaisquer códigos não utilizados dentro do próprio pacote devem ser removidos.
- O projeto está em fase de desenvolvimento, portanto, não deve haver nenhum código depreciado. REMOVA O QUE NÃO FOR UTILIZADO.
- O projeto deverá rodar com o Flutter Web, iOS, Android, Mac e Windows. 
- Prefira utilizar layouts flexíveis que se auto ajustem.
- Tenha um arquivo contendo constantes para serem usadas margins, paddings e quaisquer outros valores que sejam utilizados em vários widgets.
- Deve-se utilizar o Intl para traduções. Crie um arquivo para conter todos `Intl.message`. Crie as mensagens em inglês. Inicialmente teremos suporte a pt-BR.
- Quando um provedor causar erro, prefira estudar o status, a mensagem e utilizar uma mensagem de erro traduzida.
- O projeto não pode utilizar textos sem serem do arquivo de tradução. 
- Deve haver uma classe base para salvar os dados das conta integradadas. O usuário deve passar uma instancia desta classe para o widget.
- Deve haver uma classe que extende a classe base de salvamento e utilize o pacote shared_preferences para salvar os dados das contas integradasdas. Essa será a classe que usaremos no app de exemplo.
- Para cada conta integrada de um provedor, guarde o token de acesso, ID externo, foto, nome, email e o status da integração.   
- Exemplo de FileEntry unificado (id, nome, tipo, tamanho, mimeType, modifiedAt, isFolder, parents, thumbnailUrl, etc.)
- Contas integradas podem ser revogadas no site do provedor (ex.: eu adiciono uma integração no app via Google Drive e depois vou no Google Drive e revogo a integração), por isso, para cada chamada na API, deve-se verificar se o status retornado do erro é referente à perda de acesso ou permissão e corretamente atualizar o status da conta.
- Possíveis status de uma conta integrada: ok, missingScopes, revoked, error. É necessário mapear os tipos de status para refletir a informação correta ao usuário.
- A pasta `working_examples` contém arquivos que fazem o oauth corretamente. Use-o como base para analise. 
- Devem haver templates de arquivos de configuração minimalista, que contém somente informações cruciais para execução de:  testes unitários, widget principal e servidor de exemplo. Por ex: config.example.dart, sendo que o config.dart deve ser o arquivo de configuração que deve ser utilizado e deve existir no .gitignore para não ser enviado com commits.
- Excluir uma conta integrada NÃO deve revogar a conta no provedor.
- Considere `Modo Seleção` quando o widget for configurado como selecionador de arquivos (ex: o sistema da empresa precisa que o usuário selecione arquivos para serem anexados à um formulário)
 - O modo seleção ficará ativo caso o widget tenha sua propriedade `onSelectionConfirm` configurada.
 - O widget deve ter a configuração de quais tipos de arquivos serão permitidos para serem selecionados (lista de mime-types que o usuário deverá preencher. Pode ser um input de chips. Adicione exemplos para filtro padrões como imagens) e a quantidade mínima e máxima. Não será possível selecionar pastas como utilização.
- Precisamos ter testes unitários que validem a integração do oauth e a funcionalidade do widget, porém, como estamos em desenvolvimento, podemos criar os testes unitários depois que validarmos uma primeira versão.

## FUNCIONALIDADES COM PROVEDORES
- Navegar pelas pastas
- Criar e excluir pastas
- Fazer download de arquivos
- Fazer upload de arquivos (mostrar progresso) 
- Todos serviços de provedores deve ser possível com um provedor customizado.
- Vamos iniciar somente com o provedor Google Drive.

## LAYOUT
- Duas colunas
 - Primeira coluna (sempre visível): lista de provedores. Cada provedor deve ser um card cotendo 3 colunas: Logo e nome. Abaixo do nome deve haver a lista das 3 primeiras contas integradas, mostrando a foto de cada uma delas. Caso tenha mais, mostre algo como "+ 2". Se a conta integrada tiver problemas de permissão, circule a foto com uma cor de erro.
 - Segunda coluna (conteúdo dinâmico baseado no provedor selecionado): 
  - Linha do topo (sempre visível) com duas colunas:
   - Primeira coluna (pega o restante to espaço): carousel de contas integradas com aquele provedor e alinhado à esquerda. Cada provedor deve ser um card com 3 colunas: Foto, nome e um botão de menu. A foto deve ficar colada ao container ao lado esquerdo, topo e rodapé e ela deve ser circular. Abaixo do nome deve haver o e-mail da conta. Se a conta tiver problemas de permissão, circule o card com uma cor de erro. O menu deve-se poder reautentivar a conta e exclui-la. Um dialog deve aparecer para confirmar a ação.
   - Segunda coluna: botão de adicionar conta.
  - Linha final (pega o restante do espaço): Navegação de pastas e arquivos. Deve-se conter 2 linhas: 
   - Primeira linha: botão Home, upload e nova pasta. Alinhado à direita, um campo para fazer busca por nome. Ao lado do botão `Nova pasta`, deve-se ter um botão `Utilizar seleção` que aparece apenas se o modo de seleção estiver habilitado. Ele fica habilitado se houver arquivos selecionados conforme a quantidade mínima e máxima configurado no widget principal. Ao lado deste botão, deve-se ter um botão `Excluir selecionados` que aparece apenas se houver arquivos ou pastas selecionados. 
   - Segunda linha (pega o restante do espaço e tem scroll): lista de pastas e arquivos. Caso a integração tenha status de erro, deve-se exibir uma mensagem de erro traduzida baseada no status e um botão para reautenticar/tentar novamente.

## TEMA
- Utilize o ThemeData do Material 3 para o tema do projeto. NÃO USE CORES PRÓPRIAS.
- Apenas os logos dos provedores que terão suas próprias cores.

## FLUXO
Considerando uma nova conta integrada via google drive, o fluxo deve ser o seguinte:
 - O usuário clicka no botão de adicionar conta no topo do widget.
 - O app executa o método de gerar URL para autenticação via oauth2 e executa o flutter_web_auth_2 com a URL gerada.
 - O processo no provedor acontece e é retornado ao app com os dados.
 - Caso o flutter_web_auth_2 de erro, significa que o usuário cancelou o processo. Apenas mostre um dialog informando que o processo foi cancelado, sem alterar o conteúdo do widget.
 - Já no caso de sucesso, o app executa a API para pegar dados da conta como nome, email etc e então gera uma instância de conta integrada.
 - A listagem de contas integradas é atualizada para refletir a nova conta.
 - Selecionamos essa nova conta integrada e o painel de pastas e arquivos é exibido.
 - Caso a conta integrada tenha status de erro, o painel onde ficaria os arquivos e pastas deve exibir uma mensagem de erro traduzida baseada no status e um botão para reautenticar/tentar novamente.

## EXEMPLO
- Deve haver uma pasta example que contem dois diretórios: app e server.
- O server deve conter um projeto Dart que abra um servidor web simples para testarmos o oauth.
- O app deve conter um projeto Flutter que utilize o widget do projeto. Ele deve estar configurado para utilizar o oauth do servidor de exemplo na pasta server.