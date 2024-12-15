import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Social App',
      home: FeedScreen(),
    );
  }
}

class FeedScreen extends StatelessWidget {
  final Stream<QuerySnapshot> _postsStream =
      FirebaseFirestore.instance.collection('posts').snapshots();

  Future<void> _deletePost(BuildContext context, String postId) async {
    await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
  }

  Future<void> _downloadImage(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));
    final bytes = response.bodyBytes;
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/downloaded_image.jpg');
    await tempFile.writeAsBytes(bytes);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image downloaded successfully!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Feed')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _postsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

          final posts = snapshot.data!.docs;
          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return ListTile(
                title: Text(post['title']),
                subtitle: Text(post['description']),
                leading: Image.network(post['imageUrl'], width: 50, height: 50),
                trailing: IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _deletePost(context, post.id),
                ),
                onLongPress: () => _downloadImage(post['imageUrl']),
              );
            },
          );
        },
      ),
    );
  }
}

class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  XFile? _image;

  Future<void> _selectImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _image = pickedFile;
    });
  }

  Future<void> _uploadPost() async {
    if (_image != null) {
      // Upload image to Firebase Storage
      final ref = FirebaseStorage.instance.ref().child('posts/${_image!.name}');
      await ref.putFile(File(_image!.path));

      // Save post info to Firestore
      final imageUrl = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('posts').add({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'imageUrl': imageUrl,
      });

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Upload Post')),
      body: Column(
        children: [
          TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Title')),
          TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Description')),
          _image == null
              ? Text('No image selected')
              : Image.file(File(_image!.path), width: 100, height: 100),
          ElevatedButton(onPressed: _selectImage, child: Text('Select Image')),
          ElevatedButton(onPressed: _uploadPost, child: Text('Upload Post')),
        ],
      ),
    );
  }
}

class UpdateScreen extends StatefulWidget {
  final String postId;
  final String initialTitle;
  final String initialDescription;
  final String initialImageUrl;

  UpdateScreen({
    required this.postId,
    required this.initialTitle,
    required this.initialDescription,
    required this.initialImageUrl,
  });

  @override
  _UpdateScreenState createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  XFile? _image;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.initialTitle;
    _descriptionController.text = widget.initialDescription;
  }

  Future<void> _updatePost() async {
    // Logic to update the post in Firestore and Firebase Storage.
    if (_image != null) {
      final ref = FirebaseStorage.instance.ref().child('posts/${_image!.name}');
      await ref.putFile(File(_image!.path));

      final imageUrl = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'imageUrl': imageUrl,
      });
    } else {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({
        'title': _titleController.text,
        'description': _descriptionController.text,
      });
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Post')),
      body: Column(
        children: [
          TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Title')),
          TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Description')),
          _image == null
              ? Image.network(widget.initialImageUrl)
              : Image.file(File(_image!.path)),
          ElevatedButton(
              onPressed: () => _updatePost(), child: Text('Update Post')),
        ],
      ),
    );
  }
}
