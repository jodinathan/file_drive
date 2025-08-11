# Plano de Refatoração da Lista de Contas

## Objective
Refatorar a exibição da lista de contas integradas para fornecer uma experiência de usuário mais robusta, elegante e informativa. O novo design substituirá o carrossel horizontal por uma lista vertical ou grade de "cards" de conta detalhados.

## Implementation Plan
1. **Criar um modelo de dados de conta fortemente tipado**
   - Dependencies: None
   - Notes: Substituir o `Map<String, dynamic>` por uma classe `CloudAccount` em `lib/src/models/cloud_account.dart`. Esta classe conterá todos os detalhes da conta: `id`, `name`, `email`, `pictureUrl`, `status` (um enum como `AccountStatus`), etc.
   - Files: `lib/src/models/cloud_account.dart`
   - Status: Not Started
2. **Refatorar `OAuthCloudProvider` para usar o novo modelo**
   - Dependencies: Task 1
   - Notes: Modificar o método `getAllUsers()` em `lib/src/providers/base/oauth_cloud_provider.dart` para retornar uma `List<CloudAccount>` em vez de um `Map<String, Map<String, dynamic>>`. A lógica para determinar o status da conta será encapsulada aqui.
   - Files: `lib/src/providers/base/oauth_cloud_provider.dart`
   - Status: Not Started
3. **Criar o novo widget `AccountCard`**
   - Dependencies: Task 1
   - Notes: Desenvolver um novo `StatelessWidget` chamado `AccountCard` em `lib/src/widgets/account_card.dart`. Este widget receberá um objeto `CloudAccount` e renderizará a interface do usuário para um único card de conta. Ele lidará com a exibição de todas as informações da conta, incluindo foto, nome, e-mail e status. Ele também conterá o menu de ações (remover, reautenticar).
   - Files: `lib/src/widgets/account_card.dart`
   - Status: Not Started
4. **Criar o novo widget `AccountListView`**
   - Dependencies: Task 2, Task 3
   - Notes: Criar um novo `StatefulWidget` chamado `AccountListView` em `lib/src/widgets/account_list_view.dart`. Este widget substituirá o `AccountCarousel`. Ele buscará a lista de `CloudAccount`s do `OAuthCloudProvider` e usará um `ListView.builder` ou `GridView.builder` para exibir os `AccountCard`s.
   - Files: `lib/src/widgets/account_list_view.dart`
   - Status: Not Started
5. **Integrar `AccountListView` no `FileDriveWidget`**
   - Dependencies: Task 4
   - Notes: Substituir a chamada para `AccountCarousel` por `AccountListView` dentro de `lib/src/widgets/file_drive_widget.dart`.
   - Files: `lib/src/widgets/file_drive_widget.dart`
   - Status: Not Started
6. **Remover o `AccountCarousel` antigo**
   - Dependencies: Task 5
   - Notes: Após a integração bem-sucedida do `AccountListView`, o arquivo `lib/src/widgets/account_carousel.dart` pode ser excluído com segurança.
   - Files: `lib/src/widgets/account_carousel.dart`
   - Status: Not Started

## Verification Criteria
- A lista de contas é exibida como uma lista vertical ou grade de cards.
- Cada card de conta exibe a foto do usuário, nome, e-mail e status da conta.
- O status da conta (por exemplo, "Conectado", "Requer atenção") é claramente visível.
- O menu de ações em cada card permite que o usuário remova a conta ou inicie a reautenticação.
- A interface do usuário é atualizada corretamente após a remoção de uma conta ou uma tentativa de reautenticação.
- O código está bem estruturado, segue as melhores práticas do Flutter e não contém erros de análise.

## Potential Risks and Mitigations
1. **Complexidade do gerenciamento de estado**: A lógica para atualizar a interface do usuário em resposta às ações do usuário (remover, reautenticar) pode se tornar complexa.
   - **Mitigation**: Utilizar um `ChangeNotifier` ou um padrão de gerenciamento de estado semelhante no `OAuthCloudProvider` para notificar os widgets sobre as alterações de dados. O `AccountListView` ouvirá essas alterações e se reconstruirá conforme necessário.
2. **Regressões inesperadas**: A refatoração do `OAuthCloudProvider` pode introduzir bugs em outras partes do aplicativo que dependem dele.
   - **Mitigation**: Executar todos os testes existentes após a refatoração. Adicionar novos testes de unidade e de widget para o novo modelo `CloudAccount` e os widgets `AccountCard` e `AccountListView` para garantir que eles se comportem conforme o esperado.
3. **Problemas de design da interface do usuário**: O novo design do `AccountCard` pode não ser visualmente atraente ou fácil de usar em todos os cenários.
   - **Mitigation**: Começar com um design simples e iterar sobre ele. Considerar a possibilidade de obter feedback sobre o design em um estágio inicial.

## Alternative Approaches
1. **Manter o `Map<String, dynamic>`**: Em vez de introduzir um modelo fortemente tipado, poderíamos continuar usando o mapa, mas encapsular a lógica de acesso aos dados em funções de ajuda. Isso reduziria a quantidade de refatoração, mas resultaria em um código menos robusto e mais propenso a erros.
2. **Modificar o `AccountCarousel` existente**: Em vez de criar novos widgets, poderíamos modificar o `AccountCarousel` para exibir os cards em um layout vertical. Isso poderia ser mais rápido, mas resultaria em um widget com múltiplas responsabilidades, tornando-o mais difícil de manter a longo prazo.
