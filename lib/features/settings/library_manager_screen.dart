import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/models/compendium_source.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/import_service.dart';

class LibraryManagerScreen extends StatelessWidget {
  const LibraryManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Managed Libraries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Import XML',
            onPressed: () => _importFile(context),
          ),
        ],
      ),
      body: ValueListenableBuilder<Box<CompendiumSource>>(
        valueListenable: StorageService.getSourcesListenable(),
        builder: (context, box, child) {
          final sources = box.values.toList();
          
          if (sources.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_books_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No imported libraries',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to import content from FC5 XML files',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }

          // Sort by date descending
          sources.sort((a, b) => b.importedAt.compareTo(a.importedAt));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sources.length,
            itemBuilder: (context, index) {
              final source = sources[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.folder_zip, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                  title: Text(source.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('${source.itemCount} Items, ${source.spellCount} Spells'),
                      Text(
                        'Imported ${DateFormat.yMMMd().format(source.importedAt)}',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, source),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _importFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xml'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final message = await ImportService.importCompendiumFile(file);
        
        if (!context.mounted) return;
        Navigator.pop(context); // Close loader
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } catch (e) {
        if (!context.mounted) return;
        Navigator.pop(context); // Close loader
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, CompendiumSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Library?'),
        content: Text(
          'This will remove "${source.name}" and all associated content:\n\n' 
          '• ${source.itemCount} Items\n' 
          '• ${source.spellCount} Spells\n\n' 
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      
      try {
        await StorageService.deleteSource(source.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Library deleted successfully')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting library: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
