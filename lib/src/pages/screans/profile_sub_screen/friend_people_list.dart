import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:players_clique/src/components/add_friends/search_people.dart';
import 'package:players_clique/src/pages/screans/profile_sub_screen/profile_player.dart';

import 'package:provider/provider.dart';

import '../../../components/add_friends/search_accept.dart';

import '../../../components/add_friends/textfield.dart';
import '../../../services/auth/auth_service.dart';
import '../chat/chat_page.dart';

class FriendPeople extends StatefulWidget {
  @override
  _FriendPeople createState() => _FriendPeople();
}

class _FriendPeople extends State<FriendPeople> {
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
            middle: Text('Друзья'),
          ),
          body: Column(
            children: [
              Expanded(
                child: _buildReUserList(),
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
        List<dynamic> requestRefs = userDoc.get('players');
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



  Widget _buildReUserList() {
    // Use the filteredUsers list instead of the stream
    return ListView(
      children: filteredUsersReUid.map<Widget>((user) => _buildRequestListItem(user))
          .toList(),
    );
  }


  Widget _buildRequestListItem(DocumentSnapshot document) {
    Map<String, dynamic> data = document.data()! as Map<String, dynamic>;

    if (_auth.currentUser!.email != data['email']) {
      return ListTile(
        title: ProfilePlayerPreview(
          iconProfile: Image.network(data['photourl']),
          onTap: () {
            Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) =>
                      Profile_Player(
                        uid: data['uid'],
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


