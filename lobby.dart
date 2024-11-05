mport 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tic_tactics/profile.dart';
import 'vs_ai_screen.dart'; 
import 'localdevice.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'online.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LobbyScreen extends StatefulWidget {
  @override
  _LobbyScreenState createState() => _LobbyScreenState();
}
class FriendRequestState {
  bool isRequestSent;

  FriendRequestState({required this.isRequestSent});
}
class _LobbyScreenState extends State<LobbyScreen> {
  final _firebase = FirebaseAuth.instance;
  String? _username;
  String? _imageUrl;
  int? _score;
  bool _isLoading = false;
  Timer? _pollingTimer;
  Timer? countdownTimer;
   bool _hasFriendRequests = false;
  Map<String, String> requestStatuses = {}; // Track friend request status per user
  Map<String, bool> friendStatuses = {}; // Track friendship status per user
  void setupPushNotifications() async {
    final fcm = FirebaseMessaging.instance;

    await fcm.requestPermission();

    fcm.subscribeToTopic('users');
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _listenForFriendRequests();
    setupPushNotifications();
  }
  void _listenForFriendRequests() {
  final user = _firebase.currentUser;
  if (user == null) return;

  // Stream to listen for any changes in the 'friend_requests' collection
  FirebaseFirestore.instance
      .collection('friend_requests')
      .where('to_user_id', isEqualTo: user.uid)
      .snapshots()
      .listen((snapshot) {
    setState(() {
      _hasFriendRequests = snapshot.docs.isNotEmpty;
    });
  });
}
  @override
  void dispose() {
    // Cancel any timers that may still be active to prevent setState() being called after dispose
    countdownTimer?.cancel(); 
    _pollingTimer?.cancel(); // Ensure that polling timers are also canceled
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    final user = _firebase.currentUser;
    if (user == null) return;

    final userData = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    setState(() {
      _username = userData['username'];
      _imageUrl = userData['image_url'];
      _score = userData['score'];
      _isLoading = false;
    });
  }
  void _showFriendRequestDialog() {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Friends and Requests'),
      content: Container(
        width: double.maxFinite,
        height: 400, 
        child: DefaultTabController(
          length: 3, 
          child: Column(
            children: [
              TabBar(
                labelColor: Theme.of(context).colorScheme.primary,
                tabs: [
                  Tab(text: 'Friends'),
                  Tab(text: 'Search'),
                  Tab(text: 'Requests'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildFriendsList(),
                    _buildUserSearch(),
                    _buildFriendRequests(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.of(ctx).pop();
          },
          child: Text('Close'),
        ),
      ],
    ),
  );
}

// Section 1: Build Friends List
Widget _buildFriendsList() {
  return FutureBuilder<Map<String, dynamic>>(
    future: _getFriends(), // Fetch friends from Firestore
    builder: (ctx, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasData) {
        var data = snapshot.data ?? {};
        var friends = data['friends'] as List<Map<String, dynamic>>;
        var friendCount = data['count'] as int;

        // Display friend count and list
        return Column(
          children: [
            // Friend count indicator
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'You have ($friendCount) friend${friendCount != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Expanded(
              child: ListView.builder(
                itemCount: friends.length,
                itemBuilder: (ctx, index) {
                  final friend = friends[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: NetworkImage(friend['image_url']),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    friend['username'],
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${friend['score']}',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              friend['status'] == 'online' ? 'Online' : 'Offline',
                              style: TextStyle(
                                color: friend['status'] == 'online' ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  await _removeFriend(friend['userId']);
                                  setState(() {}); // Refresh the UI
                                },
                                child: Text(
                                  'Remove Friend',
                                  style: TextStyle(fontSize: 14, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }
      return Center(child: Text('No friends.'));
    },
  );
}

// Section 2: Build User Search
Widget _buildUserSearch() {
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  String currentUserId = '';

  return StatefulBuilder(
    builder: (context, setState) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && currentUserId != user.uid) {
        setState(() {
          currentUserId = user.uid;
        });
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search input field
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users by username',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () async {
                    if (_searchController.text.length >= 4) {
                      final results = await _searchUsers(_searchController.text);
                      // Check the request and friend statuses for all results
                      for (var user in results) {
                        requestStatuses[user['userId']] = await _checkFriendRequestStatus(user['userId']);
                        friendStatuses[user['userId']] = await _checkFriendStatus(user['userId']);
                      }
                      setState(() {
                        searchResults = results;
                      });
                    }
                  },
                ),
              ),
              onChanged: (value) async {
                if (value.length >= 4) {
                  final results = await _searchUsers(value);
                  // Check the request and friend statuses for all results
                  for (var user in results) {
                    requestStatuses[user['userId']] = await _checkFriendRequestStatus(user['userId']);
                    friendStatuses[user['userId']] = await _checkFriendStatus(user['userId']);
                  }
                  setState(() {
                    searchResults = results;
                  });
                } else {
                  setState(() {
                    searchResults = [];
                  });
                }
              },
            ),
          ),
          // Display search results
          Expanded(
            child: ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (ctx, index) {
                final user = searchResults[index];
                final isCurrentUser = user['userId'] == currentUserId;

                String requestStatus = requestStatuses[user['userId']] ?? 'none';
                bool isFriend = friendStatuses[user['userId']] ?? false;

                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(user['image_url']),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['username'],
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${user['score']}',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: isCurrentUser
                      ? null 
                      : isFriend
                          ? Text('Friend', style: TextStyle(color: Colors.blue))  
                          : requestStatus == 'sent'
                              ? Text('Sent', style: TextStyle(color: Colors.green))
                              : requestStatus == 'received'
                                  ? Text('Received', style: TextStyle(color: const Color.fromARGB(255, 89, 88, 87)))
                                  : Container(
                                      width: 80,
                                      height: 30,
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          await _sendFriendRequest(user['userId']);
                                          setState(() {
                                            requestStatuses[user['userId']] = 'sent';
                                          });
                                        },
                                        child: Text(
                                          'Add',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          padding: EdgeInsets.symmetric(vertical: 5),
                                        ),
                                      ),
                                    ),
                );
              },
            ),
          ),
        ],
      );
    },
  );
}
// Section 3: Build Friend Requests Received
Widget _buildFriendRequests() {
  return FutureBuilder(
    future: _getFriendRequests(), // Fetch friend requests from Firestore
    builder: (ctx, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasData) {
        var requests = snapshot.data as List<Map<String, dynamic>>;
        
        // If there are no requests, display "No friend requests."
        if (requests.isEmpty) {
          return Center(child: Text('No friend requests.'));
        }

        // Display the list of friend requests if available
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (ctx, index) {
            final request = requests[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Display friend request info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(request['image_url']), // Friend's profile image
                      ),
                      SizedBox(width: 16), // Spacing between image and text
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request['username'], // Friend's username
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${request['score']}', // Friend's score
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8), // Spacing between rows

                  // Row 2: Accept/Ignore buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await _acceptFriendRequest(request['userId']); // Accept logic
                          },
                          child: Text(
                            'Accept', 
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await _ignoreFriendRequest(request['userId']); // Ignore logic
                          },
                          child: Text(
                            'Ignore', 
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      }
      // Show error message if snapshot has no data
      return Center(child: Text('No friend requests.'));
    },
  );
}

