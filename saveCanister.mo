import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Prim "mo:⛔";
import Cycles "mo:base/ExperimentalCycles";


import Types "types";
import User "user";
import Item "item";
import Trade "trade";
import Posts "posts";


shared ({caller = owner}) persistent actor class Canister() = this {
  let ownerAdmin :Principal = Principal.fromText("cfklm-6bmf5-bovci-hk76c-rue3p-axnze-w2tjc-vpfdk-wppgd-xj2yv-2qe");
  let center :Principal = Principal.fromText("yffxi-vqaaa-aaaak-qcrnq-cai");
  let nftCanister :Principal = Principal.fromText("24t7b-laaaa-aaaak-quf6q-cai");
  let contentCanister :Principal = Principal.fromText("lyr3s-lqaaa-aaaak-qugvq-cai");

  system func preupgrade() {
    userToSave_s := Iter.toArray(userToSave.entries());
    followToSave_s := Iter.toArray(followToSave.entries());
    itemToSave_s := Iter.toArray(itemToSave.entries());
    storeToSave_s := Iter.toArray(storeToSave.entries());
    favoritesToSave_s := Iter.toArray(favoritesToSave.entries());
    ratingToSave_s := Iter.toArray(ratingToSave.entries());
    tradeToSave_s := Iter.toArray(tradeToSave.entries());
    refundsToSave_s := Iter.toArray(refundsToSave.entries());
    featureToSave_s := Iter.toArray(featureToSave.entries());
    postsToSave_s := Iter.toArray(postsToSave.entries());
    nftToSave_s := Iter.toArray(nftToSave.entries());
  };

  system func postupgrade() {
    userToSave_s := [];
    followToSave_s := [];
    itemToSave_s := [];
    storeToSave_s := [];
    favoritesToSave_s := [];
    ratingToSave_s := [];
    tradeToSave_s := [];
    refundsToSave_s := [];
    featureToSave_s := [];
    postsToSave_s := [];
    nftToSave_s := [];
  };
    
  public query func getSize() : async Nat {
      Prim.rts_memory_size();
  };

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
  * 用户信息
  */

  // 用户信息存档
  private var userToSave_s: [(Text, [(Principal, User.User)])] = [];
  private transient let userToSave = HashMap.fromIter<Text, [(Principal, User.User)]>(userToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func saveUserToSave({date:Text;dataList:[(Principal, User.User)]}):async () {
    if(Principal.equal(caller,center)){
        //判断该日期下是否已有存档
        switch (userToSave.get(date)) {
            case null {
                //若无存档则直接新建存档
                userToSave.put(date, dataList);
            };
            case (?u){
                //若存在存档则新建HashMap 重新赋值
                let data = HashMap.fromIter<Principal, User.User>(u.vals(), 0, Principal.equal, Principal.hash);
                for(user in dataList.vals()){
                    data.put(user);
                };
                userToSave.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getUser({date:Text}): async [(Principal, User.User)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (userToSave.get(date)) {
        case null [];
        case (?u) { u };
    };
  };

  /*
  * 关注信息
  */

  // 用户关注信息存档
  private var followToSave_s: [(Text, [(Principal, User.UserFollow)])] = [];
  private transient let followToSave = HashMap.fromIter<Text, [(Principal, User.UserFollow)]>(followToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func saveFollowToSave({date:Text;dataList:[(Principal, User.UserFollow)]}):async () {
    if(Principal.equal(caller,center)){
        //判断该日期下是否已有存档
        switch (followToSave.get(date)) {
            case null {
                //若无存档则直接新建存档
                followToSave.put(date, dataList);
            };
            case (?u){
                //若存在存档则新建HashMap 重新赋值
                let data = HashMap.fromIter<Principal, User.UserFollow>(u.vals(), 0, Principal.equal, Principal.hash);
                for(user in dataList.vals()){
                    data.put(user);
                };
                followToSave.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getFollow({date:Text}): async [(Principal, User.UserFollow)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (followToSave.get(date)) {
        case null [];
        case (?u) { u };
    };
  };

  /*
  * 项目信息
  */


  // 项目信息
  private var itemToSave_s: [(Text, [(Text, Item.Items)])] = [];
  private transient let itemToSave = HashMap.fromIter<Text, [(Text, Item.Items)]>(itemToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func saveItemToSave({date:Text;dataList:[(Text, Item.Items)]}):async () {
    if(Principal.equal(caller,center)){
        //判断该日期下是否已有存档
        switch (itemToSave.get(date)) {
            case null {
                //若无存档则直接新建存档
                itemToSave.put(date, dataList);
            };
            case (?u){
                //若存在存档则新建HashMap 重新赋值
                let data = HashMap.fromIter<Text, Item.Items>(u.vals(), 0, Text.equal, Text.hash);
                for(user in dataList.vals()){
                    data.put(user);
                };
                itemToSave.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getItem({date:Text}): async [(Text, Item.Items)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (itemToSave.get(date)) {
        case null [];
        case (?u) { u };
    };
  };

  /*
  * 文件索引信息
  */

  // 文件索引存储
  private var storeToSave_s: [(Text, [(Text, Types.FileStorage)])] = [];
  private transient let storeToSave = HashMap.fromIter<Text, [(Text, Types.FileStorage)]>(storeToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func saveStoreToSave({date:Text;dataList:[(Text, Types.FileStorage)]}):async () {
    if(Principal.equal(caller,center)){
        //判断该日期下是否已有存档
        switch (storeToSave.get(date)) {
            case null {
                //若无存档则直接新建存档
                storeToSave.put(date, dataList);
            };
            case (?u){
                //若存在存档则新建HashMap 重新赋值
                let data = HashMap.fromIter<Text, Types.FileStorage>(u.vals(), 0, Text.equal, Text.hash);
                for(user in dataList.vals()){
                    data.put(user);
                };
                storeToSave.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getStore({date:Text}): async [(Text, Types.FileStorage)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (storeToSave.get(date)) {
        case null [];
        case (?u) { u };
    };
  };


  /*
  * 项目收藏信息
  */

  // 用户项目收藏信息
  private var favoritesToSave_s: [(Text, [(Principal, Types.Favorites)])] = [];
  private transient let favoritesToSave = HashMap.fromIter<Text, [(Principal, Types.Favorites)]>(favoritesToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func saveFavoritesToSave({date:Text;dataList:[(Principal, Types.Favorites)]}):async () {
    if(Principal.equal(caller,contentCanister)){
        //判断该日期下是否已有存档
        switch (favoritesToSave.get(date)) {
            case null {
                //若无存档则直接新建存档
                favoritesToSave.put(date, dataList);
            };
            case (?u){
                //若存在存档则新建HashMap 重新赋值
                let data = HashMap.fromIter<Principal, Types.Favorites>(u.vals(), 0, Principal.equal, Principal.hash);
                for(user in dataList.vals()){
                    data.put(user);
                };
                favoritesToSave.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getFavorites({date:Text}): async [(Principal,Types.Favorites)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (favoritesToSave.get(date)) {
        case null [];
        case (?u) { u };
    };
  };


  /*
  * 用户评论评分信息
  */

  // 用户评论评分
  private var ratingToSave_s: [(Text, [(Text, Types.Rating)])] = [];
  private transient let ratingToSave = HashMap.fromIter<Text, [(Text, Types.Rating)]>(ratingToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func saveRatingToSave({date:Text;dataList:[(Text, Types.Rating)]}):async () {
    if(Principal.equal(caller,contentCanister)){
        //判断该日期下是否已有存档
        switch (ratingToSave.get(date)) {
            case null {
                //若无存档则直接新建存档
                ratingToSave.put(date, dataList);
            };
            case (?u){
                //若存在存档则新建HashMap 重新赋值
                let data = HashMap.fromIter<Text, Types.Rating>(u.vals(), 0, Text.equal, Text.hash);
                for(user in dataList.vals()){
                    data.put(user);
                };
                ratingToSave.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getRating({date:Text}): async [(Text, Types.Rating)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (ratingToSave.get(date)) {
        case null [];
        case (?u) { u };
    };
  };


 /*
  * 用户交易信息
  */

  // 用户交易信息
  private var tradeToSave_s: [(Text, [(Text, Trade.Transaction)])] = [];
  private transient let tradeToSave = HashMap.fromIter<Text, [(Text, Trade.Transaction)]>(tradeToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func saveTradeToSave({date:Text;dataList:[(Text, Trade.Transaction)]}):async () {
    if(Principal.equal(caller,center)){
        //判断该日期下是否已有存档
        switch (tradeToSave.get(date)) {
            case null {
                //若无存档则直接新建存档
                tradeToSave.put(date, dataList);
            };
            case (?u){
                //若存在存档则新建HashMap 重新赋值
                let data = HashMap.fromIter<Text, Trade.Transaction>(u.vals(), 0, Text.equal, Text.hash);
                for(user in dataList.vals()){
                    data.put(user);
                };
                tradeToSave.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getTrade({date:Text}): async [(Text, Trade.Transaction)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (tradeToSave.get(date)) {
        case null [];
        case (?u) { u };
    };
  };

  /*
  * 用户退款信息
  */

  // 用户退款信息
  private var refundsToSave_s: [(Text, [(Text, Trade.Refunds)])] = [];
  private transient let refundsToSave = HashMap.fromIter<Text, [(Text, Trade.Refunds)]>(refundsToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func saveFundsToSave({date:Text;dataList:[(Text, Trade.Refunds)]}):async () {
    if(Principal.equal(caller,center)){
        //判断该日期下是否已有存档
        switch (refundsToSave.get(date)) {
            case null {
                //若无存档则直接新建存档
                refundsToSave.put(date, dataList);
            };
            case (?u){
                //若存在存档则新建HashMap 重新赋值
                let data = HashMap.fromIter<Text, Trade.Refunds>(u.vals(), 0, Text.equal, Text.hash);
                for(user in dataList.vals()){
                    data.put(user);
                };
                refundsToSave.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getFunds({date:Text}): async [(Text, Trade.Refunds)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (refundsToSave.get(date)) {
        case null [];
        case (?u) { u };
    };
  };


  /*
  * 专栏储存信息
  */

  // 专栏储存信息
  private var featureToSave_s: [(Text, [(Text, Types.Feature)])] = [];
  private transient let featureToSave = HashMap.fromIter<Text, [(Text, Types.Feature)]>(featureToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func saveFeatureToSave({date:Text;dataList:[(Text, Types.Feature)]}):async () {
    if(Principal.equal(caller,contentCanister)){
        //判断该日期下是否已有存档
        switch (featureToSave.get(date)) {
            case null {
                //若无存档则直接新建存档
                featureToSave.put(date, dataList);
            };
            case (?u){
                //若存在存档则新建HashMap 重新赋值
                let data = HashMap.fromIter<Text, Types.Feature>(u.vals(), 0, Text.equal, Text.hash);
                for(user in dataList.vals()){
                    data.put(user);
                };
                featureToSave.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getFeature({date:Text}): async [(Text, Types.Feature)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (featureToSave.get(date)) {
        case null [];
        case (?u) { u };
    };
  };

  /*
  * 动态信息
  */

  // 动态信息
  private var postsToSave_s: [(Text, [(Text, Posts.Posts)])] = [];
  private transient let postsToSave = HashMap.fromIter<Text, [(Text, Posts.Posts)]>(postsToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func savePostsToSave({date:Text;dataList:[(Text, Posts.Posts)]}):async () {
    if(Principal.equal(caller,contentCanister)){
        //判断该日期下是否已有存档
        switch (postsToSave.get(date)) {
            case null {
                //若无存档则直接新建存档
                postsToSave.put(date, dataList);
            };
            case (?u){
                //若存在存档则新建HashMap 重新赋值
                let data = HashMap.fromIter<Text, Posts.Posts>(u.vals(), 0, Text.equal, Text.hash);
                for(user in dataList.vals()){
                    data.put(user);
                };
                postsToSave.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getPosts({date:Text}): async [(Text, Posts.Posts)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (postsToSave.get(date)) {
        case null [];
        case (?u) { u };
    };
  };
  
  // funded信息
  private var nftToSave_s: [(Text, [Types.NFT])] = [];
  private transient let nftToSave = HashMap.fromIter<Text, [Types.NFT]>(nftToSave_s.vals(), 0, Text.equal, Text.hash);

  public shared({ caller }) func saveNftToSave({date:Text;dataList:[Types.NFT]}):async () {   
    if(Principal.equal(caller,nftCanister)){
        //判断该日期下是否已有存档
        switch (nftToSave.get(date)) {
            case null {
                //若无存档则直接新建存档
                nftToSave.put(date, dataList);
            };
            case (_){
                //若存在存档则重新赋值
                nftToSave.put(date, dataList);
            };
        }
    };
  };


  /*
  * NFT 信息
  */
  // NFT 数据结构
  type NFT_Registry = {
    reg_id: Text;
    token_id: Nat; // NFT 的唯一标识符
    collection_id: Text;   // Collection 关联
    nft_canister: Principal;    // 对应的 NFT canister ID
    seller: Principal; // 卖家身份
    owner: Principal; // 当前拥有者身份
    price: Nat; // 用 ICRC Token 的最小单位
    currency: Types.Tokens; 
    created_at: Int; // 创建时间戳
    status: Types.Status; 
    expiration: ?Int; // 可选下架时间
    isActive:Bool;
  };

  // NFT 信息
  private var listedNFTs_s: [(Text, [(Text, NFT_Registry)])] = [];
  private transient let listedNFTs = HashMap.fromIter<Text, [(Text, NFT_Registry)]>(listedNFTs_s.vals(),0,Text.equal,Text.hash);

  public shared({ caller }) func saveNFTsToSave({date:Text;dataList:[(Text, NFT_Registry)]}):async () {
    if(Principal.equal(caller,contentCanister)){
        //判断该日期下是否已有存档
        switch (listedNFTs.get(date)) {
            case null {
                //若无存档则直接新建存档
                listedNFTs.put(date, dataList);
            };
            case (?u){
                //若存在存档则新建HashMap 重新赋值
                let data = HashMap.fromIter<Text, NFT_Registry>(u.vals(), 0, Text.equal, Text.hash);
                for(user in dataList.vals()){
                    data.put(user);
                };
                listedNFTs.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getNFTs({date:Text}): async [(Text, NFT_Registry)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (listedNFTs.get(date)) {
        case null [];
        case (?u) { u };
    };
  };
  
    // NFT 信息
  private var cryptoDiskToData_s: [(Text, [(Text, Types.CryptoDisk)])] = [];
  private transient let cryptoDiskToData = HashMap.fromIter<Text, [(Text, Types.CryptoDisk)]>(cryptoDiskToData_s.vals(),0,Text.equal,Text.hash);

  public shared({ caller }) func saveCryptoDiskToSave({date:Text;dataList:[(Text, Types.CryptoDisk)]}):async () {
    if(Principal.equal(caller,contentCanister)){
        //判断该日期下是否已有存档
        switch (cryptoDiskToData.get(date)) {
            case null {
                //若无存档则直接新建存档
                cryptoDiskToData.put(date, dataList);
            };
            case (?u){
                //若存在存档则新建HashMap 重新赋值
                let data = HashMap.fromIter<Text, Types.CryptoDisk>(u.vals(), 0, Text.equal, Text.hash);
                for(user in dataList.vals()){
                    data.put(user);
                };
                cryptoDiskToData.put(date, Iter.toArray(data.entries()));
            };
        }
    };
  };
 
  public query({ caller }) func getCryptoDisk({date:Text}): async [(Text, Types.CryptoDisk)] {
    assert (Principal.equal(caller, ownerAdmin));
    switch (cryptoDiskToData.get(date)) {
        case null [];
        case (?u) { u };
    };
  };



  //例:还原同步数据Canister
  public type SyncCanister = actor {
      syncData : shared ({dataList:[(Principal, User.User)]}) ->  async ();
  };
  let SyncCanister : SyncCanister = actor("yffxi-vqaaa-aaaak-qcrnq-cai");

  //例:还原该日期下用户存档 (!在该列表不大于2MB的情况下)
  public shared({ caller }) func recoverToSave({date:Text}):async () {
     assert (Principal.equal(caller, ownerAdmin));
    //判断该日期下是否已有存档
    switch (userToSave.get(date)) {
        case null {};
        case (?data){
            await SyncCanister.syncData({dataList=data});
        };
    }
  };
  

};