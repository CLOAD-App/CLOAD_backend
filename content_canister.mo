import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Bool "mo:base/Bool";
import Array "mo:base/Array";
import Order "mo:base/Order";
import Float "mo:base/Float";
import Timer "mo:base/Timer";
import Cycles "mo:base/ExperimentalCycles";

import Types "types";
import Posts "posts";
import Item "item";

shared ({caller = owner}) actor class Canister() = this {
  let ownerAdmin :Principal = Principal.fromText("");
  let featureAdmin :Principal = Principal.fromText("");

  public type MessageType = {
    #Text;
    #Image;
    #File;
  };

  public type Message = {
    messageID: Text;        // Unique message ID (can be a hash)
    from: Principal;        // Sender
    to: Principal;          // Receiver
    content: Text;          // Message content (plain text/link)
    messageType: MessageType;
    timestamp: Int;         // Nanosecond timestamp
    isRead: Bool;           // Whether the message has been read
};

  // Feature storage information
  private stable var featureToData_s: [(Text, Types.Feature)] = [];
  private let featureToData = HashMap.fromIter<Text, Types.Feature>(featureToData_s.vals(), 0, Text.equal, Text.hash);

  // Post information
  private stable var postsToData_sV2: [(Text, Posts.Posts)] = [];
  private let postsToDataV2 = HashMap.fromIter<Text, Posts.Posts>(postsToData_sV2.vals(), 0, Text.equal, Text.hash);

  // User rating comments
  private stable var ratingToData_s: [(Text, Types.Rating)] = [];
  private let ratingToData = HashMap.fromIter<Text, Types.Rating>(ratingToData_s.vals(), 0, Text.equal, Text.hash);
  // User favorite items
  private stable var favoritesToData_s: [(Principal, Types.Favorites)] = [];
  private let favoritesToData = HashMap.fromIter<Principal, Types.Favorites>(favoritesToData_s.vals(), 0, Principal.equal, Principal.hash);
  // All chat records
  private stable var chatStore_s: [(Text, [Message])] = [];
  private let chatStore = HashMap.fromIter<Text, [Message]>(chatStore_s.vals(), 0, Text.equal, Text.hash);

  system func preupgrade() {
    ratingToData_s := Iter.toArray(ratingToData.entries());
    featureToData_s := Iter.toArray(featureToData.entries());
    favoritesToData_s := Iter.toArray(favoritesToData.entries());
    chatStore_s := Iter.toArray(chatStore.entries());
    postsToData_sV2 := Iter.toArray(postsToDataV2.entries());
  };

  system func postupgrade() {
    ratingToData_s := [];
    featureToData_s := [];
    favoritesToData_s := [];
    chatStore_s := [];
    postsToData_sV2 := [];
  };

  public type CenterCanister = actor {
      getItemIDList : query ({itemList: [Text]}) -> async ([Item.Items]);
      uploadItemRating : shared ({itemID: Text;rating:Float}) -> async ();
      uploadItemFavorites : shared ({itemID: Text;favorite:Int}) -> async ();
      getUserBasic : query ({ caller:Principal }) -> async (?Types.UserBasic);
      getUserIDList : query ({userList: [Principal]}) -> async ([Types.UserBasic]);
  };
  let center:CenterCanister = actor("yffxi-vqaaa-aaaak-qcrnq-cai");

  // Synchronization
  public type SaveCanister = actor {
      saveFavoritesToSave : shared ({date:Text;dataList:[(Principal, Types.Favorites)]}) -> async ();
      saveRatingToSave : shared ({date:Text;dataList:[(Text, Types.Rating)]}) -> async ();
      saveFeatureToSave : shared ({date:Text;dataList:[(Text, Types.Feature)]}) -> async ();
      savePostsToSave : shared ({date:Text;dataList:[(Text, Posts.Posts)]}) -> async ();
  };
   let SaveCanister : SaveCanister = actor("emmm6-kaaaa-aaaak-qlnwa-cai");

  public query func getCycleBalance() : async Nat {
      Cycles.balance();
  };

   // Function to receive cycles
  public func wallet_receive() : async { accepted: Nat } {
    let available = Cycles.available();
    let accepted = Cycles.accept<system>(available);
    return { accepted = accepted };
  };

  /*
  * Private Chat
  */

  // Private chat session identifier
  func generateChatID(userA: Principal, userB: Principal): Text {
    if (Principal.toText(userA) < Principal.toText(userB)) {
      return Principal.toText(userA) # "_" # Principal.toText(userB);
    } else {
      return Principal.toText(userB) # "_" # Principal.toText(userA);
    }
  };

  func arraySome<T>(arr: [T], f: T -> Bool): Bool {
    for (item in arr.vals()) {
      if (f(item)) {
        return true;
      }
    };
    return false;
  };

  func arrayContains(arr: [Principal], target: Principal): Bool {
    Array.find<Principal>(arr, func(x) { Principal.equal(x, target) }) != null
  };

  // Send message
  public shared({ caller }) func sendMessage({ to: Principal; content: Text; messageType: MessageType }) : async Bool {
    let now = Time.now();
    let messageID = debug_show(now) # Principal.toText(caller);
    let chatID = generateChatID(caller, to);

    let newMsg : Message = {
      messageID;
      from = caller;
      to;
      content;
      messageType;
      timestamp = now;
      isRead = false;
    };

    switch (chatStore.get(chatID)) {
      case (null) { chatStore.put(chatID, [newMsg]); };
      case (?msgs) { chatStore.put(chatID, Array.append(msgs, [newMsg])); };
    };

    true
  };

  // Get chat messages
  public query({ caller }) func getChatMessages({  userB: Principal; page: Nat; pageSize: Nat }) : async [Message] {
    let chatID = generateChatID(caller, userB);
    switch (chatStore.get(chatID)) {
      case (null) return [];
      case (?msgs) {
        let total = msgs.size();
        let startIndex : Nat = if (total <= page * pageSize) 0 else total - (page * pageSize);
        let endIndex : Nat = if (startIndex + pageSize > total) total else startIndex + pageSize;
        return Array.subArray(msgs, startIndex, endIndex - startIndex : Nat);
      };
    }
  };

  // Mark as read
  public shared({ caller }) func markMessagesAsRead({ withUser: Principal }) : async Bool {
    let chatID = generateChatID(caller, withUser);

    switch (chatStore.get(chatID)) {
      case null return false;
      case (?msgs) {
        let updated = Array.map<Message, Message>(msgs, func(msg) {
          if (Principal.equal(msg.to, caller)) {
            { msg with isRead = true }
          } else msg
        });
        chatStore.put(chatID, updated);
        return true;
      };
    }
  };

  public type ChatPreview = {
    chatWith: Types.UserBasic;       // Other user
    lastMessage: Text;         // Last message
    lastTime: Int;             // Timestamp
    isUnread: Bool;            // Whether there are unread messages
  };

  // Query chat list
  public composite query({ caller }) func getChatList() : async [ChatPreview] {
    var result = Buffer.Buffer<ChatPreview>(0);
    var chatWithList = Buffer.Buffer<Principal>(0);
    var chatMap =  HashMap.fromIter<Principal, {
      lastMessage: Text;
      lastTime: Int;
      isUnread: Bool;
    }>([].vals(), 0, Principal.equal, Principal.hash);

    // Step 1: Iterate through all sessions to collect the other user's Principal
    for ((chatID, messages) in chatStore.entries()) {
      if (Text.contains(chatID, #text (Principal.toText(caller)))) {
        if (messages.size() > 0) {
          let last = messages[messages.size() - 1];

          if (Principal.equal(last.from, caller) and Principal.equal(last.to, caller)) {
            // Skip self-talk
          } else {
            let other = if (Principal.equal(last.from, caller)) last.to else last.from;

            // Check if the user has already been processed (to avoid duplicates)
            if (not arrayContains(Buffer.toArray(chatWithList), other)) {
              chatWithList.add(other);

              let hasUnread = arraySome<Message>(messages, func(m) {
                Principal.equal(m.to, caller) and not m.isRead
              });

              chatMap.put((other, {
                lastMessage = last.content;
                lastTime = last.timestamp;
                isUnread = hasUnread;
              }));
            };
          }
        }
      }
    };

    // Step 2: Get batch user information
    let userInfos = await center.getUserIDList({ userList = Buffer.toArray(chatWithList) });

    // Step 3: Construct complete ChatPreview
    for (user in userInfos.vals()) {
      switch (chatMap.get(user.userID)) {
        case (?info) {
          result.add({
            chatWith = user;
            lastMessage = info.lastMessage;
            lastTime = info.lastTime;
            isUnread = info.isUnread;
          });
        };
        case null {};
      };
    };
    Buffer.toArray(result);
  };

  /*
  * Features
  */

  // Get feature item details
  public composite query func getFeature({featureID:Text}): async {feature:?Types.Feature;itemList:[Item.Items]} {
    // Get the feature
    var itemList:[Item.Items] = [];
    var feature = switch (featureToData.get(featureID)) {
        case null null;
        case (?f) { 
          // Get the complete item list
           itemList := await center.getItemIDList({itemList=f.itemList});
          // Return feature details
          ?f;
         };
      };
      return {feature=feature;itemList=itemList};
  };

  // Create or update feature (owner)
  public shared({ caller }) func createOrUpdateFeature({featureID:Text;title:Text;desc:Text;background:Text;coverImage:Text;itemList:[Text];location:Text;}):  () {
    assert(Principal.equal(caller,featureAdmin));
    // Update feature - transfer feature
        if(featureID==location){
          featureToData.put(featureID,{
            featureID; // Feature ID
            title;// Feature title
            desc;// Feature description
            background;// Feature background
            coverImage;// Cover image
            itemList// Item collection
          })
        }else{
          // Get the historical homepage feature content
         switch (featureToData.get(location)) {
              case (null) {
                // If the feature location is empty, transfer directly and delete the previous ID
                featureToData.put(location,{
                  featureID=location; // Feature ID
                  title;// Feature title
                  desc;// Feature description
                  background;// Feature background
                  coverImage;// Cover image
                  itemList// Item collection
                });
                featureToData.delete(featureID);
              }; 
              case (?f) {
              // Swap the display location with the current feature content
              featureToData.put(featureID,{
                featureID; // Feature ID
                title=f.title;// Feature title
                desc=f.desc;// Feature description
                background=f.background;// Feature background
                coverImage=f.coverImage;// Cover image
                itemList=f.itemList// Item collection
              });
              featureToData.put(location,{
                featureID=location; // Feature ID
                title;// Feature title
                desc;// Feature description
                background;// Feature background
                coverImage;// Cover image
                itemList// Item collection
              })
              }
          };
    };
  };

  // Delete feature
  public shared({ caller }) func removeFeature({featureID:Text}): () {
    assert(Principal.equal(caller,ownerAdmin));

    // Check if there is permission to delete
    switch (featureToData.get(featureID)) {
      case null {};
      case (_) {            
         featureToData.delete(featureID);
      };
    };
  };

  // Get feature list
  public query func getFeatureList({page:Nat;pageSize:Nat}): async {
      listSize:Nat;
      dataList:[(Text, Types.Feature)];
      dataPage:Nat;
  } {
    // Get feature tuple
    var list = Iter.toArray(featureToData.entries());

    let (pagedItems, total) = Types.paginate(list, page, pageSize);
    {
      listSize = total;
      dataList = pagedItems;
      dataPage = page;
    }
  };

    /*
  * Post Publishing
  */

  // Create post
  public shared({ caller }) func createPosts({postsID:Text;content: Text;mediaContent: Text;mediaType: Posts.MediaType; parentTweetId: Text}): () {
    assert(Principal.isAnonymous(caller)==false);
    // Get user details
    switch (await center.getUserBasic({ caller = caller })) {
        case null {};
        case (?u) { 
            Posts.setPosts(postsToDataV2,postsID,u,content,[],mediaContent,mediaType,[],parentTweetId);
            // If it is a reply message, update the parent reply list ID
            if(parentTweetId!=""){
                // Get parent details and update reply list
                switch (postsToDataV2.get(parentTweetId)) { 
                  case (null) {}; 
                  case (?p) {
                    // Bind the newly posted content to the parent ID list
                    let replies = Array.append<Text>(p.replies,[postsID]);
                    Posts.updateReplies(postsToDataV2,p.postsID,replies);
                  }; 
                };
            }
          };
      };
  };

  // Get post details
  public shared func getPosts({postsID:Text}):async ?Posts.Posts {
    // Get user details
    switch (postsToDataV2.get(postsID)) {
        case null null;
        case (?p) {?p};
      };
  };

  // Get post list
  public composite query func getPostsList({pageSize:Nat}): async [(?Item.Items,Posts.Posts)] {
    // Sort posts
    var postList = Array.sort(Iter.toArray(postsToDataV2.entries()), func (a1 : (Text, Posts.Posts), a2 :(Text, Posts.Posts)) : Order.Order {
      if (a1.1.createTime < a2.1.createTime) {
        return #greater;
      } else if (a1.1.createTime > a2.1.createTime) {
        return #less;
      } else {
        return #equal;
      }
    });

    // Split ItemID
    var itemIDList = Buffer.Buffer<Text>(0);
    var postsList = Buffer.Buffer<Posts.Posts>(0);

    label letters for((id,post) in postList.vals()){
      if(post.parentTweetId=="" and post.isActive){
        itemIDList.add(post.mediaContent);
        postsList.add(post);
        if(itemIDList.size()==pageSize){
          break letters
        }
      };
    };
    // Get item list
    var itemList :[Item.Items]= await center.getItemIDList({itemList=Buffer.toArray(itemIDList)});

    // Get post tuple
    var list = Buffer.Buffer<(?Item.Items,Posts.Posts)>(0);

    for(post in postsList.vals()){
      let item = Array.find<Item.Items>(itemList, func x = x.itemID == post.mediaContent);
      list.add((item ,post));
    };

    Buffer.toArray(list);
  };

  // Get reply list
  public query func getRepliesList({postsID:Text;pageSize:Nat}): async [Posts.Posts] {
    // Get post tuple
    var list = Buffer.Buffer<Posts.Posts>(0);
    // Get parent details and update reply list
    switch (postsToDataV2.get(postsID)) { 
      case (null) {}; 
      case (?p) {
       label letters for(id in p.replies.vals()){
          switch (postsToDataV2.get(id)) { 
            case (null) {}; 
            case (?pp) {
              if(pp.isActive){
                  list.add(pp);
                if(list.size()==pageSize){
                  break letters
                }
              }
            };
          };
        };
      }; 
    };

    // Sort list, newer replies first
    Array.sort(Buffer.toArray(list), func (a1 : Posts.Posts, a2 :Posts.Posts) : Order.Order {
        if (a1.createTime < a2.createTime) {
          return #greater;
        } else if (a1.createTime > a2.createTime) {
          return #less;
        } else {
          return #equal;
        }
    });
  };

  // Like or unlike post
  public shared({ caller }) func updatePostsLikes({postsID:Text}): async () {
    assert(Principal.isAnonymous(caller)==false);

    // Check if the user has already liked the post
    switch (postsToDataV2.get(postsID)) { 
      case (null) {}; 
      case (?p) {
       let isCaller = Array.find<Principal>(p.likes, func x = x == caller);
        if(isCaller != null){
          Posts.updatePostsLikes(postsToDataV2,postsID,Array.filter<Principal>(p.likes, func x = x != caller));
        }else{
          Posts.updatePostsLikes(postsToDataV2,postsID,Array.append<Principal>(p.likes,[caller]));
        };
      }; 
    };
  };

  // Delete post
  public shared({ caller }) func removePosts({postsID:Text}): async () {
    // Check if the post belongs to the user
    switch (postsToDataV2.get(postsID)) { 
      case (null) {}; 
      case (?p) {
        if(Principal.equal(p.user.userID, caller)){
          Posts.removePosts(postsToDataV2,p.postsID);
        }
      }; 
    };
  };

  // Get post list by user ID
  public composite query func getUserPostsList({caller:Principal;pageSize:Nat}): async [(?Item.Items,Posts.Posts)] {
    // Split ItemID
    var itemIDList = Buffer.Buffer<Text>(0);
    var postsList = Buffer.Buffer<Posts.Posts>(0);

    label letters for((id,post) in Iter.toArray(postsToDataV2.entries()).vals()){
      if(Principal.equal(post.user.userID, caller) and post.isActive){
        itemIDList.add(post.mediaContent);
        postsList.add(post);
        if(itemIDList.size()==pageSize){
          break letters
        }
      };
    };
    // Get item list
    var itemList :[Item.Items]= await center.getItemIDList({itemList=Buffer.toArray(itemIDList)});

    // Get post tuple
    var postList = Buffer.Buffer<(?Item.Items,Posts.Posts)>(0);

    for(post in postsList.vals()){
      let item = Array.find<Item.Items>(itemList, func x = x.itemID == post.mediaContent);
      postList.add((item ,post));
    };

    // Sort list, newer posts first
    Array.sort(Buffer.toArray(postList), func (a1 : (?Item.Items,Posts.Posts), a2 :(?Item.Items,Posts.Posts)) : Order.Order {
        if (a1.1.createTime < a2.1.createTime) {
          return #greater;
        } else if (a1.1.createTime > a2.1.createTime) {
          return #less;
        } else {
          return #equal;
        }
    });
  };

  // Get number of posts by user ID
  public query({ caller }) func getUserPostSize(): async Int {
    var postSize = 0;
    for((id,posts) in Iter.toArray(postsToDataV2.entries()).vals()){
      if(Principal.equal(posts.user.userID, caller) and posts.isActive){
          postSize := postSize+1
      };
    };
    postSize;
  };

  /*
  * Rating Operations // Rating Comments
  */

  // Get item rating list
  public composite query func getItemRatingList({itemID:Text;pageSize:Nat}): async {
      listSize:Nat;
      dataList:[Types.RatingList];
  } {
     // Get item list tuple
    var itemList = Buffer.Buffer<Types.RatingList>(0);
    var listSize = 0;
    switch (ratingToData.get(itemID)) {
      case null {};
      case (?r) { 
          // Iterate and restructure items
         listSize := r.ratingList.size();
         label letters for((id,rating) in r.ratingList.vals()){
            // Get user information
            switch (await center.getUserBasic({ caller = id })) {
              case null {};
              case (?u) { 
                itemList.add({rating=rating.rating;comment=rating.comment;time=rating.time;name=u.name;avatarURL=u.avatarURL});
                if(itemList.size()==pageSize){
                  break letters
                }
              };
            };
          };
      };
    };
    // Paginate
    {
      listSize = itemList.size();
      dataList = Buffer.toArray(itemList);
    }
  };

  // Item rating
  public shared({ caller }) func itemRating({itemID:Text;rating:Float;comment:Text}):  () {
        assert(Principal.isAnonymous(caller)==false);
    // Check if it is the first rating
    switch (ratingToData.get(itemID)) {
      case null {
        ratingToData.put(itemID,{
          itemID = itemID; // Item ID
          ratingList=// User rating list
          [(caller,{ 
            rating=rating; // Rating score
            comment=comment; // Comment
            dislike=0;
            like=0;
            time=Time.now(); // Rating time
          })];
        });

        // Update item rating
        await center.uploadItemRating({itemID;rating});
      };
      case (?r) {            
        // Convert
        let hashRating = HashMap.fromIter<Principal, {rating:Float;comment:Text; dislike:Int;like:Int; time:Int;}>(r.ratingList.vals(), 0, Principal.equal, Principal.hash);
        hashRating.put(caller,{
          rating=rating; // Rating score
          comment=comment; // Comment
          dislike=0;
          like=0;
          time=Time.now(); // Rating time
        });

        ratingToData.put(itemID,{
          itemID = itemID; // User ID
          ratingList=Iter.toArray(hashRating.entries());// User comment list
        });

        var count:Float = 0;
        // Calculate average score
        for((id,rating) in r.ratingList.vals()){
          count:=count+rating.rating
        };

        // Update item rating
        await center.uploadItemRating({itemID;rating=(count/Float.fromInt(r.ratingList.size()))});
      };
    };
  };

  // Check if the current item has been rated
  public query({ caller }) func getItemIsRating({itemID: Text}): async (Bool) {
    // Store my ratings
    var follow = false;
    // Get rating details
    switch (ratingToData.get(itemID)) {
      case null {};
      case (?r) {            
        // Convert
        let hashRating = HashMap.fromIter<Principal, {rating:Float;comment:Text; dislike:Int;like:Int; time:Int;}>(r.ratingList.vals(), 0, Principal.equal, Principal.hash);
        switch (hashRating.get(caller)) {
          case null {};
          case (_) {
            follow := true
          };
        }
      };
    };
   return follow;
  };

    /*
  * Collection Operations
  */

  // Collect item
  public shared({ caller }) func collection({authorID:Principal;itemID:Text}):  () {
    assert(Principal.isAnonymous(caller)==false);
    // Check if it is the first collection
    switch (favoritesToData.get(caller)) {
      case null {
        favoritesToData.put(caller,{
          userID = caller; // User ID
          favoritesList=// User collection list
          [(itemID,{ 
            userID=authorID; // Author ID
            itemID=itemID; // Item ID
            time=Time.now(); // Collection time
          })];
        })
      };
      case (?f) {            
        // Convert
        let hashFavorites = HashMap.fromIter<Text, {userID: Principal;itemID:Text;time:Int;}>(f.favoritesList.vals(), 0, Text.equal, Text.hash);
        hashFavorites.put(itemID,{
          userID=authorID; // Author ID
          itemID=itemID; // Item ID
          time=Time.now(); // Collection time
        });

        favoritesToData.put(caller,{
          userID = caller; // User ID
          favoritesList=Iter.toArray(hashFavorites.entries());// User collection list
        })
      };
    };
    // Update item favorites
     await center.uploadItemFavorites({itemID;favorite=1});
  };

  // Cancel collection
  public shared({ caller }) func cancelCollection({itemID: Text}): () {
    // Get collection details
    switch (favoritesToData.get(caller)) {
      case null {};
      case (?f) {            
        // Convert
        let hashFavorites = HashMap.fromIter<Text, {userID: Principal;itemID:Text;time:Int;}>(f.favoritesList.vals(), 0, Text.equal, Text.hash);
        hashFavorites.delete(itemID);

        favoritesToData.put(caller,{
          userID = caller; // User ID
          favoritesList=Iter.toArray(hashFavorites.entries());// User collection list
        });

        // Update item favorites
        await center.uploadItemFavorites({itemID;favorite=-1});
      };
    };
  };

  // Check if the current item is collected by me
  public query({ caller }) func getCollection({itemID: Text}): async (Bool) {
    // Store my collections
    var follow = false;
    // Get collection details
    switch (favoritesToData.get(caller)) {
      case null {};
      case (?f) {            
        // Convert
        let hashFavorites = HashMap.fromIter<Text, {userID: Principal;itemID:Text;time:Int;}>(f.favoritesList.vals(), 0, Text.equal, Text.hash);
        switch (hashFavorites.get(itemID)) {
          case null {};
          case (?f) {
            follow := true
          };
        }
      };
    };
   return follow;
  };

  // Get user collection list
  public composite query({ caller }) func getCollectionList({page:Nat;pageSize:Nat}): async {
      listSize:Nat;
      dataList:[Item.Items];
      dataPage:Nat;
  }  {
    var itemList:[Item.Items] = [];
    // Get collection details
    switch (favoritesToData.get(caller)) {
      case null {};
      case (?f) {
        let itemIDsArray = Array.map<(Text, {itemID : Text; time : Int; userID : Principal}), Text>(
          f.favoritesList,
          func(_, record) { record.itemID }
        );
        itemList := await center.getItemIDList({itemList=itemIDsArray});
      };
    };

    let (pagedItems, total) = Types.paginate(itemList, page, pageSize);
    {
      listSize = total;
      dataList = pagedItems;
      dataPage = page;
    }
  };

  // Get user collection count
  public query({ caller }) func getCollectionSize(): async (Nat) {
    var itemList = 0;
    // Get collection details
    switch (favoritesToData.get(caller)) {
      case null {};
      case (?f) {            
        // Convert
       itemList:= f.favoritesList.size();
      };
    };
     // Paginate
    itemList
  };

  // Backup data
  private func saveAllData(): async () {
    let date = Int.toText(Time.now() / Types.second);
    // Backup favorites data
    await Types.backupData({data=Iter.toArray(favoritesToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Principal, Types.Favorites)]) : async () { await SaveCanister.saveFavoritesToSave({ date = d; dataList })}});
    // Backup rating data
    await Types.backupData({data=Iter.toArray(ratingToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Types.Rating)]) : async () { await SaveCanister.saveRatingToSave({ date = d; dataList })}});
    // Backup feature data
    await Types.backupData({data=Iter.toArray(featureToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Types.Feature)]) : async () { await SaveCanister.saveFeatureToSave({ date = d; dataList })}});
    // Backup post data
    await Types.backupData({data=Iter.toArray(postsToDataV2.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Posts.Posts)]) : async () { await SaveCanister.savePostsToSave({ date = d; dataList })}});
  };

  ignore Timer.recurringTimer<system>(#seconds 604800, saveAllData);

  // Manually save data
  public shared({ caller }) func setSaveAllData({date:Text}): async () {
    assert(Principal.equal(caller,ownerAdmin));
    // Backup favorites data
    await Types.backupData({data=Iter.toArray(favoritesToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Principal, Types.Favorites)]) : async () { await SaveCanister.saveFavoritesToSave({ date = d; dataList })}});
    // Backup rating data
    await Types.backupData({data=Iter.toArray(ratingToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Types.Rating)]) : async () { await SaveCanister.saveRatingToSave({ date = d; dataList })}});
    // Backup feature data
    await Types.backupData({data=Iter.toArray(featureToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Types.Feature)]) : async () { await SaveCanister.saveFeatureToSave({ date = d; dataList })}});
    // Backup post data
    await Types.backupData({data=Iter.toArray(postsToDataV2.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Posts.Posts)]) : async () { await SaveCanister.savePostsToSave({ date = d; dataList })}});
  };
}