// Firestore function to send a friend request
Future<void> _sendFriendRequest(String toUserId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.uid == toUserId) return; 

  final fromUserId = user.uid;

  // Add the friend request in Firestore
  await FirebaseFirestore.instance.collection('friend_requests').doc('$fromUserId-$toUserId').set({
    'from_user_id': fromUserId,
    'to_user_id': toUserId,
    'status': 'sent', 
    'created_at': FieldValue.serverTimestamp(),
  });
}

// Function to check if a friend request is already sent
Future<String> _checkFriendRequestStatus(String toUserId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return 'none';

  final fromUserId = user.uid;

  
  final sentRequest = await FirebaseFirestore.instance
      .collection('friend_requests')
      .doc('$fromUserId-$toUserId')
      .get();

  if (sentRequest.exists && sentRequest.data()?['status'] == 'sent') {
    return 'sent';
  }

  
  final receivedRequest = await FirebaseFirestore.instance
      .collection('friend_requests')
      .doc('$toUserId-$fromUserId')
      .get();

  if (receivedRequest.exists && receivedRequest.data()?['status'] == 'sent') {
    return 'received';
  }

  return 'none';
}


// Function to check if the user is already friends with the target user
Future<bool> _checkFriendStatus(String toUserId) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final fromUserId = user.uid;

    
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(fromUserId).get();

    if (userDoc.exists) {
      List<dynamic> friends = userDoc.data()?['friends'] ?? [];

      
      if (friends.contains(toUserId)) {
        return true;  
      }
    }

    return false; 
  } catch (e) {
    print('Error checking friend status: $e');
    return false; 
  }
}


