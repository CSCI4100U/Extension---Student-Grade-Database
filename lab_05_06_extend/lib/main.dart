import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as Path;
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:io';

class Grade {
  int? id;
  String sid;
  String grade;

  Grade(this.sid, this.grade);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sid': sid,
      'grade': grade,
    };
  }

  Grade.fromMap(Map<String, dynamic> map)
      : id = map['id'],
        sid = map['sid'],
        grade = map['grade'];
}

enum SortOption { increasingSid, decreasingSid, increasingGrade, decreasingGrade }

class GradesModel {
  late Database database;

  GradesModel() {
    initDatabase();
  }

  Future<void> initDatabase() async {
    database = await openDatabase(
      Path.join(await getDatabasesPath(), 'grades_database.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE grades(id INTEGER PRIMARY KEY AUTOINCREMENT, sid TEXT, grade TEXT)',
        );
      },
      version: 1,
    );
  }

  Future<int> insertGrade(Grade grade) async {
    final id = await database.insert(
      'grades',
      grade.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<void> updateGrade(Grade grade) async {
    await database.update(
      'grades',
      grade.toMap(),
      where: 'id = ?',
      whereArgs: [grade.id],
    );
  }

  Future<void> deleteGradeById(int id) async {
    await database.delete(
      'grades',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Grade>> getAllGrades(SortOption sortOption) async {
    String orderBy;
    switch (sortOption) {
      case SortOption.increasingSid:
        orderBy = 'sid ASC';
        break;
      case SortOption.decreasingSid:
        orderBy = 'sid DESC';
        break;
      case SortOption.increasingGrade:
        orderBy = 'grade ASC';
        break;
      case SortOption.decreasingGrade:
        orderBy = 'grade DESC';
        break;
    }

    final List<Map<String, dynamic>> maps = await database.query('grades', orderBy: orderBy);

    return List.generate(maps.length, (i) {
      return Grade.fromMap(maps[i]);
    });
  }

  Future<Map<String, int>> getGradeFrequency() async {
    final List<Map<String, dynamic>> maps =
        await database.rawQuery('SELECT grade, COUNT(*) as frequency FROM grades GROUP BY grade ORDER BY grade ASC');
    Map<String, int> frequencyMap = {};
    for (var map in maps) {
      frequencyMap[map['grade']] = map['frequency'];
    }
    return frequencyMap;
  }

  Future<List<Grade>> searchGradesBySid(String sid) async {
    final List<Map<String, dynamic>> maps = await database.query('grades', where: 'sid LIKE ?', whereArgs: ['%$sid%']);
    return List.generate(maps.length, (i) {
      return Grade.fromMap(maps[i]);
    });
  }

  Future<double> getAverageGrade() async {
    final List<Map<String, dynamic>> maps = await database.rawQuery('SELECT AVG(CAST(grade AS REAL)) as average FROM grades');
    return maps.first['average'] ?? 0.0;
  }

  Future<String> getHighestGrade() async {
    final List<Map<String, dynamic>> maps = await database.rawQuery('SELECT MAX(grade) as highest FROM grades');
    return maps.first['highest'] ?? 'N/A';
  }

  Future<String> getLowestGrade() async {
    final List<Map<String, dynamic>> maps = await database.rawQuery('SELECT MIN(grade) as lowest FROM grades');
    return maps.first['lowest'] ?? 'N/A';
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Forms and SQLite',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Forms and SQLite'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GradesModel gradesModel = GradesModel();
  final List<Grade> grades = [];
  int? _selectedIndex;
  SortOption _currentSortOption = SortOption.increasingSid;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadGrades();
  }

  void _editGrade() {
    if (_selectedIndex is int) {
      print('Edit grade button pressed for grade at index $_selectedIndex');
      _showEditMenu(grades[_selectedIndex!]);
    } else {
      print('Please select a grade to edit');
    }
  }

  void _deleteGrade(int index) {
    final id = grades[index].id;
    if (id != null) {
      gradesModel.deleteGradeById(id);
      loadGrades();
    }
  }

  void _addGrade() {
    print('Add grade button pressed');
    Navigator.push(context, MaterialPageRoute(builder: (context) => GradeForm(Grade('', ''), gradesModel)))
        .then((newGrade) {
      if (newGrade != null) {
        loadGrades();
      }
    });
  }

  Future<void> loadGrades() async {
    final allGrades = await gradesModel.getAllGrades(_currentSortOption);
    setState(() {
      grades.clear();
      grades.addAll(allGrades);
    });
  }

  void _showEditMenu(Grade grade) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _editGradeWithForm(grade);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  gradesModel.deleteGradeById(grade.id!);
                  loadGrades();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _editGradeWithForm(Grade grade) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => GradeForm(grade, gradesModel)))
        .then((editedGrade) {
      if (editedGrade != null) {
        loadGrades();
      }
    });
  }

  void _sortGrades(SortOption sortOption) {
    setState(() {
      _currentSortOption = sortOption;
    });
    loadGrades();
  }

  void _showGradeChart() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16.0),
          child: FutureBuilder<Map<String, int>>(
            future: gradesModel.getGradeFrequency(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else {
                  return DataTable(
                    columns: [
                      DataColumn(label: Text('Grade')),
                      DataColumn(label: Text('Frequency')),
                    ],
                    rows: snapshot.data!.entries.map((entry) {
                      return DataRow(cells: [
                        DataCell(Text(entry.key)),
                        DataCell(Text(entry.value.toString())),
                      ]);
                    }).toList(),
                  );
                }
              } else {
                return Center(child: CircularProgressIndicator());
              }
            },
          ),
        );
      },
    );
  }

  void _importCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        String? filePath = result.files.single.path;

        if (filePath != null) {
          String fileContent = await File(filePath).readAsString();
          List<List<dynamic>> csvGrades = CsvToListConverter().convert(fileContent);

          for (List<dynamic> csvGrade in csvGrades) {
            if (csvGrade.length == 2) {
              String sid = csvGrade[0].toString();
              String grade = csvGrade[1].toString();

              Grade newGrade = Grade(sid, grade);
              await gradesModel.insertGrade(newGrade);
            }
          }
          loadGrades(); 
        }
      }
    } catch (e) {
      print('Error importing CSV: $e');
    }
  }

  void _searchGrades(String searchText) async {
    if (searchText.isNotEmpty) {
      final searchResults = await gradesModel.searchGradesBySid(searchText);
      setState(() {
        grades.clear();
        grades.addAll(searchResults);
      });
    } else {
      loadGrades(); 
    }
  }

  void _showStatistics() async {
    double averageGrade = await gradesModel.getAverageGrade();
    String highestGrade = await gradesModel.getHighestGrade();
    String lowestGrade = await gradesModel.getLowestGrade();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Statistics'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Average Grade: ${averageGrade.toStringAsFixed(2)}'),
              Text('Highest Grade: $highestGrade'),
              Text('Lowest Grade: $lowestGrade'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          PopupMenuButton<SortOption>(
            onSelected: (SortOption result) {
              _sortGrades(result);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
              const PopupMenuItem<SortOption>(
                value: SortOption.increasingSid,
                child: Text('Sort by Increasing Sid'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.decreasingSid,
                child: Text('Sort by Decreasing Sid'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.increasingGrade,
                child: Text('Sort by Increasing Grade'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.decreasingGrade,
                child: Text('Sort by Decreasing Grade'),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.bar_chart),
            onPressed: _showGradeChart,
          ),
          IconButton(
            icon: Icon(Icons.file_upload),
            onPressed: _importCSV,
          ),
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              _searchGrades(_searchController.text);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by Student ID',
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _searchGrades('');
                  },
                ),
              ),
              onChanged: (value) {
                _searchGrades(value);
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: grades.length,
              itemBuilder: (context, index) {
                final grade = grades[index];
                return Dismissible(
                  key: Key(grade.id.toString()),
                  onDismissed: (direction) {
                    _deleteGrade(index);
                  },
                  background: Container(
                    color: Colors.red,
                    child: Icon(Icons.delete, color: Colors.white),
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: 20.0),
                  ),
                  child: GestureDetector(
                    onLongPress: () {
                      setState(() {
                        _selectedIndex = index;
                      });
                      _showEditMenu(grade);
                    },
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedIndex == index ? Colors.blue : Colors.transparent,
                      ),
                      child: ListTile(
                        title: Text(grade.sid),
                        subtitle: Text(grade.grade),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _showStatistics,
              child: Text('Show Statistics'),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGrade,
        tooltip: 'Add Grade',
        child: Icon(Icons.add),
      ),
    );
  }
}

class GradeForm extends StatelessWidget {
  final Grade grade;
  final GradesModel gradesModel;

  GradeForm(this.grade, this.gradesModel);

  void _updateSid(String value) {
    grade.sid = value;
  }

  void _updateGrade(String value) {
    grade.grade = value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Grade Form'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Text('Sid: '),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: grade.sid),
                    onChanged: (value) {
                      _updateSid(value);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.0),
            Row(
              children: [
                Text('Grade: '),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: grade.grade),
                    onChanged: (value) {
                      _updateGrade(value);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (grade.id == null) {
            gradesModel.insertGrade(grade).then((id) {
              grade.id = id;
              Navigator.of(context).pop(grade);
            });
          } else {
            gradesModel.updateGrade(grade).then((_) {
              Navigator.of(context).pop(grade);
            });
          }
        },
        tooltip: 'Save',
        child: Icon(Icons.save),
      ),
    );
  }
}