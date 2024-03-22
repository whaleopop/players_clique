import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../icons/player_icon_icons.dart';
import '../../models/post.dart';
import '../../services/auth/auth_service.dart';

class LentaPost extends StatelessWidget {
  final void Function()? onTap;
  final String imageUrl;
  final String namePost;
  final String descPost;
  final String userId;

  const LentaPost({
    Key? key,
    required this.imageUrl,
    required this.onTap,
    required this.namePost,
    required this.descPost,
    required this.userId,
  }) : super(key: key);

  Future<String?> loadUserField(BuildContext context, String fieldName) async {
    final authService = Provider.of<AuthService>(context, listen: false);

    if (userId != null) {
      return await authService.getUserField(userId, fieldName);
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  ClipOval(
                    child: FutureBuilder(
                      future: loadUserField(context, "photourl"),
                      builder: (BuildContext context,
                          AsyncSnapshot<String?> snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return Icon(Icons.error);
                        } else if (snapshot.hasData) {
                          return Image.network(
                            snapshot.data!,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                          );
                        } else {
                          return SizedBox(
                            width: 32,
                            height: 32,
                            child: Placeholder(),
                          );
                        }
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: FutureBuilder(
                      future: loadUserField(context, "fio"),
                      builder: (BuildContext context,
                          AsyncSnapshot<String?> snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return Text("${snapshot.error}");
                        } else if (snapshot.hasData) {
                          return Text(
                            snapshot.data!,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          );
                        } else {
                          return Text("No data");
                        }
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.more_vert),
                  ),
                ],
              ),
            ),
            Image.network(
              imageUrl,
              width: double.infinity,
              height: 300,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: Icon(PlayerIcon.favorite,color: Colors.lightBlue,),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: Icon(PlayerIcon.chat_fill,color: Colors.lightBlue,),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    namePost,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    descPost,
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