// Search Users
Future<List<Map<String, dynamic>>> _searchUsers(String query) async {
  if (query.length < 4) {
    // Do not perform a search if less than 4 characters are entered
    return [];
  }

  
  final searchResults = await FirebaseFirestore.instance
      .collection('users')
      .where('username', isGreaterThanOrEqualTo: query)
      .where('username', isLessThanOrEqualTo: query + '\uf8ff') 
      .get();

  List<Map<String, dynamic>> usersList = [];

  for (var doc in searchResults.docs) {
    final userData = doc.data();
    usersList.add({
      'userId': doc.id,
      'username': userData['username'],
      'image_url': userData['image_url'],
      'score': userData['score'],
    });
  }

  return usersList;
}
Future<Map<String, dynamic>> _getFriends() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return {'count': 0, 'friends': []};

  final userId = user.uid;

  // Fetch the user's document
  final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
  if (!userDoc.exists || !userDoc.data()!.containsKey('friends')) return {'count': 0, 'friends': []};

  List<String> friendIds = List<String>.from(userDoc.data()!['friends']);
  List<Map<String, dynamic>> friendsList = [];

  for (String friendId in friendIds) {
    final friendDoc = await FirebaseFirestore.instance.collection('users').doc(friendId).get();
    if (friendDoc.exists) {
      final friendData = friendDoc.data()! as Map<String, dynamic>; // Explicitly cast to Map<String, dynamic>
      friendsList.add({
        'userId': friendId,
        'username': friendData['username'],
        'image_url': friendData['image_url'],
        'score': friendData['score'],
        'status': friendData['status'] ?? 'offline', // friend’s status
      });
    }
  }

  return {'count': friendsList.length, 'friends': friendsList};
}

//  Get Friend Requests
Future<List<Map<String, dynamic>>> _getFriendRequests() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return [];

  final userId = user.uid;

  final friendRequests = await FirebaseFirestore.instance
      .collection('friend_requests')
      .where('to_user_id', isEqualTo: userId)
      .get();

  List<Map<String, dynamic>> requestsList = [];

  for (var request in friendRequests.docs) {
    final fromUserId = request['from_user_id'];
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(fromUserId).get();
    if (userDoc.exists) {
      final userData = userDoc.data()!;
      requestsList.add({
        'userId': fromUserId,
        'username': userData['username'],
        'image_url': userData['image_url'],
        'score': userData['score'],
      });
    }
  }

  return requestsList;
}
Future<void> _removeFriend(String friendId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final userId = user.uid;

  // Remove friend from the current user's "friends" array
  await FirebaseFirestore.instance.collection('users').doc(userId).update({
    'friends': FieldValue.arrayRemove([friendId]),
  });

  // Remove the current user from the friend's "friends" array
  await FirebaseFirestore.instance.collection('users').doc(friendId).update({
    'friends': FieldValue.arrayRemove([userId]),
  });

  print('Friend removed successfully');
}



//  Accept Friend Request
Future<void> _acceptFriendRequest(String fromUserId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final userId = user.uid;

  // Add each other to the friends list
  await FirebaseFirestore.instance.collection('users').doc(userId).update({
    'friends': FieldValue.arrayUnion([fromUserId]),  // Add friend to current user's friends array
  });

  await FirebaseFirestore.instance.collection('users').doc(fromUserId).update({
    'friends': FieldValue.arrayUnion([userId]),  // Add current user to friend's friends array
  });

  // Delete the friend request after accepting
  await _deleteFriendRequest(fromUserId, userId);

  
  final userData = await FirebaseFirestore.instance.collection('users').doc(userId).get();
  final updatedFriendsList = List<String>.from(userData['friends'] ?? []);

  
  setState(() {
    friendStatuses[fromUserId] = updatedFriendsList.contains(fromUserId); 
  });
}

//  Ignore Friend Request
Future<void> _ignoreFriendRequest(String fromUserId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final userId = user.uid;

  // Delete the friend request after ignoring it
  await _deleteFriendRequest(fromUserId, userId);

  setState(() {}); 
}

