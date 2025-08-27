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

shared ({caller = owner}) persistent actor class Canister() = this {
  transient let ownerAdmin :Principal = Principal.fromText("cfklm-6bmf5-bovci-hk76c-rue3p-axnze-w2tjc-vpfdk-wppgd-xj2yv-2qe");
  transient let featureAdmin :Principal = Principal.fromText("uwvp7-5unl6-4dyas-6jbow-q4uqv-3g7i7-pyigh-qabzl-vixut-mbsiu-kqe");

  public type MessageType = {
    #Text;
    #Image;
    #File;
  };

  public type Message = {
    messageID: Text;        // 消息唯一 ID
    from: Principal;        // 发送者
    to: Principal;          // 接收者
    content: Text;          // 消息内容
    messageType: MessageType;
    timestamp: Int;         // 纳秒时间戳
    isRead: Bool;           // 是否已读
};


  // 专栏储存信息
  private var featureToData_s: [(Text, Types.Feature)] = [];
  private transient let featureToData = HashMap.fromIter<Text, Types.Feature>(featureToData_s.vals(), 0, Text.equal, Text.hash);

  // 动态信息
  private var postsToData_sV2: [(Text, Posts.Posts)] = [];
  private transient let postsToDataV2 = HashMap.fromIter<Text, Posts.Posts>(postsToData_sV2.vals(), 0, Text.equal, Text.hash);

  // 用户评论评分
  private var ratingToData_s: [(Text, Types.Rating)] = [];
  private transient let ratingToData = HashMap.fromIter<Text, Types.Rating>(ratingToData_s.vals(), 0, Text.equal, Text.hash);
  
  // 用户项目收藏信息
  private var favoritesToData_s: [(Principal, Types.Favorites)] = [];
  private transient let favoritesToData = HashMap.fromIter<Principal, Types.Favorites>(favoritesToData_s.vals(), 0, Principal.equal, Principal.hash);

  // 所有聊天记录
  private var chatStore_s: [(Text, [Message])] = [];
  private transient let chatStore = HashMap.fromIter<Text, [Message]>(chatStore_s.vals(), 0, Text.equal, Text.hash);


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
  transient let center:CenterCanister = actor("yffxi-vqaaa-aaaak-qcrnq-cai");

  //同步
  public type SaveCanister = actor {
      saveFavoritesToSave : shared ({date:Text;dataList:[(Principal, Types.Favorites)]}) -> async ();
      saveRatingToSave : shared ({date:Text;dataList:[(Text, Types.Rating)]}) -> async ();
      saveFeatureToSave : shared ({date:Text;dataList:[(Text, Types.Feature)]}) -> async ();
      savePostsToSave : shared ({date:Text;dataList:[(Text, Posts.Posts)]}) -> async ();
  };
   transient let SaveCanister : SaveCanister = actor("emmm6-kaaaa-aaaak-qlnwa-cai");


  public query func getCycleBalance() : async Nat {
      Cycles.balance();
  };

   // 接收cycles的函数
  public func wallet_receive() : async { accepted: Nat } {
    let available = Cycles.available();
    let accepted = Cycles.accept<system>(available);
    return { accepted = accepted };
  };

  
  /*
  * 私聊
  */

  //私聊会话标识
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

  //发送消息
  public shared({ caller }) func sendMessage({ to: Principal; content: Text; messageType: MessageType }) : async Bool {
    if (Text.size(content) > 4096) return false;
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

  //获取聊天记录
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

  //标记为已读
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
    chatWith: Types.UserBasic;       // 对方用户
    lastMessage: Text;         // 最后一条消息
    lastTime: Int;             // 时间戳
    isUnread: Bool;            // 是否有未读
  };

  //查询聊天列表
  public composite query({ caller }) func getChatList() : async [ChatPreview] {
    var result = Buffer.Buffer<ChatPreview>(0);
    var chatWithList = Buffer.Buffer<Principal>(0);
    var chatMap =  HashMap.fromIter<Principal, {
      lastMessage: Text;
      lastTime: Int;
      isUnread: Bool;
    }>([].vals(), 0, Principal.equal, Principal.hash);

    // Step 1: 先遍历所有会话，收集与之对话的对方 Principal
    for ((chatID, messages) in chatStore.entries()) {
      if (Text.contains(chatID, #text (Principal.toText(caller)))) {
        if (messages.size() > 0) {
          let last = messages[messages.size() - 1];

          if (Principal.equal(last.from, caller) and Principal.equal(last.to, caller)) {
            // 跳过自言自语
          } else {
            let other = if (Principal.equal(last.from, caller)) last.to else last.from;

            // 是否已经处理过该用户（避免重复添加）
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

    // Step 2: 获取批量用户信息
    let userInfos = await center.getUserIDList({ userList = Buffer.toArray(chatWithList) });

    // Step 3: 拼接完整的 ChatPreview
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
  * 专栏
  */

  //获取专栏项目详情
  public composite query func getFeature({featureID:Text}): async {feature:?Types.Feature;itemList:[Item.Items]} {
    //获取该专栏
    var itemList:[Item.Items] = [];
    var feature = switch (featureToData.get(featureID)) {
        case null null;
        case (?f) { 
          //获取完整的项目列表
           itemList := await center.getItemIDList({itemList=f.itemList});
          //返回项目专栏详情
          ?f;
         };
      };
      return {feature=feature;itemList=itemList};
  };

  //创建专栏 owner
  public shared({ caller }) func createOrUpdateFeature({featureID:Text;title:Text;desc:Text;background:Text;coverImage:Text;itemList:[Text];location:Text;}):  () {
    assert(Principal.equal(caller,featureAdmin));
        //更新专栏-转移专栏
        if(featureID==location){
          featureToData.put(featureID,{
            featureID; // 专栏ID
            title;//专栏标题
            desc;//专栏描述
            background;//专栏背景
            coverImage;//封面图片
            itemList//项目合集
          })
        }else{
          //获取历史首页位置的专栏内容
         switch (featureToData.get(location)) {
              case (null) {
                //若专栏位置为空 则直接转移并删除之前ID
                featureToData.put(location,{
                  featureID=location; // 专栏ID
                  title;//专栏标题
                  desc;//专栏描述
                  background;//专栏背景
                  coverImage;//封面图片
                  itemList//项目合集
                });
                featureToData.delete(featureID);
              }; 
              case (?f) {
              //将展示位置与当前feature对象内容互换
              featureToData.put(featureID,{
                featureID; // 专栏ID
                title=f.title;//专栏标题
                desc=f.desc;//专栏描述
                background=f.background;//专栏背景
                coverImage=f.coverImage;//封面图片
                itemList=f.itemList//项目合集
              });
              featureToData.put(location,{
                featureID=location; // 专栏ID
                title;//专栏标题
                desc;//专栏描述
                background;//专栏背景
                coverImage;//封面图片
                itemList//项目合集
              })
              }
          };
    };
  };

  //删除专栏
  public shared({ caller }) func removeFeature({featureID:Text}): () {
    assert(Principal.equal(caller,featureAdmin));

    //判断是否有删除权限
    switch (featureToData.get(featureID)) {
      case null {};
      case (_) {            
         featureToData.delete(featureID);
      };
    };
  };

  //获取专栏列表
  public query func getFeatureList({page:Nat;pageSize:Nat}): async {
      listSize:Nat;
      dataList:[(Text, Types.Feature)];
      dataPage:Nat;
  } {
    //获取专栏元组
    var list = Iter.toArray(featureToData.entries());

    let (pagedItems, total) = Types.paginate(list, page, pageSize);
    {
      listSize = total;
      dataList = pagedItems;
      dataPage = page;
    }
  };

  /*
  * 发布动态
  */

  //发布动态
  public shared({ caller }) func createPosts({content: Text;mediaContent: Text;mediaType: Posts.MediaType; parentTweetId: Text}): () {
    assert(Principal.isAnonymous(caller)==false);
    let postsID = await Types.genRandomSha256Id();
    switch (postsToDataV2.get(postsID)) {
      case null {
      //获取用户详情
      switch (await center.getUserBasic({ caller })) {
          case null {};
          case (?u) { 
              Posts.setPosts(postsToDataV2,postsID,u,content,[],mediaContent,mediaType,[],parentTweetId);
              //若为回复消息 则更新父级回复列表ID
              if(parentTweetId!=""){
                  //获取父级详情 更新回复列表
                  switch (postsToDataV2.get(parentTweetId)) { 
                    case (null) {}; 
                    case (?p) {
                      //将新发布的动态绑定至父级ID列表
                      let replies = Array.append<Text>(p.replies,[postsID]);
                      Posts.updateReplies(postsToDataV2,p.postsID,replies);
                    }; 
                  };
              }
          };
      };
      };
      case (_) {};
    };
  };

  // 获取动态详情
  public shared func getPosts({postsID:Text}):async ?Posts.Posts {
    //获取用户详情
    switch (postsToDataV2.get(postsID)) {
        case null null;
        case (?p) {?p};
      };
  };

  // 获取动态列表 
  public composite query func getPostsList({pageSize:Nat}): async [(?Item.Items,Posts.Posts)] {
    //排序项目
    var postList = Array.sort(Iter.toArray(postsToDataV2.entries()), func (a1 : (Text, Posts.Posts), a2 :(Text, Posts.Posts)) : Order.Order {
      if (a1.1.createTime < a2.1.createTime) {
        return #greater;
      } else if (a1.1.createTime > a2.1.createTime) {
        return #less;
      } else {
        return #equal;
      }
    });

    //拆分ItemID  
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
    //获取项目列表
    var itemList :[Item.Items]= await center.getItemIDList({itemList=Buffer.toArray(itemIDList)});

    //获取动态元组
    var list = Buffer.Buffer<(?Item.Items,Posts.Posts)>(0);

    for(post in postsList.vals()){
      let item = Array.find<Item.Items>(itemList, func x = x.itemID == post.mediaContent);
      list.add((item ,post));
    };

    Buffer.toArray(list);
  };


  // 获取回复列表
  public query func getRepliesList({postsID:Text;pageSize:Nat}): async [Posts.Posts] {
    //获取动态元组
    var list = Buffer.Buffer<Posts.Posts>(0);
    //获取父级详情 更新回复列表
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

    //排序列表 新回复在前
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
  

  //点赞 or 取消点赞
  public shared({ caller }) func updatePostsLikes({postsID:Text}): async () {
    assert(Principal.isAnonymous(caller)==false);

    //前置条件判断该用户是否点赞
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

  //删除
  public shared({ caller }) func removePosts({postsID:Text}): async () {
    //前置条件判断评论用户是否是该用户
    switch (postsToDataV2.get(postsID)) { 
      case (null) {}; 
      case (?p) {
        if(Principal.equal(p.user.userID, caller)){
          Posts.removePosts(postsToDataV2,p.postsID);
        }
      }; 
    };
  };

  //通过用户ID获取动态列表
  public composite query func getUserPostsList({caller:Principal;pageSize:Nat}): async [(?Item.Items,Posts.Posts)] {
    //拆分ItemID  
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
    //获取项目列表
    var itemList :[Item.Items]= await center.getItemIDList({itemList=Buffer.toArray(itemIDList)});

    //获取动态元组
    var postList = Buffer.Buffer<(?Item.Items,Posts.Posts)>(0);

    for(post in postsList.vals()){
      let item = Array.find<Item.Items>(itemList, func x = x.itemID == post.mediaContent);
      postList.add((item ,post));
    };

    //排序列表 新回复在前
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

  //通过用户ID获取动态数
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
  * 评分操作 //评分留言
  */

  //获取项目评论列表
  public composite query func getItemRatingList({itemID:Text;pageSize:Nat}): async {
      listSize:Nat;
      dataList:[Types.RatingList];
  } {
     //获取项目列表元组
    var itemList = Buffer.Buffer<Types.RatingList>(0);
    var listSize = 0;
    switch (ratingToData.get(itemID)) {
      case null {};
      case (?r) { 
          //循环重组项目
         listSize := r.ratingList.size();
         label letters for((id,rating) in r.ratingList.vals()){
            // 获取用户信息
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
    //分页
    {
      listSize = itemList.size();
      dataList = Buffer.toArray(itemList);
    }
  };
  
  //项目评分
  public shared({ caller }) func itemRating({itemID:Text;rating:Float;comment:Text}):  () {
    assert(Principal.isAnonymous(caller)==false);
    if (rating < 0.0 or rating > 5.0) return ();
    if (Text.size(comment) > 2000) return ();

    //判断是否是首次评分
    switch (ratingToData.get(itemID)) {
      case null {
        ratingToData.put(itemID,{
          itemID = itemID; // 项目ID
          ratingList=// 用户评分列表
          [(caller,{ 
            rating=rating; // 评分分数
            comment=comment; // 评论
            dislike=0;
            like=0;
            time=Time.now(); // 评分时间
          })];
        });

        //更新项目评分
        await center.uploadItemRating({itemID;rating});
      };
      case (?r) {            
        //转换
        let hashRating = HashMap.fromIter<Principal, {rating:Float;comment:Text; dislike:Int;like:Int; time:Int;}>(r.ratingList.vals(), 0, Principal.equal, Principal.hash);
        hashRating.put(caller,{
          rating=rating; // 评分分数
          comment=comment; // 评论
          dislike=0;
          like=0;
          time=Time.now(); // 评分时间
        });

        ratingToData.put(itemID,{
          itemID = itemID; // 用户ID
          ratingList=Iter.toArray(hashRating.entries());// 用户评论列表
        });

        var count:Float = 0;
        //计算平均分
        for((rating) in hashRating.vals()){
          count:=count+rating.rating
        };

        //更新项目评分
        await center.uploadItemRating({itemID;rating=(count/Float.fromInt(r.ratingList.size()))});
      };
    };

    
  };
  
  //获取当前项目是否已评分
  public query({ caller }) func getItemIsRating({itemID: Text}): async (Bool) {
    //储存我的收藏
    var follow = false;
    //获取收藏详情
    switch (ratingToData.get(itemID)) {
      case null {};
      case (?r) {            
        //转换
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
  * 收藏操作
  */


  //收藏项目
  public shared({ caller }) func collection({ authorID : Principal; itemID : Text }) : () {
    assert(Principal.isAnonymous(caller) == false);
    if (Types.isLen20to32NoSymbol(itemID,20,32)) {
      var isNew = false;

      switch (favoritesToData.get(caller)) {
        // 首次有该用户的收藏记录
        case null {
          isNew := true;
          favoritesToData.put(
            caller,
            {
              userID = caller;
              favoritesList = [
                (
                  itemID,
                  {
                    userID = authorID;
                    itemID = itemID;
                    time = Time.now();
                  }
                )
              ];
            }
          );
        };

        // 已有该用户的收藏记录
        case (?f) {
          let hashFavorites =
            HashMap.fromIter<Text, { userID : Principal; itemID : Text; time : Int }>(
              f.favoritesList.vals(),
              0,
              Text.equal,
              Text.hash
            );

          // 只在不存在该 itemID 时视为“新收藏”
          switch (hashFavorites.get(itemID)) {
            case null {
              isNew := true;
              hashFavorites.put(
                itemID,
                {
                  userID = authorID;
                  itemID = itemID;
                  time = Time.now();
                }
              );
              favoritesToData.put(
                caller,
                {
                  userID = caller;
                  favoritesList = Iter.toArray(hashFavorites.entries());
                }
              );
            };
            case (?_) {
              // 已经收藏过：不更新 favoritesToData（如需更新时间可在此单独更新，但仍不计数）
            };
          };
        };
      };

      // 仅“首次收藏”才累加项目收藏数，避免短时间多次点击导致无限累加
      if (isNew) {
        await center.uploadItemFavorites({ itemID; favorite = 1 });
      };
    };
  };


  //取消收藏
  public shared({ caller }) func cancelCollection({ itemID : Text }) : () {
    // 获取收藏详情
    switch (favoritesToData.get(caller)) {
      case null {
        // 用户没有任何收藏：不做任何事，不扣减
        ();
      };

      case (?f) {
        // 转换为 HashMap 以便删除
        let hashFavorites =
          HashMap.fromIter<Text, { userID : Principal; itemID : Text; time : Int }>(
            f.favoritesList.vals(),
            0,
            Text.equal,
            Text.hash
          );

        // 只有真的删掉了该项，才算“取消收藏成功”
         let removed : Bool = switch (hashFavorites.remove(itemID)) {
            case (?_) true;
            case null false;
          };

        if (removed) {
          // 仅在发生变化时回写用户收藏列表
          favoritesToData.put(
            caller,
            {
              userID = caller;                         // 用户ID
              favoritesList = Iter.toArray(hashFavorites.entries()); // 用户收藏列表
            }
          );

          // 仅“成功移除”才扣减，避免重复点击导致无限扣减
          await center.uploadItemFavorites({ itemID; favorite = -1 });
        };
      };
    };
  };


  //获取当前项目是否被我收藏
  public query({ caller }) func getCollection({itemID: Text}): async (Bool) {
    //储存我的收藏
    var follow = false;
    //获取收藏详情
    switch (favoritesToData.get(caller)) {
      case null {};
      case (?f) {            
        //转换
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

  //获取用户收藏列表
  public composite query({ caller }) func getCollectionList({page:Nat;pageSize:Nat}): async {
      listSize:Nat;
      dataList:[Item.Items];
      dataPage:Nat;
  }  {
    var itemList:[Item.Items] = [];
    //获取收藏详情
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

  //获取用户收藏数
  public query({ caller }) func getCollectionSize(): async (Nat) {
    var itemList = 0;
    //获取收藏详情
    switch (favoritesToData.get(caller)) {
      case null {};
      case (?f) {            
        //转换
       itemList:= f.favoritesList.size();

      };
    };
     //分页
    itemList
  };

  //备份数据
  private func saveAllData(): async () {
    let date = Int.toText(Time.now() / Types.second);
    // 备份文件收藏数据
    await Types.backupData({data=Iter.toArray(favoritesToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Principal, Types.Favorites)]) : async () { await SaveCanister.saveFavoritesToSave({ date = d; dataList })}});
    // 备份评分数据
    await Types.backupData({data=Iter.toArray(ratingToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Types.Rating)]) : async () { await SaveCanister.saveRatingToSave({ date = d; dataList })}});
    // 备份合集数据
    await Types.backupData({data=Iter.toArray(featureToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Types.Feature)]) : async () { await SaveCanister.saveFeatureToSave({ date = d; dataList })}});
    // 备份动态数据
    await Types.backupData({data=Iter.toArray(postsToDataV2.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Posts.Posts)]) : async () { await SaveCanister.savePostsToSave({ date = d; dataList })}});
  };

  ignore Timer.recurringTimer<system>(#seconds 604800, saveAllData);

  //手动存储数据
  public shared({ caller }) func setSaveAllData({date:Text}): async () {
    assert(Principal.equal(caller,ownerAdmin));
    // 备份文件收藏数据
    await Types.backupData({data=Iter.toArray(favoritesToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Principal, Types.Favorites)]) : async () { await SaveCanister.saveFavoritesToSave({ date = d; dataList })}});
    // 备份评分数据
    await Types.backupData({data=Iter.toArray(ratingToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Types.Rating)]) : async () { await SaveCanister.saveRatingToSave({ date = d; dataList })}});
    // 备份合集数据
    await Types.backupData({data=Iter.toArray(featureToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Types.Feature)]) : async () { await SaveCanister.saveFeatureToSave({ date = d; dataList })}});
    // 备份动态数据
    await Types.backupData({data=Iter.toArray(postsToDataV2.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Posts.Posts)]) : async () { await SaveCanister.savePostsToSave({ date = d; dataList })}});
  };

}