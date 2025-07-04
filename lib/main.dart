import 'package:flutter/material.dart';

void main() {
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

    _queriedFolders = List.from(_folders);
    
    _searchController.addListener(() {
      setState(() {
        _queriedFolders = _folders
          .where((folder) => folder['title'].toLowerCase().contains(_searchController.text.toLowerCase()))
          .toList();
      });
    });
  }

  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _folders = [
    { 'id': 1, 'title': 'Folder 1' },
    { 'id': 2, 'title': 'Folder 2' },
    { 'id': 3, 'title': 'Folder 3' },
  ];

  List<Map<String, dynamic>> _queriedFolders = [];

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
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.only(left: 15, right: 15),
                floatingLabelBehavior: FloatingLabelBehavior.never,
                hintText: 'Cari folder...',
                border: UnderlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 3 / 2,
                ),
                itemCount: _queriedFolders.length,
                itemBuilder: (context, index) {
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        // Handle folder tap
                      },
                      child: ListTile(title: Text(_queriedFolders[index]['title'])),
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