// Function to delete friend request from Firestore
Future<void> _deleteFriendRequest(String fromUserId, String toUserId) async {
  final requestQuery = await FirebaseFirestore.instance
      .collection('friend_requests')
      .where('from_user_id', isEqualTo: fromUserId)
      .where('to_user_id', isEqualTo: toUserId)
      .get();

  // Delete the friend request document
  for (var request in requestQuery.docs) {
    await request.reference.delete();
  }
}
  // Navigate to game mode screens based on selection
  void _navigateToGameMode(String mode) {
    if (mode == 'Online') {
       _showOnlineMatchConfirmation(); 
    } else if (mode == 'VS AI') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (ctx) => VsAiScreen(), 
      ));
    } else if (mode == 'Local Device') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (ctx) => LocalDeviceGameScreen(),
      ));
    }else if (mode == 'Leaderboard') {
      _showLeaderboardDialog(context);
    }
  }
   void _showOnlineMatchConfirmation() {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Center(child: Text('Online Match')),
      content: Text('Do you want to search for an opponent?'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop(); 
          },
          child: Text('Cancel', style: TextStyle(color: Colors.red),)
        ),
        ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); 
                _showSearchingDialog(); 
              },
              child: Text('Confirm', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
      ],
    ),
  );
}
void _showSearchingDialog() {
  int remainingTime = 120; 
  bool isSearching = true;
   Timer? countdownTimer;
  

  // Start the countdown timer and Firestore polling
  showDialog(
    context: context,
    barrierDismissible: false, // Prevents dismissing by tapping outside
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        
        countdownTimer ??= Timer.periodic(Duration(seconds: 1), (timer) {
          if (remainingTime > 0) {
            if (mounted) {
              
              setState(() {
                remainingTime--;
                print("UI Timer: Time remaining: $remainingTime seconds");
              });
            }
          } else {
            
            countdownTimer?.cancel();
            if (isSearching) {
              _endMatchSearch(false); 
              if (Navigator.canPop(context)) {
                    Navigator.of(context).pop(); 
                  }
            }
          }
        });

        return AlertDialog(
          title: Text('Searching for a match...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'Time remaining: ${(remainingTime ~/ 60).toString().padLeft(2, '0')}:${(remainingTime % 60).toString().padLeft(2, '0')}',
                style: TextStyle(
    color: remainingTime < 30 ? Colors.red : Colors.black, // Change color if less than 30 seconds
  ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  countdownTimer?.cancel(); 
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop(); 
                  }
                  _cancelMatchmaking(); 
                },
                child: Text('Cancel'),
              ),
            ],
          ),
        );
      },
    ),
  ).then((_) {
    
    countdownTimer?.cancel();
  });
  _startOnlineMatchmaking(); 
}


// Start the online matchmaking process
Future<void> _startOnlineMatchmaking() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print("User not logged in.");
    return;
  }

  final playerId = user.uid;
  final matchCollection = FirebaseFirestore.instance.collection('matches');

  bool matchFound = false; // Track if a match is found

  try {
    // Step 1: Check if there is any match available where player2 is still null and player1 is not the current user
    final matchQuery = await matchCollection
        .where('player2', isNull: true)
        .where('player1', isNotEqualTo: playerId)
        .limit(1)
        .get();

    if (matchQuery.docs.isNotEmpty) {
      // Step 2: Join an existing match
      final matchId = matchQuery.docs.first.id;
      await matchCollection.doc(matchId).update({
        'player2': playerId,
        'status': 'matched',
        'board': List.filled(9, ''), // Initialize empty board
        'turn': 'X', // Player 1 starts
      });
      matchFound = true;
      print("Match found and joined: $matchId");

      // Now listen for status change to 'matched' for Player 2
      _listenForMatchStatus(matchId, countdownTimer);
    } else {
      // Step 3: Create a new match since no available match was found
      final newMatch = await matchCollection.add({
        'player1': playerId,
        'player2': null,
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
      });
      print("New match created for player: $playerId with ID: ${newMatch.id}");

      // Now listen for status change to 'matched' for Player 1
      _listenForMatchStatus(newMatch.id, countdownTimer);
    }
  } catch (e) {
    print("Error in matchmaking process: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error in matchmaking process: $e")),
    );
  }
}

// Function to listen for match status changes
void _listenForMatchStatus(String matchId, Timer? countdownTimer) {
  final matchCollection = FirebaseFirestore.instance.collection('matches');

  matchCollection.doc(matchId).snapshots().listen((snapshot) {
    if (snapshot.exists) {
      final matchData = snapshot.data();

      // Check if the match status is 'matched'
      if (matchData != null && matchData['status'] == 'matched') {
        print("Match is now matched. Navigating to OnlineGameScreen...");

        // Stop the countdown timer
        countdownTimer?.cancel();

        // Close the searching dialog
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop(); // Close the search dialog
        }

        // Show a notification and navigate to the game screen
        Future.delayed(Duration(milliseconds: 100), () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Match found! Starting game...')),
          );

          // Navigate to the OnlineGameScreen with the correct matchId
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => OnlineGameScreen(matchId: matchId),
            ),
          );
        });
      }
    }
  });
}



