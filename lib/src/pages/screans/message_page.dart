import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:players_clique/src/components/my_text_field.dart';
import 'package:provider/provider.dart';

import '../../components/messages/message_user.dart';
import '../../services/auth/auth_service.dart';
import 'chat/chat_page.dart';

class Message_Page extends StatefulWidget {
  @override
  _Message_Page createState() => _Message_Page();
}

class _Message_Page extends State<Message_Page> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final searchFriends = TextEditingController();
  List<DocumentSnapshot> filteredUsers =
      []; // State variable for filtered users
  List<DocumentSnapshot> filteredUsersReUid =
      []; // State variable for filtered users

  Future<List<String>> loadUserField(String fieldName) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    String? uid = authService.getCurrentUserUid();
    if (uid != null) {
      return await authService.getUserList(uid, fieldName);
    } else {
      return [];
    }
  }

  @override
  void initState() {
    super.initState();

    _filterUsersUid(); // Call this method in initState
  }

  @override
  Widget build(BuildContext context) {
    _filterUsersUid();
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: _buildReUserList(),
            ),
          ],
        ),
      ),
    );
  }

  void _filterUsersUid() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    String? uid = authService.getCurrentUserUid();
    if (uid != null) {
      try {
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        List<dynamic> requestRefs = userDoc.get('players');
        List<DocumentSnapshot> requestUsers = [];

        // Assuming requestRefs is a list of user IDs (strings)
        for (var userId in requestRefs) {
          if (userId is String) {
            DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();
            requestUsers.add(docSnapshot);
          } else {
            print("Unexpected type for user ID: $userId");
          }
        }

        //  print("Request Users: $requestUsers"); // Debugging print statement

        if (mounted) {
          setState(() {
            filteredUsersReUid = requestUsers; // Update state here
          });
        }
      } catch (e) {
        print("Error fetching user documents: $e");
      }
    }
  }

  Widget _buildReUserList() {
    // Use the filteredUsers list instead of the stream
    return ListView(
      children: filteredUsersReUid
          .map<Widget>((user) => _buildRequestListItem(user))
          .toList(),
    );
  }

  Widget _buildRequestListItem(DocumentSnapshot document) {
    Map<String, dynamic> data = document.data()! as Map<String, dynamic>;

    if (_auth.currentUser!.email != data['email']) {
      return ListTile(
        title: MessageProfile(
          iconProfile: Image.network(data['photourl']),
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatPage(
                    receiveruserEmail: data['fio'],
                    receiverUserID: data['uid'],
                  ),
                ));
          },
          text: data['fio'],
          uid: data['uid'],
        ),

      );
    } else {
      return Container();
    }
  }
}
