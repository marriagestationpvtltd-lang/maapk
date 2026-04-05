import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'chatprovider.dart';
import 'chatscreen.dart';

class Loading extends StatefulWidget {
  @override
  State<Loading> createState() => _LoadingState();
}

class _LoadingState extends State<Loading> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() =>
        Provider.of<ChatProvider>(context, listen: false).fetchChatList());
  }

  @override
  Widget build(BuildContext context) {
    return ChatScreen();
  }
}