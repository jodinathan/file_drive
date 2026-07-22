import 'dart:typed_data';
import 'package:flutter/widgets.dart';

/// Ponto de extensão de edição criativa ("estilizador") do file_cloud. Recebe os
/// BYTES do original (o file_cloud os baixa de qualquer provider) e devolve os
/// bytes editados, ou `null` se o usuário CANCELAR (a seleção é abortada). A
/// implementação (ex.: `pro_image_editor`) mora no app — o file_cloud não conhece
/// o pacote. Espelha o princípio de ponto de extensão do `externalFileFactory` do
/// oni_front.
typedef ImageStylizer = Future<Uint8List?> Function(
  BuildContext context, {
  required Uint8List bytes,
  String? mimeType,
});
