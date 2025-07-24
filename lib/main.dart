import 'package:flutter/material.dart';
import 'package:notelance/add_folder_dialog.dart';
import 'package:notelance/models/folder.dart';
import 'package:notelance/sqllite.dart';
import 'package:logger/logger.dart';

var logger = Logger();

void main() async {
  await loadSQLite();
  runApp(const Notelance());
}

class Notelance extends StatefulWidget {
  const Notelance({super.key});

  @override
  State<Notelance> createState() => _NotelanceState();
}

class _NotelanceState extends State<Notelance> {
  @override
  void initState() {
    super.initState();
    _loadFolders();

    _searchController.addListener(() => _queryFolders());
  }

  final TextEditingController _searchController = TextEditingController();

  List<Folder> _folders = [];
  List<Folder> _queriedFolders = [];

  void _queryFolders() {
    setState(() {
      _queriedFolders = _folders
          .where((folder) => folder.name.toLowerCase().contains(_searchController.text.toLowerCase()))
          .toList();
    });
  }

  // Load folders from database
  Future<void> _loadFolders() async {
    if (database == null) return;

    try {
      final List<Map<String, dynamic>> foldersFromDb = await database!.query('Folders');
      setState(() {
        _folders = foldersFromDb
            .map((folderJson) => Folder.fromJson(folderJson))
            .toList();

        _queriedFolders = List.from(_folders);
      });
    } catch (e) {
      logger.e(e.toString());
    }
  }

  void _showAddFolderDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AddFolderDialog(
          onAdded: (folder) {
            setState(() => _folders.add(folder));
            _queryFolders();
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notelance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Notelance')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.only(left: 15, right: 15),
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  hintText: 'Cari folder...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Builder(
                    builder: (context) {
                      return ElevatedButton(
                        onPressed: () => _showAddFolderDialog(context),
                        child: Text('Buat Folder'),
                      );
                    }
                ),
              ),
            ),
            SizedBox(height: 10),
            Expanded(
              child: _queriedFolders.isEmpty
                  ? Center(
                child: Text(
                  _folders.isEmpty
                      ? 'Belum ada folder. Buat folder pertama Anda!'
                      : 'Tidak ada folder yang cocok dengan pencarian.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              )
                  : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 3 / 2,
                ),
                itemCount: _queriedFolders.length,
                itemBuilder: (context, index) {
                  final folder = _queriedFolders[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        // Handle folder tap
                        print('Tapped folder: ${folder.name} (ID: ${folder.id})');
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder,
                              size: 48,
                              color: Theme.of(context).primaryColor,
                            ),
                            SizedBox(height: 8),
                            Text(
                              folder.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}