// Function to handle ending the search process
void _endMatchSearch(bool matchFound) async {
  
  _pollingTimer?.cancel();

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final playerId = user.uid;
  final matchCollection = FirebaseFirestore.instance.collection('matches');

  
  if (Navigator.canPop(context)) {
    Navigator.maybePop(context); 
  }

  if (matchFound) {
    // When a match is found, we need to fetch the match document to get the matchId
    try {
      final matchQuery = await matchCollection
          .where('player1', isEqualTo: playerId)
          .where('status', isEqualTo: 'matched')
          .limit(1)
          .get();

      if (matchQuery.docs.isNotEmpty) {
        final matchId = matchQuery.docs.first.id;

        // Only show the Snackbar after the dialog has been closed safely
        Future.delayed(Duration(milliseconds: 100), () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Match found! Starting game...')),
          );

          // Navigate to the OnlineGameScreen with the correct matchId
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => OnlineGameScreen(matchId: matchId), 
            ),
          );
        });
      } else {
        // No match document found, handle it as an error
        print("Error: Match document not found.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Match not found.')),
        );
      }
    } catch (e) {
      print("Error fetching match data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching match data.')),
      );
    }
  } else {
    // If no match was found, show a different Snackbar
    Future.delayed(Duration(milliseconds: 100), () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sorry, could not find a game.')),
      );
    });

    
    try {
      final matchQuery = await matchCollection
          .where('player1', isEqualTo: playerId)
          .where('status', isEqualTo: 'waiting')
          .limit(1)
          .get();

      for (var doc in matchQuery.docs) {
        await doc.reference.delete();
        print("Match document deleted: ${doc.id}");
      }
    } catch (e) {
      print("Error deleting match: $e");
    }
  }
}

