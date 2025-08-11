import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_drive/src/widgets/provider_content.dart';
import 'package:file_drive/src/models/file_drive_config.dart';
import 'package:file_drive/src/providers/base/cloud_provider.dart';
import '../test_helpers.dart';

void main() {
  group('ProviderContent - Error State', () {
    testWidgets('should show error state with try again button only', (WidgetTester tester) async {
      // Criar um mock provider
      final mockProvider = MockTestCloudProvider();
      final theme = FileDriveTheme.light();
      
      // Simular estado de erro
      mockProvider.simulateError();
      
      // Construir o widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderContent(
              provider: mockProvider,
              theme: theme,
            ),
          ),
        ),
      );
      
      // Verificar que a tela de erro é exibida
      expect(find.text('Erro de Conexão'), findsOneWidget);
      expect(find.text('Tentar Novamente'), findsOneWidget);
      
      // Verificar que o botão Voltar não existe mais
      expect(find.text('Voltar'), findsNothing);
      
      // Verificar que o provider está em estado de erro
      expect(mockProvider.status, equals(ProviderStatus.error));
    });
    
    testWidgets('should call authenticate when try again button is pressed', (WidgetTester tester) async {
      final mockProvider = MockTestCloudProvider();
      final theme = FileDriveTheme.light();
      
      // Simular estado de erro
      mockProvider.simulateError();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderContent(
              provider: mockProvider,
              theme: theme,
            ),
          ),
        ),
      );
      
      // Verificar estado inicial de erro
      expect(find.text('Erro de Conexão'), findsOneWidget);
      
      // Reset the flag before testing
      mockProvider.resetAuthenticateFlag();
      
      // Pressionar o botão Tentar Novamente
      await tester.tap(find.text('Tentar Novamente'));
      await tester.pumpAndSettle();
      
      // Verificar que o método authenticate foi chamado
      expect(mockProvider.lastAuthenticateCalled, isTrue);
    });
  });
}