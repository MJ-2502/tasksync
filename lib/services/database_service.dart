import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';

class TaskService {
  final CollectionReference tasksCollection =
      FirebaseFirestore.instance.collection('tasks');

  // Create Task
  Future<void> addTask(Task task) async {
    await tasksCollection.add(task.toMap());
  }

  // Read Tasks (Stream for real-time updates)
  Stream<List<Task>> getTasks() {
    return tasksCollection.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => Task.fromDoc(doc)).toList(),
        );
  }

  // Update Task
  Future<void> updateTask(Task task) async {
    await tasksCollection.doc(task.id).update(task.toMap());
  }

  // Delete Task
  Future<void> deleteTask(String id) async {
    await tasksCollection.doc(id).delete();
  }
}