void _cancelMatchmaking() async {
    
    _pollingTimer?.cancel();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final playerId = user.uid;
    final matchCollection = FirebaseFirestore.instance.collection('matches');

    
    final matchQuery = await matchCollection
        .where('player1', isEqualTo: playerId)
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();

    for (var doc in matchQuery.docs) {
      await doc.reference.delete();
      print("Match document deleted: ${doc.id}");
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Matchmaking canceled.')),
    );
  }
  // Function to show the leaderboard dialog
  void _showLeaderboardDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Center(child: Text('Leaderboard')),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  labelColor: Theme.of(context).colorScheme.primary,
                  tabs: [
                    Tab(text: 'Global'),
                    Tab(text: 'Friends'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildGlobalLeaderboard(),
                      _buildFriendsLeaderboard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  // Widget for global leaderboard list
  Widget _buildGlobalLeaderboard() {
    return FutureBuilder(
      future: _getGlobalLeaderboard(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          var users = snapshot.data as List<Map<String, dynamic>>;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (ctx, index) {
              final user = users[index];
              return _buildLeaderboardTile(user, index, true);
            },
          );
        }
        return Center(child: Text('No data available.'));
      },
    );
  }

  // Widget for friends leaderboard list
  Widget _buildFriendsLeaderboard() {
    return FutureBuilder(
      future: _getFriendsLeaderboard(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          var friends = snapshot.data as List<Map<String, dynamic>>;
          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (ctx, index) {
              final friend = friends[index];
              return _buildLeaderboardTile(friend, index, false);
            },
          );
        }
        return Center(child: Text('No friends in leaderboard.'));
      },
    );
  }

  Widget _buildLeaderboardTile(Map<String, dynamic> user, int index, bool isGlobal) {
  bool isCurrentUser = FirebaseAuth.instance.currentUser?.uid == user['userId'];

  IconData? icon;
  Color iconColor;

  // Determine the icon and color for top 3 ranks
  if (index == 0) {
    icon = FontAwesomeIcons.trophy;
    iconColor = Colors.amber; // Gold for first place
  } else if (index == 1) {
    icon = FontAwesomeIcons.medal;
    iconColor = Colors.grey; // Silver for second place
  } else if (index == 2) {
    icon = FontAwesomeIcons.medal;
    iconColor = Colors.brown; // Bronze for third place
  } else {
    icon = null;
    iconColor = Colors.transparent; // No icon for ranks beyond third
  }

  return Container(
    color: isCurrentUser ? Colors.blue.withOpacity(0.2) : Colors.transparent,
    child: ListTile(
      leading: CircleAvatar(
        backgroundImage: NetworkImage(user['image_url']),
      ),
      title: Text(
        user['username'],
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        'Score: ${user['score']}',
        style: TextStyle(color: const Color.fromARGB(255, 62, 60, 60)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min, // Ensure the Row takes minimum space
        mainAxisAlignment: MainAxisAlignment.end, // Push elements to the far right
        crossAxisAlignment: CrossAxisAlignment.center, // Vertically align both elements
        children: [
          if (icon != null)
            Icon(
              icon,
              color: iconColor,
              size: 25,
            ),
          if (index >= 3) ...[
            SizedBox(width: 10), // Add spacing between the icon and rank number
            Text(
              '${index + 1}', // Rank number for ranks 4 and below
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey,
                fontSize: 25,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

  // Firestore query to retrieve global leaderboard
  Future<List<Map<String, dynamic>>> _getGlobalLeaderboard() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('score', descending: true)
        .limit(100)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'userId': doc.id,
        'username': data['username'],
        'image_url': data['image_url'],
        'score': data['score'],
      };
    }).toList();
  }

  // Firestore query to retrieve friends leaderboard
  Future<List<Map<String, dynamic>>> _getFriendsLeaderboard() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return [];

  final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  if (!userDoc.exists || !userDoc.data()!.containsKey('friends')) return [];

  List<String> friendIds = List<String>.from(userDoc.data()!['friends']);
  if (friendIds.isEmpty) return [];

  // Query to fetch all friends sorted by score
  final friendsSnapshot = await FirebaseFirestore.instance
      .collection('users')
      .where(FieldPath.documentId, whereIn: friendIds)
      .orderBy('score', descending: true)
      .get();

  // Map the friends data and add rank
  final friendsList = friendsSnapshot.docs.map((doc) {
    final data = doc.data();
    return {
      'userId': doc.id,
      'username': data['username'],
      'image_url': data['image_url'],
      'score': data['score'],
    };
  }).toList();

  // Add the current user in the friends list for ranking purposes
  friendsList.add({
    'userId': user.uid,
    'username': userDoc['username'],
    'image_url': userDoc['image_url'],
    'score': userDoc['score'],
  });

  // Sort the list by score after adding the current user
  friendsList.sort((a, b) => b['score'].compareTo(a['score']));

  return friendsList;
}

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Theme.of(context).colorScheme.primary, 
    appBar: AppBar(
  backgroundColor: Theme.of(context).colorScheme.primary,
  title: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      
      if (!_isLoading && _username != null && _imageUrl != null)
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (ctx) => ProfileScreen(),
            ));
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(_imageUrl!),
              ),
              const SizedBox(width: 8),
              Text(
                'Score: $_score',
                style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

      
      const Expanded(
        child:  Center(
          child: Text(
            'Tic Tactics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ],
  ),
  
 
  actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.person_add, color: Colors.white),
                onPressed: () {
                  _showFriendRequestDialog();
                },
              ),
              if (_hasFriendRequests)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                  ),
                ),
            ],
          ),
    IconButton(
      onPressed: () {
        FirebaseAuth.instance.signOut(); 
      },
      icon: Icon(
        Icons.exit_to_app,
        color: Colors.white,
      ),
    ),
  ],
),
    body: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: ListView(
            scrollDirection: Axis.vertical, 
            children: [
              _buildGameModeSquare('Online', const Color.fromARGB(255, 65, 162, 241), const Color.fromARGB(255, 8, 35, 83)),
              _buildGameModeSquare('VS AI', const Color.fromARGB(255, 167, 81, 182), const Color.fromARGB(255, 37, 17, 73)),
              _buildGameModeSquare('Local Device', const Color.fromARGB(255, 99, 173, 101), const Color.fromARGB(255, 2, 67, 61)),
              _buildGameModeSquare('Leaderboard', const Color.fromARGB(255, 241, 104, 94), const Color.fromARGB(255, 86, 3, 3)),
            ],
          ),
        ),
      ],
    ),
  );
}

// Function to build large square buttons with a gradient background
Widget _buildGameModeSquare(String mode, Color startColor, Color endColor) {
  return GestureDetector(
    onTap: () => _navigateToGameMode(mode),
    child: Container(
      margin: const EdgeInsets.all(20),
      width: double.infinity,  // Full-width square to fill the row
      height: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.7),
            spreadRadius: 4,
            blurRadius: 15,
            offset: Offset(9, 7), 
          ),
        ],
      ),
      child: Center(
        child: Text(
          mode,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
}
