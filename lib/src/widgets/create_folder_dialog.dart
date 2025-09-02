import 'package:flutter/material.dart';
import '../models/file_entry.dart';
import '../theme/app_constants.dart';

/// Dialog for creating a new folder with validation
class CreateFolderDialog extends StatefulWidget {
  /// The parent folder where the new folder will be created
  final FileEntry? parentFolder;
  
  /// Callback when folder creation is confirmed
  final void Function(String folderName)? onCreateFolder;
  
  /// Initial folder name (for pre-filling)
  final String? initialName;
  
  /// List of existing folder names to avoid duplicates
  final List<String>? existingNames;
  
  /// Custom validation function
  final String? Function(String name)? customValidator;

  const CreateFolderDialog({
    super.key,
    this.parentFolder,
    this.onCreateFolder,
    this.initialName,
    this.existingNames,
    this.customValidator,
  });

  @override
  State<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<CreateFolderDialog> {
  late final TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();
  bool _isCreating = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (_validationError != null) {
      setState(() {
        _validationError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.create_new_folder,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppConstants.spacingS),
          const Text('Nova Pasta'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location info
              if (widget.parentFolder != null) ...[
                Text(
                  'Localização:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppConstants.paddingS),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppConstants.radiusS),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppConstants.spacingS),
                      Expanded(
                        child: Text(
                          widget.parentFolder!.name,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.spacingM),
              ],

              // Folder name input
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nome da pasta',
                  hintText: 'Digite o nome da nova pasta',
                  prefixIcon: const Icon(Icons.folder_outlined),
                  border: const OutlineInputBorder(),
                  errorText: _validationError,
                ),
                validator: _validateFolderName,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _createFolder(),
                enabled: !_isCreating,
              ),

              const SizedBox(height: AppConstants.spacingM),

              // Validation info
              _buildValidationInfo(context),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isCreating ? null : _createFolder,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Criar'),
        ),
      ],
    );
  }

  Widget _buildValidationInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingS),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Regras para nomes de pastas:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          _buildValidationRule(
            context,
            'Não pode estar vazio',
            _nameController.text.trim().isNotEmpty,
          ),
          _buildValidationRule(
            context,
            'Máximo 255 caracteres',
            _nameController.text.length <= 255,
          ),
          _buildValidationRule(
            context,
            'Sem caracteres especiais (/ \\ : * ? " < > |)',
            !_hasInvalidCharacters(_nameController.text),
          ),
          if (widget.existingNames?.isNotEmpty == true)
            _buildValidationRule(
              context,
              'Nome único (não existente)',
              !_isDuplicateName(_nameController.text),
            ),
        ],
      ),
    );
  }

  Widget _buildValidationRule(BuildContext context, String rule, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: isValid 
                ? Colors.green 
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              rule,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isValid 
                    ? Colors.green 
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _validateFolderName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nome da pasta é obrigatório';
    }

    final name = value.trim();

    // Check parent folder validation if available
    if (widget.parentFolder != null) {
      final validation = widget.parentFolder!.validateSubfolderCreation(
        folderName: name,
      );
      
      if (!validation.isValid) {
        return validation.error;
      }
    }

    // Check length
    if (name.length > 255) {
      return 'Nome muito longo (máximo 255 caracteres)';
    }

    // Check invalid characters
    if (_hasInvalidCharacters(name)) {
      return 'Nome contém caracteres inválidos';
    }

    // Check for duplicates
    if (_isDuplicateName(name)) {
      return 'Já existe uma pasta com este nome';
    }

    // Custom validation
    if (widget.customValidator != null) {
      final customError = widget.customValidator!(name);
      if (customError != null) {
        return customError;
      }
    }

    return null;
  }

  bool _hasInvalidCharacters(String name) {
    final invalidChars = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];
    return invalidChars.any((char) => name.contains(char));
  }

  bool _isDuplicateName(String name) {
    if (widget.existingNames == null) return false;
    
    final normalizedName = name.trim().toLowerCase();
    return widget.existingNames!.any(
      (existing) => existing.toLowerCase() == normalizedName,
    );
  }

  void _createFolder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final folderName = _nameController.text.trim();
    
    setState(() {
      _isCreating = true;
      _validationError = null;
    });

    try {
      // Simulate creation delay for better UX
      await Future.delayed(const Duration(milliseconds: 500));
      
      widget.onCreateFolder?.call(folderName);
      
      if (mounted) {
        Navigator.of(context).pop(folderName);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _validationError = 'Erro ao criar pasta: $e';
          _isCreating = false;
        });
      }
    }
  }

}