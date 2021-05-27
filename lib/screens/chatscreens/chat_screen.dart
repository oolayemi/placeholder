import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:placeholder/constants/strings.dart';
import 'package:placeholder/enum/view_state.dart';
import 'package:placeholder/models/firebase_user.dart';
import 'package:placeholder/models/message.dart';
import 'package:placeholder/provider/image_upload_provider.dart';
import 'package:placeholder/resources/firebase_repository.dart';
import 'package:placeholder/screens/chatscreens/widgets/cached_image.dart';
import 'package:placeholder/screens/chatscreens/widgets/contact_page.dart';
import 'package:placeholder/utils/unversal_variables.dart';
import 'package:placeholder/utils/utilities.dart';
import 'package:placeholder/widgets/appbar.dart';
import 'package:placeholder/widgets/custom_tile.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  final FirebaseUser receiver;

  ChatScreen({
    this.receiver,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  TextEditingController textFieldController = TextEditingController();
  FirebaseRepository _repository = FirebaseRepository();

  Iterable<Contact> _contacts;
  PermissionStatus permissionStatus;

  FocusNode textFieldFocus = FocusNode();

  ImageUploadProvider _imageUploadProvider;

  FirebaseUser sender;

  String _currentUserId;

  bool isWriting = false;

  bool showEmojiPicker = false;

  @override
  void initState() {
    super.initState();

    _repository.getCurrentUser().then((user) {
      _currentUserId = user.uid;

      setState(() {
        sender = FirebaseUser(
          uid: user.uid,
          name: user.displayName,
          profilePhoto: user.photoURL,
        );
      });
    });
  }

  showKeyboard() => textFieldFocus.requestFocus();

  hideKeyboard() => textFieldFocus.unfocus();

  hideEmojiContainer() {
    setState(() {
      showEmojiPicker = false;
    });
  }

  showEmojiContainer() {
    setState(() {
      showEmojiPicker = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    _imageUploadProvider = Provider.of<ImageUploadProvider>(context);

    return Scaffold(
      backgroundColor: UniversalVariables.blackColor,
      appBar: customAppBar(context),
      body: Column(
        children: <Widget>[
          Flexible(
            child: messageList(),
          ),
          _imageUploadProvider.getViewState == ViewState.LOADING
              ? Container(
                  margin: EdgeInsets.only(right: 15),
                  alignment: Alignment.centerRight,
                  child: CircularProgressIndicator(),
                )
              : Container(),
          chatControls(),
          showEmojiPicker
              ? Flexible(
                  child: Container(
                    child: emojiContainer(),
                  ),
                )
              : Container()
        ],
      ),
    );
  }

  emojiContainer() {
    return EmojiPicker(
      config: Config(
        bgColor: UniversalVariables.separatorColor,
        indicatorColor: UniversalVariables.blueColor,
        emojiSizeMax: 24.3,
        showRecentsTab: true,
        columns: 7,
      ),
      onEmojiSelected: (category, emoji) {
        setState(() {
          isWriting = true;
        });

        textFieldController.text = textFieldController.text + emoji.emoji;
      },
    );
  }

  Widget messageList() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection(MESSAGES_COLLECTION)
          .doc(_currentUserId)
          .collection(widget.receiver.uid)
          .orderBy(TIMESTAMP_FIELD, descending: true)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.data == null) {
          return Center(
            child: CircularProgressIndicator(),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(10),
          reverse: true,
          itemCount: snapshot.data.docs.length,
          itemBuilder: (context, index) {
            return chatMessageItem(snapshot.data.docs[index]);
          },
        );
      },
    );
  }

  Widget chatMessageItem(DocumentSnapshot snapshot) {
    Message _message = Message.fromMap(snapshot.data());

    viewImageModal(context, imageUrl, senderId) async {
      String userIdentity = "Loading...";

      if (FirebaseAuth.instance.currentUser.uid == senderId) {
        setState(() {
          userIdentity = "You";
        });
      } else {
        setState(() {
          userIdentity = widget.receiver.name;
        });
      }
      showModalBottomSheet(
        context: context,
        elevation: 0,
        isScrollControlled: true,
        builder: (context) {
          return Container(
            margin: EdgeInsets.only(top: 28),
            child: Scaffold(
              appBar: AppBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                title: Text(userIdentity),
                actions: [
                  IconButton(
                    onPressed: () {},
                    tooltip: "More",
                    icon: Icon(
                      Icons.more_vert,
                    ),
                  )
                ],
              ),
              body: Center(
                child: AnimatedContainer(
                  margin: EdgeInsets.only(bottom: 20),
                  duration: Duration(seconds: 3),
                  curve: Curves.fastOutSlowIn,
                  decoration: BoxDecoration(
                    color: UniversalVariables.blackColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 3),
      child: GestureDetector(
        onTap: _message.type == MESSAGE_TYPE_IMAGE
            ? () {
                viewImageModal(
                  context,
                  _message.photoUrl,
                  _message.senderId,
                );
              }
            : null,
        child: Container(
          alignment: _message.senderId == _currentUserId
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: _message.senderId == _currentUserId
              ? senderLayout(_message)
              : receiverLayout(_message),
        ),
      ),
    );
  }

  Widget senderLayout(Message message) {
    Radius messageRadius = Radius.circular(10);

    return Container(
      margin: EdgeInsets.only(top: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      decoration: BoxDecoration(
        color: UniversalVariables.senderColor,
        borderRadius: BorderRadius.only(
          topLeft: messageRadius,
          topRight: messageRadius,
          bottomLeft: messageRadius,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(10),
        child: getMessage(message),
      ),
    );
  }

  getMessage(Message message) {
    if (message.type == MESSAGE_TYPE_IMAGE) {
      return message != null
          ? CachedImage(url: message.photoUrl)
          : Text("Url not found");
    } else if (message.type == MESSAGE_TYPE_CONTACT) {
      Contact receivedContact = Contact.fromMap(message.contact);
      //print(receivedContact.toMap());
      return GestureDetector(
        onTap: () => print(message.toContactMap()),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.5,
          padding: EdgeInsets.only(
            top: 6,
          ),
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.blue,
                  child: Text(
                    Utils.getInitials(message.contact['displayName']),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                    ),
                  ),
                ),
                SizedBox(
                  height: 4,
                ),
                Text(
                  message.contact['displayName'].toString(),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(
                  height: 6,
                ),
                Divider(
                  thickness: 1,
                  color: Colors.grey,
                ),
                TextButton(
                  onPressed: () async {
                    // try {
                    //   print(receivedContact.toMap());
                    //   await ContactsService.addContact(receivedContact)
                    //       .then((value) => print(value));
                    // } on FormOperationException catch (e) {
                    //   switch (e.errorCode) {
                    //     case FormOperationErrorCode.FORM_COULD_NOT_BE_OPEN:
                    //     case FormOperationErrorCode.FORM_OPERATION_CANCELED:
                    //     case FormOperationErrorCode
                    //         .FORM_OPERATION_UNKNOWN_ERROR:
                    //       print(e.toString());
                    //   }
                    // }
                  },
                  child: Text(
                    'Add Contact',
                  ),
                )
              ],
            ),
          ),
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //   children: [
          //     Container(
          //       child: Row(
          //         children: [
          //           CircleAvatar(
          //             backgroundColor: Colors.blue,
          //             child: Text(
          //               Utils.getInitials(message.contact['displayName']),
          //               style: TextStyle(
          //                 color: Colors.white,
          //                 fontSize: 17,
          //               ),
          //             ),
          //           ),
          //           SizedBox(
          //             width: 8,
          //           ),
          //           Text(
          //             message.contact['displayName'].toString(),
          //             style: TextStyle(
          //               fontSize: 17,
          //               fontWeight: FontWeight.bold,
          //             ),
          //           ),
          //         ],
          //       ),
          //     ),
          //     Icon(Icons.contact_page)
          //   ],
          // ),
        ),
      );
    } else {
      return Text(
        message.message,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16.0,
        ),
      );
    }
  }

  Widget receiverLayout(Message message) {
    Radius messageRadius = Radius.circular(10);

    return Container(
      margin: EdgeInsets.only(top: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      decoration: BoxDecoration(
        color: UniversalVariables.receiverColor,
        borderRadius: BorderRadius.only(
          bottomRight: messageRadius,
          topRight: messageRadius,
          bottomLeft: messageRadius,
        ),
      ),
      child: Padding(padding: EdgeInsets.all(10), child: getMessage(message)),
    );
  }

  Widget chatControls() {
    setWritingTo(bool val) {
      setState(() {
        isWriting = val;
      });
    }

    addMediaModal(context) {
      Contact contact;
      showModalBottomSheet(
          context: context,
          elevation: 0,
          backgroundColor: UniversalVariables.blackColor,
          builder: (context) {
            return Column(
              children: <Widget>[
                Container(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Row(
                    children: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.maybePop(context),
                        child: Icon(
                          Icons.close,
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(
                            "Content and tools",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    children: <Widget>[
                      ModalTile(
                        title: "Media",
                        subtitle: "Share photos and videos",
                        icon: Icons.image,
                        onTap: () {
                          pickImage(source: ImageSource.gallery);
                          Navigator.pop(context);
                        },
                      ),
                      ModalTile(
                        title: "File",
                        subtitle: "Share files",
                        icon: Icons.tab,
                      ),
                      ModalTile(
                        title: "Contacts",
                        subtitle: "Share contacts",
                        icon: Icons.contacts,
                        onTap: () async {
                          Navigator.pop(context);
                          contact = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ContactsPage(
                                contact: contact,
                              ),
                            ),
                          );

                          if (contact != null) {
                            Contact newContact;
                            newContact = Contact(
                              displayName: contact.displayName,
                              phones: contact.phones,
                            );

                            print(contact.displayName);
                            sendReceivedContact(
                              contact: newContact.toMap(),
                              senderId: sender.uid,
                              receiverId: widget.receiver.uid,
                            );
                          }
                        },
                      ),
                      // ModalTile(
                      //   title: "Location",
                      //   subtitle: "Share a location",
                      //   icon: Icons.add_location,
                      // ),
                      ModalTile(
                        title: "Schedule Call",
                        subtitle: "Share a placeholder",
                        icon: Icons.schedule,
                      ),
                      // ModalTile(
                      //   title: "Create Poll",
                      //   subtitle: "Share polls",
                      //   icon: Icons.poll,
                      // ),
                    ],
                  ),
                )
              ],
            );
          });
    }

    return Container(
      padding: EdgeInsets.all(10),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () => addMediaModal(context),
            child: Container(
              padding: EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: UniversalVariables.fabGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add),
            ),
          ),
          SizedBox(
            width: 5,
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                TextField(
                  controller: textFieldController,
                  focusNode: textFieldFocus,
                  onTap: () => hideEmojiContainer(),
                  style: TextStyle(color: Colors.white),
                  onChanged: (val) {
                    (val.length > 0 && val.trim() != "")
                        ? setWritingTo(true)
                        : setWritingTo(false);
                  },
                  maxLines: 4,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: "Type a message",
                    hintStyle: TextStyle(color: UniversalVariables.greyColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16.0)),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.fromLTRB(10, 5, 37, 5),
                    fillColor: UniversalVariables.separatorColor,
                    filled: true,
                  ),
                ),
                SizedBox(
                  width: 15,
                ),
                IconButton(
                  highlightColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  onPressed: () {
                    if (!showEmojiPicker) {
                      hideKeyboard();
                      showEmojiContainer();
                    } else {
                      showKeyboard();
                      hideEmojiContainer();
                    }
                  },
                  icon: Icon(Icons.face),
                ),
              ],
            ),
          ),
          isWriting
              ? Container()
              : Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.record_voice_over),
                ),
          isWriting
              ? Container()
              : GestureDetector(
                  onTap: () => pickImage(source: ImageSource.camera),
                  child: Icon(Icons.camera_alt)),
          isWriting
              ? Container(
                  margin: EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                      gradient: UniversalVariables.fabGradient,
                      shape: BoxShape.circle),
                  child: IconButton(
                    icon: Icon(
                      Icons.send,
                      size: 15,
                    ),
                    onPressed: () => sendMessage(),
                  ),
                )
              : Container()
        ],
      ),
    );
  }

  sendMessage() {
    var text = textFieldController.text;

    Message _message = Message(
      receiverId: widget.receiver.uid,
      senderId: sender.uid,
      message: text,
      timestamp: Timestamp.now(),
      type: 'text',
    );

    setState(() {
      isWriting = false;
    });

    textFieldController.text = "";

    _repository.addMessageToDb(_message, sender, widget.receiver);
  }

  pickImage({@required ImageSource source}) async {
    File selectedImage = await Utils.pickImage(source: source);
    _repository.uploadImage(
      image: selectedImage,
      receiverId: widget.receiver.uid,
      senderId: _currentUserId,
      imageUploadProvider: _imageUploadProvider,
    );
  }

  CustomAppBar customAppBar(context) {
    return CustomAppBar(
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
        ),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      centerTitle: false,
      title: Text(
        widget.receiver.name,
        style: TextStyle(fontSize: 19),
      ),
      actions: <Widget>[
        IconButton(
          icon: Icon(
            Icons.video_call,
          ),
          onPressed: () {},
        ),
        // IconButton(
        //   icon: Icon(
        //     Icons.phone,
        //   ),
        //   onPressed: () {},
        // )
      ],
    );
  }

  void sendReceivedContact({
    Map<dynamic, dynamic> contact,
    String receiverId,
    String senderId,
  }) {
    _repository.sendContact(contact, senderId, receiverId);
  }
}

class ModalTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Function onTap;

  const ModalTile({
    @required this.title,
    @required this.subtitle,
    @required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 15),
      child: CustomTile(
        mini: false,
        onTap: onTap,
        leading: Container(
          margin: EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: UniversalVariables.receiverColor,
          ),
          padding: EdgeInsets.all(10),
          child: Icon(
            icon,
            color: UniversalVariables.greyColor,
            size: 38,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: UniversalVariables.greyColor,
            fontSize: 14,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}