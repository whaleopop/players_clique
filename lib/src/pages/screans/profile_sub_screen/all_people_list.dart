import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:players_clique/src/components/my_text_field.dart';
import 'package:provider/provider.dart';

import '../../../components/add_friends/search_accept.dart';


import '../../../components/add_friends/seatch_add.dart';
import '../../../components/add_friends/textfield.dart';
import '../../../services/auth/auth_service.dart';
import '../chat/chat_page.dart';

class AllPeopleList extends StatefulWidget {
  @override
  _AllPeopleList createState() => _AllPeopleList();
}

class _AllPeopleList extends State<AllPeopleList> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final searchFriends = TextEditingController();
  List<DocumentSnapshot> filteredUsers = [
  ]; // State variable for filtered users
  List<DocumentSnapshot> filteredUsersReUid = [
  ]; // State variable for filtered users

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

    return SafeArea(

        child: Scaffold(
          appBar: CupertinoNavigationBar(
            middle: Text('Люди'),
          ),
          body: Column(
            children: [
              Stack(
                children: [
                  FriendsTextField(
                    controller: searchFriends,
                    obscureText: false,
                    hintText: 'Напишите имя игрока',
                  ),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      onPressed: () {
                        // Call the function to filter users based on the search query
                        _filterUsersFio();
                      },
                      icon: Icon(Icons.search),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: _buildUserList(),
              ),

            ],
          ),
        ));
  }

  void _filterUsersUid() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    String? uid = authService.getCurrentUserUid();
    if (uid != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        List<dynamic> requestRefs = userDoc.get('request');
        List<DocumentSnapshot> requestUsers = [];

        // Assuming requestRefs is a list of user IDs (strings)
        for (var userId in requestRefs) {
          if (userId is String) {
            DocumentSnapshot docSnapshot = await FirebaseFirestore.instance.collection('users').doc(userId).get();
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



  void _filterUsersFio() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    String? uid = authService.getCurrentUserUid();
    if (uid != null) {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('users').get();
      List<DocumentSnapshot> users = querySnapshot.docs;
      String searchQuery = searchFriends.text.toLowerCase();
      filteredUsers = users.where((user) => user['fio'].toString().toLowerCase().contains(searchQuery)).toList();
      if (mounted) { // Check if the widget is still in the tree
        setState(() {});
      }
    }
  }



  Widget _buildUserList() {
    // Use the filteredUsers list instead of the stream
    return ListView(
      children: filteredUsers.map<Widget>((user) => _buildUserListItem(user))
          .toList(),
    );
  }

  Widget _buildUserListItem(DocumentSnapshot document) {
    Map<String, dynamic> data = document.data()! as Map<String, dynamic>;

    if (_auth.currentUser!.email != data['email']) {
      return ListTile(
        title: MessageProfileAdd(
          iconProfile: Image.network(data['photourl']),
          onTap: () {},
          text: data['fio'],
          uid: data['uid'],

        ),
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ChatPage(
                      receiveruserEmail: data['email'],
                      receiverUserID: data['uid'],
                    ),
              ));
        },
      );
    } else {
      return Container();
    }
  }
}


