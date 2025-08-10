import Debug "mo:base/Debug";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Bool "mo:base/Bool";
import Order "mo:base/Order";
import Timer "mo:base/Timer";
import Blob "mo:base/Blob";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Float "mo:base/Float";
import Result "mo:base/Result";
import Error "mo:base/Error";
import Nat64 "mo:base/Nat64";
import Cycles "mo:base/ExperimentalCycles";
import TrieMap "mo:base/TrieMap";

import User "user";
import Item "item";
import Types "types";
import Trade "trade";
import Account "account";

actor this {

  /*
  * Storage Information
  */

  // User information
  private stable var userToData_s: [(Principal, User.User)] = [];
  private let userToData = HashMap.fromIter<Principal, User.User>(userToData_s.vals(), 0, Principal.equal, Principal.hash);
  // Follow information
  private stable var followToData_s: [(Principal, User.UserFollow)] = [];
  private let followToData = HashMap.fromIter<Principal, User.UserFollow>(followToData_s.vals(), 0, Principal.equal, Principal.hash);
  // Item information
  private stable var itemsToData_s: [(Text, Item.Items)] = [];
  private let itemsToData = HashMap.fromIter<Text, Item.Items>(itemsToData_s.vals(), 0, Text.equal, Text.hash);
  // File index storage
  private stable var fileStorageToData_s: [(Text, Types.FileStorage)] = [];
  private let fileStorageToData = HashMap.fromIter<Text, Types.FileStorage>(fileStorageToData_s.vals(), 0, Text.equal, Text.hash);

  private var fileToData = HashMap.fromIter<Text, Types.FilePath>([].vals(), 0, Text.equal, Text.hash);
   // User transaction information
  private stable var tradeToData_s: [(Text, Trade.Transaction)] = [];
  private let tradeToData = HashMap.fromIter<Text, Trade.Transaction>(tradeToData_s.vals(), 0, Text.equal, Text.hash);
  // User refund information
  private stable var refundsToData_s: [(Text, Trade.Refunds)] = [];
  private let refundsToData = HashMap.fromIter<Text, Trade.Refunds>(refundsToData_s.vals(), 0, Text.equal, Text.hash);

  // Transaction deduplication record
  private var transferToData = TrieMap.fromEntries<Text, TransferHash>([].vals(), Text.equal, Text.hash);
  public type TransferHash = {
    userID: Principal; // User
    transferID: Text; // Transaction ID
    state: Bool; // Transaction state
    time: Int; // Time
  };

  system func preupgrade() {
    Debug.print("Starting pre-upgrade hook...");
    userToData_s := Iter.toArray(userToData.entries());
    followToData_s := Iter.toArray(followToData.entries());
    itemsToData_s := Iter.toArray(itemsToData.entries());
    fileStorageToData_s := Iter.toArray(fileStorageToData.entries());
    tradeToData_s := Iter.toArray(tradeToData.entries());
    refundsToData_s := Iter.toArray(refundsToData.entries());
    Debug.print("pre-upgrade finished.");
  };

  system func postupgrade() {
    Debug.print("Starting post-upgrade hook...");
    userToData_s := [];
    followToData_s := [];
    itemsToData_s := [];
    fileStorageToData_s := [];
    tradeToData_s := [];
    refundsToData_s := [];
    Debug.print("post-upgrade finished.");
  };

  let ownerAdmin: Principal = Principal.fromText("");
  let featureAdmin: Principal = Principal.fromText("");
  let cyclesAddr: Principal = Principal.fromText("");
  let rewardCanister: Principal = Principal.fromText("pva7i-yqaaa-aaaak-qugpq-cai");
  let contentCanister: Principal = Principal.fromText("lyr3s-lqaaa-aaaak-qugvq-cai");
  let cryptoDiskCanister: Principal = Principal.fromText("ecvgk-vqaaa-aaaak-quhrq-cai");
  let nftCanister: Principal = Principal.fromText("24t7b-laaaa-aaaak-quf6q-cai");

  // Storage canister list
  let canisterList = HashMap.fromIter<Principal, Text>([].vals(), 0, Principal.equal, Principal.hash);

  // Sync API
  public type SaveCanisterApi = actor {
      saveUserToSave: shared ({date: Text; dataList: [(Principal, User.User)]}) -> async ();
      saveFollowToSave: shared ({date: Text; dataList: [(Principal, User.UserFollow)]}) -> async ();
      saveItemToSave : shared ({date:Text;dataList:[(Text, Item.Items)]}) -> async ();
      saveStoreToSave : shared ({date:Text;dataList:[(Text, Types.FileStorage)]}) -> async ();
      saveTradeToSave: shared ({date: Text; dataList: [(Text, Trade.Transaction)]}) -> async ();
      saveFundsToSave: shared ({date: Text; dataList: [(Text, Trade.Refunds)]}) -> async ();
  };

  public type CyclesCanisterApi = actor {
      monitorAndTopUp: shared ({canisterId: Principal; threshold: Nat; topUpAmount: Nat}) -> async ({status: Text; transferred: Nat; refunded: Nat});
      checkAndTopUpAllCanisters: shared ({list: [Principal]}) -> async ([(Principal, Nat, Nat)]);
      addCyclesRecord: shared ({ userID: Principal; amount: Int; operation: { #Add; #Sub }; memo: Text; balance: Int }) -> async ();
  };

  // Canister interactions
  let LedgerICP: Types.Ledger = actor("ryjl3-tyaaa-aaaaa-aaaba-cai");
  let LedgerCkBTC: Types.Ledger = actor("mxzaz-hqaaa-aaaar-qaada-cai");
  let TC: Types.CyclesCanister = actor("rkp4c-7iaaa-aaaaa-aaaca-cai");
  let SaveCanister: SaveCanisterApi = actor("emmm6-kaaaa-aaaak-qlnwa-cai");
  let CyclesCanister: CyclesCanisterApi = actor("j6jj7-caaaa-aaaak-qugyq-cai");

  /*
  * Admin Related
  */
  
  // Get file ID list
  public query({ caller }) func getfileToData(): async [(Text, Types.FilePath)] {
   assert(Principal.equal(caller, ownerAdmin));
    Iter.toArray(fileToData.entries())
  };
  
  // Verify item
  public shared({ caller }) func owItemVerified({itemID: Text; bool: Bool}): async () {
    assert(Principal.equal(caller, ownerAdmin));
    Item.updateItemVerified(itemsToData,itemID,bool);
  };

  // Set user type
  public shared({ caller }) func setUserType({userID: Principal; role: Types.UserRole}): async () {
    assert(Principal.equal(caller, ownerAdmin));
    User.upDateUserRole(userToData, userID, role);
  };

  // Set featured item
  public shared({ caller }) func setManageItem({itemID: Text; tags: ?[Text]; origin: ?Text; exposure: ?Int; isActive: ?Bool}): async () {
    assert(Principal.equal(caller, ownerAdmin));
    Item.manageItem(itemsToData,itemID,tags,origin,exposure,isActive);
  };

  // Clear all invalid file fragments
  public shared({ caller }) func deleteFileInvalid(): async () {
    assert(Principal.equal(caller, ownerAdmin));
    await deleteFileInvalidAll()
  };

  /*
  * Cycle Information
  */
  
  // Replenish canister cycles
  public shared({ caller }) func replenishCycles({canisterId: Principal;}): async ({status: Text; transferred: Nat; refunded: Nat}) {
    assert(Principal.equal(caller, featureAdmin));
    await CyclesCanister.monitorAndTopUp({
        canisterId;
        threshold = Types.cycles1T * 2;
        topUpAmount = Types.cycles1T;
      });
  };

  // Replenish all canister cycles
  public shared({ caller }) func replenishCyclesAll({list: [Principal];}): async ([(Principal, Nat, Nat)]) {
    assert(Principal.equal(caller, featureAdmin));
    await CyclesCanister.checkAndTopUpAllCanisters({list});
  };

  // Get cycles balance
  public func getCycleBalance(): async Nat {
    return Cycles.balance();
  };

  // Receive cycles
  public func wallet_receive(): async { accepted: Nat } {
    let available = Cycles.available();
    let accepted = Cycles.accept<system>(available);
    return { accepted = accepted };
  };

  // Get cycles price
  public shared func cyclesPrice(): async (Nat64) {
    let data = await TC.get_icp_xdr_conversion_rate();
    data.data.xdr_permyriad_per_icp;
  };

  // Add user cycles
  public shared({ caller }) func addUserCycles({amount: Nat}): async Result.Result<Nat64, Text> {
    let res = await LedgerICP.icrc1_transfer({
        memo = null;
        from_subaccount = ?Account.toSubaccount(caller);
        to = {
          owner = cyclesAddr;
          subaccount = null;
        };
        amount = amount - 10_000;
        fee = ?10_000;
        created_at_time = null;
    });
    
    switch (res) {
        case (#Ok(blockIndex)) {
            var cPrice = await cyclesPrice();
            cPrice := cPrice * Nat64.fromNat(amount);
            switch (userToData.get(caller)) {
              case null {};
              case (?u) { 
                User.upDateUserCycles(userToData, caller, u.cyclesBalance + Nat64.toNat(cPrice));
                // Add cycles record
                await CyclesCanister.addCyclesRecord({
                  userID = caller;
                  amount = Nat64.toNat(cPrice);
                  operation = #Add;
                  memo = "User recharge";
                  balance = u.cyclesBalance;
                });
              };
            };
            #ok(Nat64.fromNat(blockIndex))
        };
        case (#Err(other)) {
            throw Error.reject("Unexpected error: " # debug_show other);
        };
    }; 
  };

  /*
  * Basic Information
  */

  public shared func getTokenConfig(token: Types.Tokens): async { ledger: Types.Ledger; fee: Nat } {
    switch (token) {
      case (#ICP) { { ledger = LedgerICP; fee = 10000 } };
      case (#CKBTC) { { ledger = LedgerCkBTC; fee = 10 } };
    }
  };

  // Get deposit address
  public query({ caller }) func getDepositAddress(): async Text {
    let acc = Account.toAccount({
      subaccount = caller;
      owner = Principal.fromActor(this);
    });
    return Account.toText(acc);
  };

  // Get subaccount for caller
  public query({ caller }) func getSubaccountForCaller(): async Blob {
    Account.toSubaccount(caller);
  };

  // Withdraw to specified address
  public shared({ caller }) func withdrawICP({address: Text; price: Nat; token: Types.Tokens}): async Result.Result<Nat, Text> {  
    let tokens = await getTokenConfig(token);
    let res = await tokens.ledger.icrc1_transfer({
        memo = null;
        from_subaccount = ?Account.toSubaccount(caller);
        to = {
          owner = Principal.fromText(address);
          subaccount = null;
        };
        amount = price;
        fee = ?tokens.fee;
        created_at_time = null;
    });
    switch (res) {
        case (#Ok(blockIndex)) {
            #ok(blockIndex)
        };
        case (#Err(#InsufficientFunds { balance })) {
            #err("Insufficient balance, your balance cannot complete this transaction, balance:" # debug_show balance)
        };
        case (#Err(other)) {
            throw Error.reject("Unexpected error: " # debug_show other);
        };
    }; 
  };

  // Transfer token
  private func transferToken({from: Principal; to: Principal; price: Nat; token: Types.Tokens; refund: Bool}): async Result.Result<Nat, Text> {  
    let tokens = await getTokenConfig(token);
    var prices = price;
    if (refund) {
      if (price < tokens.fee) {
        return #err("The price is insufficient to cover the fee");
      };
      prices := price - tokens.fee;
    };
    let res = await tokens.ledger.icrc1_transfer({
        memo = null;
        from_subaccount = ?Account.toSubaccount(from);
        to = Account.toAccount({
          subaccount = to;
          owner = Principal.fromActor(this);
        });
        amount = prices;
        fee = ?tokens.fee;
        created_at_time = null;
    });
    switch (res) {
        case (#Ok(blockIndex)) {
            #ok(blockIndex)
        };
        case (#Err(#InsufficientFunds { balance })) {
            #err("Insufficient balance, your balance cannot complete this transaction, balance:" # debug_show balance)
        };
        case (#Err(other)) {
            throw Error.reject("Unexpected error: " # debug_show other);
        };
    }; 
  };

  // Transfer fee to public account
  private func transferFee({caller: Principal; amount: Nat; token: Types.Tokens}): async Result.Result<Nat, Text> {
    let tokens = await getTokenConfig(token);
    let res = await tokens.ledger.icrc1_transfer({
        memo = null;
        from_subaccount = ?Account.toSubaccount(caller);
        to = {
          owner = ownerAdmin;
          subaccount = null;
        };
        amount = amount;
        fee = ?tokens.fee;
        created_at_time = null;
    });
    switch (res) {
        case (#Ok(blockIndex)) {
            #ok(blockIndex)
        };
        case (#Err(#InsufficientFunds { balance })) {
            #err("Insufficient balance, your balance cannot complete this transaction, balance:" # debug_show balance)
        };
        case (#Err(other)) {
            throw Error.reject("Unexpected error: " # debug_show other);
        };
    }; 
  };

  /*
  * User Related
  */

  // Create user
  public shared({ caller }) func createUser({sha256ID: Text; name: Text}): async Result.Result<Bool, Text> {
   if (Principal.isAnonymous(caller) == false) {
      User.createUser(userToData, caller, sha256ID, name);
      #ok(true)
    } else {
      #err("Unable to set user information using anonymous identity, please refresh and try again")
    }
  };

  // Get user details
  public query({ caller }) func getUser(): async ?User.User {
   switch (userToData.get(caller)) {
      case null null;
      case (?u) { ?u };
    };
  };

  // Get user basic details
  public query func getUserBasic({ caller: Principal }): async ?Types.UserBasic {
   switch (userToData.get(caller)) {
      case null null;
      case (?u) { ?u };
    };
  };

  // Search user
  public query func searchUser({userName: ?Text}): async [Types.UserBasic] {
    let userList = Iter.toArray(userToData.entries());
    let list = switch (userName) {
        case (null) [];
        case (?u) {
          var lists = Buffer.Buffer<Types.UserBasic>(0);
         for((id,user) in userList.vals()){
            let upperText = Text.toUppercase(user.name);
            let upperPattern = Text.toUppercase(u);
            if(Text.contains(upperText, #text upperPattern)){
              lists.add(user);
            };
          };
          Buffer.toArray(lists);
        };
      };
    return list;
  };

  // Get user list by principal
  public query func getUserListPrincipal(): async [Principal] {
   var itemList = Buffer.Buffer<Principal>(0);
      for((id,item) in Iter.toArray(userToData.entries()).vals()){
        itemList.add(item.userID);
      };
      Buffer.toArray(itemList);
  };

  // Get user count
  public query func getUserSize(): async Nat {
    let list = Iter.toArray(userToData.entries());
    return list.size()
  };
  
  // Set user information
  public shared({ caller }) func setUserInfo({
    name: Text; desc: Text; address: Text; avatarURL: Text;
    backgroundURL: Text; twitterURL: Text; emailURL: Text
  }): async Result.Result<Bool, Text> {
    if (Principal.isAnonymous(caller) == false) {
      User.upDateUserDetail(userToData, caller, name, desc, address, avatarURL, backgroundURL, twitterURL, emailURL);
      #ok(true)
    } else {
      #err("Unable to set user information using anonymous identity, please refresh and try again")
    }
  };

  // Get principal by sha256ID
  public query func sha256IDToPrincipal({sha256ID: Text}): async ?Principal {
    let list = Iter.toArray(userToData.entries());
    let principal = Array.find<(Principal,User.User)>(list, func (id,x) = x.sha256ID == sha256ID);
    switch (principal) {
      case null null;
      case (?(id,_)) ?id;
    }
  };

  // Get sha256ID by principal
  public query func principalToSha256ID({user: Principal}): async Text {
    switch (userToData.get(user)) {
      case null "";
      case (?u) u.sha256ID;
    }
  };

  // Get user details by ID list
  public query func getUserIDList({userList: [Principal]}): async [Types.UserBasic] {
    let list = Buffer.Buffer<Types.UserBasic>(0);
    for (userID in userList.vals()) {
        switch (userToData.get(userID)) {
          case null {};
          case (?u) { 
            list.add(u)
           };
        };
    };
    Buffer.toArray(list);
  };

  /*
  * Item Related
  */

  // Create or update item
  public shared({ caller }) func createOrUpDateItem({
    itemID: Text; name: Text; website: Text; tags: [Text]; types: [Text];
    desc: Text; price: Nat; version: Text; logo: Text;coverImage: Text; contentImage: [Text];blockchain: Types.Blockchain; 
    currency: Types.Tokens;area: Types.Modules;
  }): async Result.Result<Bool, Text> {
    if (Principal.isAnonymous(caller) == false) {
      switch (itemsToData.get(itemID)) {
        case null {};
        case (?i) {             
          assert (Principal.equal(i.userID, caller));
        };
      };
      Item.createOrUpdateItem(itemsToData,itemID,name,caller,website,tags,types,desc,price,version,logo,coverImage,contentImage,blockchain,currency,area);
      switch (userToData.get(caller)) {
        case null {};
        case (?u) { 
          if (u.role == #Project) {
            Item.updateItemVerified(itemsToData,itemID,true);
          }
         };
      };
      #ok(true);
    } else {
      #err("Sorry, items cannot be posted/edited anonymously")
    }
  };

  // Get item details
  public query func getItem({itemID: Text}): async ?Item.Items {
   switch (itemsToData.get(itemID)) {
      case (null) null;
      case (?i) {
        if (i.isActive) {
          ?i
        } else {
          null
        }
      };
    }
  };

  // Get item details by ID list
  public query func getItemIDList({itemList: [Text]}): async [Item.Items] {
    let list = Buffer.Buffer<Item.Items>(0);
    for(itemID in itemList.vals()){
        switch (itemsToData.get(itemID)) {
          case (null) {};
          case (?i) {
            list.add(i)
          };
        };
    };
    Buffer.toArray(list);
  };

  // Get items with filtering and pagination
  public query func getItems({area:Types.Modules;types:Text;name:?Text;verified:Bool;page:Nat;pageSize:Nat}): async {
      listSize: Nat;
      dataList:[Item.Items];
      dataPage: Nat;
  } {
    var itemList = Buffer.Buffer<Item.Items>(0);
    for((id,item) in Iter.toArray(itemsToData.entries()).vals()){
      if(types=="All"){
        if(item.area == area and item.isActive and item.status == #Succes){
          if(verified and item.verified){
            itemList.add(item);
          }else if(verified==false and item.verified==false){
            itemList.add(item);
          }
        };
      }else{
        let typesList = Array.find<Text>(item.types, func x = Text.equal(x, types));
        if(typesList!= null and item.area == area and item.isActive and item.status == #Succes){
          if(verified and item.verified){
            itemList.add(item);
          }else if(verified==false and item.verified==false){
            itemList.add(item);
          }
        };
      }
    };
   
    let list = switch (name) {
      case (null) Buffer.toArray(itemList);
      case (?i) {
        let items = Buffer.Buffer<Item.Items>(0);
        for (item in itemList.vals()) {
            let upperText = Text.toUppercase(item.name);
            let upperPattern = Text.toUppercase(i);
          if (Text.contains(upperText, #text upperPattern)) {
            items.add(item);
          };
        };
        Buffer.toArray(items);
      }
    };

    let (pagedItems, total) = Types.paginate(list, page, pageSize);
    {listSize = total; dataList = pagedItems; dataPage = page;}
  };

  // Get recommended item list
  public query func getItemList({area:Types.Modules;types:{#Downloads;#Favorites;#Price;#CreationTime;#Rating;#Exposure};page:Nat;pageSize:Nat}): async {
      listSize: Nat;
      dataList:[Item.Items];
      dataPage: Nat;
  } {
    var list = Buffer.Buffer<Item.Items>(0);
    for((id,item) in Iter.toArray(itemsToData.entries()).vals()){
        if(area==#All){
          if(item.isActive and item.verified and item.status == #Succes){
            list.add(item);
          };
        }else{
          if(item.area == area and item.isActive and item.verified and item.status == #Succes){
            list.add(item);
          };
        }
    };

    var sortedItem:[Item.Items] = switch(types) {
        case (#Downloads) {
          Array.sort(Buffer.toArray(list), func (a1 : Item.Items, a2 : Item.Items) : Order.Order {
            if (a1.downloads < a2.downloads) {
              return #greater;
            } else if (a1.downloads > a2.downloads) {
              return #less;
            } else {
              return #equal;
            }
          });
        };
        case (#Favorites) {
            Array.sort(Buffer.toArray(list), func (a1 : Item.Items, a2 : Item.Items) : Order.Order {
            if (a1.favorites < a2.favorites) {
              return #greater;
            } else if (a1.favorites > a2.favorites) {
              return #less;
            } else {
              return #equal;
            }
          });
        };
        case (#Price) {
          var freeList = Buffer.Buffer<Item.Items>(0);
          for(work in list.vals()){
            if((work.price == 0)){
              freeList.add(work);
            };
          };
          Array.sort(Buffer.toArray(freeList), func (a1 : Item.Items, a2 : Item.Items) : Order.Order {
            if (a1.price < a2.price) {
              return #greater;
            } else if (a1.price > a2.price) {
              return #less;
            } else {
              return #equal;
            }
          });
        };
        case (#CreationTime) {
          Array.sort(Buffer.toArray(list), func (a1 : Item.Items, a2 : Item.Items) : Order.Order {
            if (a1.creationTime < a2.creationTime) {
              return #greater;
            } else if (a1.creationTime > a2.creationTime) {
              return #less;
            } else {
              return #equal;
            }
          });
        };
        case (#Rating) {
          Array.sort(Buffer.toArray(list), func (a1 : Item.Items, a2 : Item.Items) : Order.Order {
            if (a1.rating < a2.rating) {
              return #greater;
            } else if (a1.rating > a2.rating) {
              return #less;
            } else {
              return #equal;
            }
          });
        };
        case (#Exposure) {
          Array.sort(Buffer.toArray(list), func (a1 : Item.Items, a2 : Item.Items) : Order.Order {
            if (a1.exposure < a2.exposure) {
              return #greater;
            } else if (a1.exposure > a2.exposure) {
              return #less;
            } else {
              return #equal;
            }
          });
        };
      };

    let (pagedItems, total) = Types.paginate(sortedItem, page, pageSize);
    {
      listSize = total;
      dataList = pagedItems;
      dataPage = page;
    };
  };

  // Update item status
  public shared({ caller }) func userUpdateItemStatus({itemID: Text; available: Bool}): async Result.Result<Text, Text> {
    assert(Principal.isAnonymous(caller) == false);
    switch (itemsToData.get(itemID)) {
      case null {};
      case (?i) {             
        assert (Principal.equal(i.userID, caller));
      };
    };
    var goLive: Bool = false;
    if (available) {
      for((id,item) in Iter.toArray(fileStorageToData.entries()).vals()){
        if(item.itemID == itemID and item.status == #Succes){
          Item.updateItemStatus(itemsToData,itemID,#Succes);
          goLive := true;
        };
      };
      if (goLive) {
        #ok("Launch successful! Your project is now available to users.")
      } else {
        #err("Project launch failed. Please retry or check the project file status.")
      };
    } else {
      Item.updateItemStatus(itemsToData,itemID,#Failed);
      #ok("The project has been taken down")
    }
  };

  // Update item downloads
  public shared func uploadItemDownload({itemID: Text}): async () {
   switch (itemsToData.get(itemID)) {
      case (null) {};
      case (?i) {
       Item.updateItemDownloadsOrFavorites(itemsToData,itemID,?(i.downloads + 1),null,null,null);
      };
    }
  };

  // Update item rating
  public shared({ caller }) func uploadItemRating({itemID: Text; rating: Float}): async () {
    assert(Principal.equal(caller, contentCanister));
    switch (itemsToData.get(itemID)) { 
      case (null) {}; 
      case (_) {
        Item.updateItemDownloadsOrFavorites(itemsToData,itemID,null,null,null,?rating);
      };
    };
  };

  // Update item favorites
  public shared({ caller }) func uploadItemFavorites({itemID: Text; favorite: Int}): async () {
    assert(Principal.equal(caller, contentCanister));
    switch (itemsToData.get(itemID)) { 
      case (null) {}; 
      case (?i) {
        Item.updateItemDownloadsOrFavorites(itemsToData,itemID,null,?(i.favorites + favorite),null,null);
      };
    };
  };

  // Get item count
  public query func getItemQuantity(): async Nat {
      let list = Iter.toArray(itemsToData.entries());
      return list.size()
  };

  // Get total item downloads
  public query func getItemDownload(): async Int {
    let list = Iter.toArray(itemsToData.entries());
      var amount: Int = 0;
      for((id,item) in list.vals()){
       amount:=amount + item.downloads;
      };
    return amount
  };

  // Get item ID list
  public query func getItemsID(): async [{name: Text; value: Text}] {
    var itemList = Buffer.Buffer<{name: Text; value: Text}>(0);
    for((id,item) in Iter.toArray(itemsToData.entries()).vals()){
        if(item.isActive and item.verified){
            itemList.add({name=item.name;value=item.itemID});
        };
    };
    Buffer.toArray(itemList);
  };

  /*
  * User Publishing Related
  */

  // Get user item list
  public query func getUserItemList({caller: Principal; page: Nat; pageSize: Nat}): async {
      listSize: Nat;
      dataList:[Item.Items];
      dataPage: Nat;
  } {
    var itemList = Buffer.Buffer<Item.Items>(0);
    for((id,item) in Iter.toArray(itemsToData.entries()).vals()){
        if(Principal.equal(item.userID, caller) and item.isActive){
            itemList.add(item);
        };
    };
   
    let (pagedItems, total) = Types.paginate(Buffer.toArray(itemList), page, pageSize);
    {
      listSize = total;
      dataList = pagedItems;
      dataPage = page;
    }
  };

  // Get user item info
  public query({caller}) func getUserItemInfo(): async {downloads: Int; favorites: Int; rating: Float; size: Int} {
    var downloads: Int = 0;
    var favorites: Int = 0;
    var rating: Float = 0;
    var size: Int = 0;
    for((id,item) in Iter.toArray(itemsToData.entries()).vals()){
        if(Principal.equal(item.userID, caller) and item.isActive){
            downloads := downloads+item.downloads;
            favorites := favorites+item.favorites;
            rating := rating+item.rating;
            size:=size+1;
        };
    };
   {downloads; favorites; rating; size}
  };

  // Get user item count
  public query func getUserItemSize({caller: Principal}): async Nat {
    var itemList = Buffer.Buffer<Item.Items>(0);
    for((id,item) in Iter.toArray(itemsToData.entries()).vals()){
        if(Principal.equal(item.userID, caller) and item.isActive){
            itemList.add(item);
        };
    };
    return itemList.size();
  };

  /*
  * File Management Operations
  */

  // Get user item file size
  public query({ caller }) func getUserItemfileSize(): async Int {
    let list = Iter.toArray(fileStorageToData.entries());
    var fileSize: Int = 0;
      for((id,file) in list.vals()){
          if(Principal.equal(file.userID, caller)){
            fileSize := file.size + fileSize;
          };
      };
    return fileSize
  };

  // Get all file canister list
  public query func getAllFileCanister(): async [(Principal, Text)] {
    Iter.toArray(canisterList.entries())
  };

  // Set upload license
  public shared({ caller }) func setUploadLicense({itemID: Text; fileID: Text; name: Text; fileSize: Int;}): async Result.Result<Text, Text> {
    assert(Principal.isAnonymous(caller) == false);
    switch (itemsToData.get(itemID)) {
      case null {};
      case (?i) {             
        assert (Principal.equal(i.userID, caller));
      };
    };
    switch (userToData.get(caller)) {
      case null {
        #err("You have not registered yet.");
      };
      case (?u) {
        if (u.cyclesBalance > (fileSize * Types.cycles1MbFile)) {
          await CyclesCanister.addCyclesRecord({
            userID = caller;
            amount = fileSize * Types.cycles1MbFile;
            operation = #Sub;
            memo = "File upload";
            balance = u.cyclesBalance;
          });
          fileStorageToData.put(fileID, {
            fileID; // File ID
            itemID; // Item ID
            name; // File name
            size = fileSize; // File size
            fileType = #Item; // File type
            fileOrigin = #Upload; // File origin
            userID = caller; // Uploader
            upDateTime = 0; // Update time
            creationTime = Time.now(); // Creation time
            shardFile = []; // Shard storage location
            status = #Default; // Status
          });
          #ok(fileID);
        } else {
          #err("Your Cycle balance is insufficient for this upload.");
        }
      };
    };
  };

  // Query upload license and user cycles
  public query func queryLicense({fileID: Text; userID: Principal}): async Bool {
    switch (fileStorageToData.get(fileID)) {
      case null false;
      case (?s) {
        assert (Principal.equal(s.userID, userID));
        switch (userToData.get(userID)) {
          case null false;
          case (?u) { 
              if (u.cyclesBalance > (Types.cycles1MbFile * 10)) {
                true
              } else {
                false
              }
           };
        };
      };
    };
  };

  // Update file index
  public shared({ caller }) func uploadFileStore({userID: Principal; chunkID: Text; canister: Principal; fileID: Text}): async () {
      switch (canisterList.get(caller)) {
        case (null) {};
        case (_) {
          switch (userToData.get(userID)) {
            case null {};
            case (?u) {
              User.upDateUserCycles(userToData, userID, u.cyclesBalance - Types.cycles1MbFile);
              fileToData.put(chunkID, {
                fileID; // File ID
                chunkID; // Chunk ID
                canister; // File storage canister
              })
            };
          }
        };
      };
  };

  // Query temporary file list
  public query({ caller }) func queryFileToData({fileID: Text}): async ([{chunkID: Text; canister: Principal}]) {
      switch (fileStorageToData.get(fileID)) {
        case (null) {};
        case (?i) {
          if (Principal.equal(i.userID, caller)) {
          } else {
            assert(Principal.equal(caller, ownerAdmin));
          };
        };
      };
      var list = Buffer.Buffer<{chunkID: Text; canister: Principal}>(0);
      for((id,file) in Iter.toArray(fileToData.entries()).vals()){
          if(file.fileID==fileID){
            list.add({chunkID=file.chunkID;canister=file.canister})
          };
      };
      Buffer.toArray(list);
  };

  // Complete file upload
  public shared({ caller }) func uploadFileFinish({fileID: Text}): async () {
    switch (fileStorageToData.get(fileID)) {
      case (null) {};
      case (?s) {
        assert (Principal.equal(s.userID, caller));
        var list = Buffer.Buffer<{chunkID: Text; canister: Principal}>(0);
        for((id,file) in Iter.toArray(fileToData.entries()).vals()){
            if(file.fileID==fileID){
              list.add({chunkID=file.chunkID;canister=file.canister})
            };
        };
        fileStorageToData.put(fileID,{ s with upDateTime=Time.now();shardFile=Buffer.toArray(list)});
        if(list.size() >= s.size){
          fileStorageToData.put(fileID,{ s with upDateTime=Time.now();shardFile=Buffer.toArray(list);status=#Succes});
          Item.updateItemStatus(itemsToData,s.itemID,#Succes);
        };
      };
    }; 
  };

  // Delete file index/file
  public shared({ caller }) func deleteFile({itemID: Text; fileID: Text}): async () {
    switch (itemsToData.get(itemID)) {
      case null {};
      case (?i) {             
        assert (Principal.equal(i.userID, caller));
      };
    };
    fileStorageToData.delete(fileID);
    Item.updateItemStatus(itemsToData,itemID,#Failed);
    var time :Nat = 0;
    for((id,canister) in Iter.toArray(canisterList.entries()).vals()){
        let fileStore:Types.StoreCanister = actor(Principal.toText(id));
          time:=time+1;
        let _ = Timer.setTimer<system>(#nanoseconds(time*Types.millisecond*100), func() : async () {
          fileStore.deleteFile({fileID=fileID});
        });  
    };
  };

  // Periodically clear invalid/expired file fragments
  private func deleteFileInvalidAll(): async () {
  var list = HashMap.fromIter<Principal, [Text]>([].vals(), 0, Principal.equal, Principal.hash);
    for((id,item) in Iter.toArray(fileStorageToData.entries()).vals()){
        if(item.status == #Succes or item.creationTime + (10 * Types.minute) > Time.now()){
          switch (userToData.get(item.userID)) {
            case null {};
            case (?u) {
              if(u.cyclesBalance > (item.size*Types.cycles1Mb1DayFile)){
                User.upDateUserCycles(userToData,u.userID,u.cyclesBalance-(item.size*Types.cycles1Mb1DayFile));
                await CyclesCanister.addCyclesRecord({
                  userID = u.userID;
                  amount =item.size * Types.cycles1Mb1DayFile;
                  operation = #Sub;
                  memo = "File storage fee";
                  balance = u.cyclesBalance;
                });

                for(chunk in item.shardFile.vals()){
                  switch (list.get(chunk.canister)) {
                    case null {
                      list.put(chunk.canister,[chunk.chunkID]);
                    };
                    case (?c) {
                      let newArray = Array.append(c, [chunk.chunkID]);
                      list.put(chunk.canister,newArray);
                    };
                  };
                };
              }else{
                Item.updateItemStatus(itemsToData,item.itemID,#Failed);
              }
            }
          };
        };
    };
    var time :Nat = 0;
    for((id,canister) in Iter.toArray(list.entries()).vals()){
        let fileStore:Types.StoreCanister = actor(Principal.toText(id));
        time:=time+1;
        let _ = Timer.setTimer<system>(#nanoseconds(time*Types.millisecond*100), func() : async () {
          fileStore.clearFile({fileList=canister});
        });  
    };
    fileToData:= HashMap.fromIter<Text, Types.FilePath>([].vals(), 0, Text.equal, Text.hash);
  };

  // Start recurring timer to run cleanup task every 24 hours
  ignore Timer.recurringTimer<system>(#nanoseconds (Types.hour * 24), deleteFileInvalidAll);  

  // Get item file canister list
 public query func getItemFileCanister({itemID:Text}): async[Types.FileStorageBasic] {
    var list = Buffer.Buffer<Types.FileStorageBasic>(0);
    for((id,item) in Iter.toArray(fileStorageToData.entries()).vals()){
        if(item.itemID == itemID and item.fileOrigin != #Disk){
            list.add(item);
        };
    };
    Buffer.toArray(list);
  };

  // Get all user file list
  public query({ caller }) func getFileList(): async[Types.FileStorage] {
    var list = Buffer.Buffer<Types.FileStorage>(0);
    for((id,item) in Iter.toArray(fileStorageToData.entries()).vals()){
        if(Principal.equal(item.userID, caller) and item.fileOrigin != #Disk){
            list.add(item);
        };
    };
    Buffer.toArray(list);
  };

  // Get total item file size
  public query func getItemFileSize(): async Int {
    let list = Iter.toArray(fileStorageToData.entries());
    var fileSize :Int= 0;
      for((id,file) in list.vals()){
          fileSize := file.size + fileSize;
      };
    return fileSize
  };

  // Get file canister list
 public query({ caller }) func getFileCanisterList({fileID:Text;itemID:Text}): async ?Types.FileStorage {
    var isTrade:Bool = false;
    for((id,trade) in Iter.toArray(tradeToData.entries()).vals()){
        if(Principal.equal(trade.userID, caller) and trade.itemID == itemID and trade.isActive){
          isTrade:=true
        };
    };
    switch (itemsToData.get(itemID)) {
      case (null) {};
      case (?i) {
        if(Principal.equal(i.userID, caller) or i.price == 0 ){
          isTrade:=true;
        };
      };
    };

    if(isTrade){
      switch (fileStorageToData.get(fileID)) {
        case (null) null;
        case (?s) {
          if(s.fileOrigin != #Disk or Principal.equal(caller, s.userID)){
            ?s
          }else{
            null
          };
        }
      };
    }else{
      null
    }
  };

  /*
  * Transaction Operations (Purchase, Refund)
  */

  // Create transaction
  public shared({ caller }) func createTrade({itemID: Text; transactionID: Text}): async Result.Result<Text, Text> {
    assert(Principal.isAnonymous(caller) == false);
    let isTransfer: Bool = switch (transferToData.get(transactionID)) {
      case (null) { true };
      case (?t) {
        if (Time.now() > (t.time + Types.second * 10)) {
          true
        } else {
          false
        }
      }
    };
    if (isTransfer) {
      transferToData.put(transactionID, {userID = caller; transferID = transactionID; state = false; time = Time.now()});
      if ((await getIsItemTrade({userID = caller; itemID = itemID})) == null) {
        switch (itemsToData.get(itemID)) {
          case (null) {
            #err("Unexpected error: No purchase record")
          };
          case (?i) {
            if ((i.status == #Succes)) {
              if (i.price > 0) {
                var transferResult = await transferToken({from = caller; to = i.userID; price = i.price; token = i.currency; refund = false});
                switch (transferResult) {
                  case (#ok(_)) {
                    transferToData.delete(transactionID);
                    Trade.createTransaction(tradeToData, transactionID, caller, i.userID, i.itemID, i.price, i.currency);
                    #ok(transactionID);
                  };
                  case (#err(_)) { 
                    #err("Transaction failed, please check if your balance is sufficient")
                  };
                };
              } else {
                transferToData.delete(transactionID);
                Trade.createTransaction(tradeToData, transactionID, caller, i.userID, i.itemID, i.price, i.currency);
                #ok(transactionID);
              };
            } else {
              #err("The current product has been removed from the shelves")
            };
          };
        };
      } else {
          #err("You already own this work and cannot purchase it again")
      };
    } else {
      #err("Your request is too frequent. Please try again later.");
    }
  };

  // Check if item is purchased
  public query func getIsItemTrade({userID: Principal; itemID: Text}): async ?Text {
   let list = Iter.toArray(tradeToData.entries());
    var buy: ?Text = null;
    for((id,item) in list.vals()){
      if(Principal.equal(item.userID, userID) and (item.itemID == itemID) and item.isActive){
        buy := ?item.transactionID;
      }
   };
   return buy;
  };

  // Get trade info
  public query({caller}) func getTradeInfo(): async {refunded: Int; refunding: Int; size: Int; earnings: Int} {
    var refunded: Int = 0;
    var refunding: Int = 0;
    var earnings: Int = 0;
    var size: Int = 0;
    for((id,trade) in Iter.toArray(tradeToData.entries()).vals()){
        if(Principal.equal(trade.authorID, caller) ){
            size := size + 1;
        };
    };
    earnings := size;
    for((id,refund) in Iter.toArray(refundsToData.entries()).vals()){
        if(Principal.equal(refund.authorID, caller) ){
            if(refund.refund==#Default and refund.isActive){
               refunding := refunding+1;
               earnings := earnings-1;
            };
            if(refund.refund==#Succes and refund.isActive){
               refunded := refunded+1;
               earnings := earnings-1;
            };
        };
    };
   {refunded; refunding; size; earnings}
  };

  // Get trade details
  public query func getItemTradeInfo({transactionID: Text}): async ?Trade.Transaction {
   switch (tradeToData.get(transactionID)) {
      case null null;
      case (?u) {
        ?u
      };
    }
  };

  // Get user purchased item list
  public query({ caller }) func getItemTradeList({page: Nat; pageSize: Nat}): async {
      listSize: Nat;
      dataList:[(Text, Item.Items)];
      dataPage: Nat;
  } {
   let tradeList = Iter.toArray(tradeToData.entries());
   let itemList = Buffer.Buffer<(Text, Item.Items)>(0);
   for((id,trade) in tradeList.vals()){
      if(Principal.equal(trade.userID, caller) and trade.isActive){
        switch (itemsToData.get(trade.itemID)) {
          case null {};
          case (?i) {
            itemList.add(trade.transactionID,i);
          };
        }
      };
   };

    let (pagedItems, total) = Types.paginate(Buffer.toArray(itemList), page, pageSize);
    {
      listSize = total;
      dataList = pagedItems;
      dataPage = page;
    };
  };

  // Create refund
  public shared({ caller }) func createRefunds({transactionID: Text; refundReason: Text}): async Result.Result<Text, Text> {
      switch (tradeToData.get(transactionID)) {
        case (null) {
          #err("Unexpected error: No purchase record")
        };
        case (?t) {
          if (t.paymentAmount > 0) {
            if (t.creationTime + Types.hour * 48 > Time.now()) {
              if ((Principal.equal(t.userID, caller))) {
                switch (refundsToData.get(transactionID)) {
                  case (null) {
                    Trade.createRefunds(refundsToData, transactionID, t.userID, t.authorID, t.paymentAmount, refundReason);
                    #ok(transactionID)
                  };
                  case (_) {
                    #err("A refund has been initiated for this transaction")
                  };
                };
              } else {
                #err("The current product has been removed from the shelves")
              };
            } else {
              #err("The 48 hour refund period has exceeded")
            };
          } else {
            #err("The order payment amount is 0, so no refund is needed")
          };
        };
      };
  };

  // Get refund details
  public query func getRefundsInfo({transactionID: Text}): async ?Trade.Refunds {
   switch (refundsToData.get(transactionID)) {
      case null null;
      case (?u) {
        ?u
      };
    }
  };

  // Approve refund
  public shared({ caller }) func approveRefund({transactionID: Text; rejectRefundReason: Text; refund: Bool}): async Result.Result<Text, Text> {
    let isTransfer: Bool = switch (transferToData.get(transactionID)) {
      case (null) { true };
      case (?u) {
        if (Time.now() > (u.time + Types.second * 10)) {
          true
        } else {
          false
        }
      }
    };
    if (isTransfer) {
      transferToData.put(transactionID, {userID = caller; transferID = transactionID; state = false; time = Time.now()});
      switch (refundsToData.get(transactionID)) {
        case null {
          #err("Unexpected error: The refund information does not exist")
        };
        case (?r) {
          if ((Principal.equal(r.authorID, caller))) {
              if (r.refund == #Default and r.isActive == true) {
                switch (refund) { 
                    case (true) {
                      switch (tradeToData.get(transactionID)) { 
                          case (null) {
                            #err("No orders related to this order ID were obtained")
                          }; 
                          case (?t) {
                            var transferResult = await transferToken({from = r.authorID; to = r.userID; price = r.refundAmount; token = t.currency; refund = true});
                              switch (transferResult) {
                                case (#ok(_)) {
                                  transferToData.delete(transactionID);
                                  Trade.setRefundsStatus(refundsToData, transactionID, "Approve Refund", #Succes);
                                  Trade.setTradeIsActive(tradeToData, transactionID, false);     
                                  #ok(transactionID);
                                };
                                case (#err(_)) { 
                                  #err("Transaction failed, please check if your balance is sufficient")
                                };
                              };
                          }; 
                      };    
                    };
                    case (false) {
                      Trade.setRefundsStatus(refundsToData, transactionID, rejectRefundReason, #Failed);
                      #ok(transactionID);
                    };
                };
              } else {
                #err("Unexpected error: Refund status is abnormal")
              }
          } else {
            #err("Unexpected error: Insufficient permissions. You are not the publisher of this project")
          };
        };
      };
     } else {
      #err("Your request is too frequent. Please try again later.")
     }
  };

  // Refund list
  public query({ caller }) func getRefundList({status: Types.Status; page: Nat; pageSize: Nat}): async {
      listSize: Nat;
      dataList: [Trade.Refunds];
      dataPage: Nat;
  } {
   let refundsList = Iter.toArray(refundsToData.entries());
   let itemList = Buffer.Buffer<Trade.Refunds>(0);
   for((id,refund) in refundsList.vals()){
      if(Principal.equal(refund.authorID, caller) and refund.refund==status and refund.isActive){
        itemList.add(refund);
      };
   };
    let (pagedItems, total) = Types.paginate(Buffer.toArray(itemList), page, pageSize);
    {
      listSize = total;
      dataList = pagedItems;
      dataPage = page;
    };
  };

  // User refund list
  public query({ caller }) func getUserRefundList({status: Types.Status; page: Nat; pageSize: Nat}): async {
      listSize: Nat;
      dataList: [Trade.Refunds];
      dataPage: Nat;
  } {
   let refundsList = Iter.toArray(refundsToData.entries());
   let itemList = Buffer.Buffer<Trade.Refunds>(0);
   for((id,refund) in refundsList.vals()){
      if(Principal.equal(refund.userID, caller) and refund.refund==status and refund.isActive){
        itemList.add(refund);
      };
   };
    let (pagedItems, total) = Types.paginate(Buffer.toArray(itemList), page, pageSize);
    {
      listSize = total;
      dataList = pagedItems;
      dataPage = page;
    };
  };

  // Order list
  public query({ caller }) func getTradeList({page: Nat; pageSize: Nat}): async {
      listSize: Nat;
      dataList: [Trade.Transaction];
      dataPage: Nat;
  } {
   let tradeList = Iter.toArray(tradeToData.entries());
   let itemList = Buffer.Buffer<Trade.Transaction>(0);
   for((id,trade) in tradeList.vals()){
      if(Principal.equal(trade.authorID, caller) and trade.isActive){
        itemList.add(trade);
      };
   };
    let (pagedItems, total) = Types.paginate(Buffer.toArray(itemList), page, pageSize);
    {
      listSize = total;
      dataList = pagedItems;
      dataPage = page;
    };
  };

  // Manual refund after timeout
  public shared({ caller }) func userRefund({transactionID: Text}): async Result.Result<Text, Text> {
    assert(Principal.isAnonymous(caller) == false);
    let isTransfer: Bool = switch (transferToData.get(transactionID)) {
      case (null) { true };
      case (?u) {
        if (Time.now() > (u.time + Types.second * 10)) {
          true
        } else {
          false
        }
      }
    };
    if (isTransfer) {
      transferToData.put(transactionID, {userID = caller; transferID = transactionID; state = false; time = Time.now()});
      switch (refundsToData.get(transactionID)) {
        case null {
          #err("Unexpected error: The refund information does not exist")
        };
        case (?r) {
          if ((Principal.equal(r.userID, caller))) {
            if (r.refund == #Default and r.createTime + Types.hour * 48 < Time.now() and r.isActive == true) {
              switch (tradeToData.get(transactionID)) { 
                  case (null) {
                    #err("No orders related to this order ID were obtained")
                  }; 
                  case (?t) {
                    var transferResult = await transferToken({from = r.authorID; to = caller; price = r.refundAmount; token = t.currency; refund = true});
                      switch (transferResult) {
                        case (#ok(_)) {
                          transferToData.delete(transactionID);
                          Trade.setRefundsStatus(refundsToData, transactionID, "Approve Refund", #Succes);
                          #ok(transactionID);
                        };
                        case (#err(_)) { 
                          #err("Transaction failed, please check if your balance is sufficient")
                        };
                      };
                  }; 
              };   
            } else {
              #err("Unexpected error: Refund status is abnormal")
            }
          } else {
            #err("Unexpected error: Insufficient permissions. You are not the publisher of this project")
          };
        };
      };
     } else {
      #err("Your request is too frequent. Please try again later.")
     }
  };

  /*
  * Follow Users
  */

  // Get follow/follower count
  public query func getFollowToFollowers({userID: Principal}): async {follows: Nat; followers: Nat} {
   switch (followToData.get(userID)) {
      case null {
        return {follows = 0; followers = 0}
      };
      case (?f) {
        return {follows = f.follows.size(); followers = f.followers.size()}
      };
    };
  };

  // Get follow list
  public query({ caller }) func getFollow({userID: Principal}): async [User.UserFollowBasic] {
     switch (followToData.get(userID)) {
        case null {
          return []
        };
        case (?f) {
        var listFollows = Buffer.Buffer<User.UserFollowBasic>(0);
        for (user in f.follows.vals()) {
          if (Principal.equal(caller, userID)) {
            listFollows.add(user);
          } else {
            switch (followToData.get(caller)) {
              case null {};
              case (?cf) {
                let principal = Array.find<User.UserFollowBasic>(cf.follows, func x = x.userID == user.userID);
                switch (principal) {
                  case null {
                    listFollows.add({userID = user.userID; sha256ID = user.sha256ID; name = user.name; avatarURL = user.avatarURL; desc = user.desc; isFollow = false});
                  };
                  case (_) {
                    listFollows.add(user);
                  };
                }
              };
            };
          };
        };
        Buffer.toArray(listFollows)
      };
    };
  };

  // Get follower list
  public query({ caller }) func getFollower({userID: Principal}): async [User.UserFollowBasic] {
     switch (followToData.get(userID)) {
        case null {
          return []
        };
        case (?f) {
        var listFollowers = Buffer.Buffer<User.UserFollowBasic>(0);
        for (user in f.followers.vals()) {
          switch (followToData.get(caller)) {
            case null {};
            case (?cf) {
              let principal = Array.find<User.UserFollowBasic>(cf.follows, func x = x.userID == user.userID);
              switch (principal) {
                case null {
                  listFollowers.add({userID = user.userID; sha256ID = user.sha256ID; name = user.name; avatarURL = user.avatarURL; desc = user.desc; isFollow = false});
                };
                case (_) {
                  listFollowers.add(user);
                };
              }
            };
          };
        };
        Buffer.toArray(listFollowers)
      };
    };
  };

  // Check if user is followed
  public query({ caller }) func getFollowIsUser({userID: Principal}): async (Bool) {
     switch (followToData.get(caller)) {
        case null {false};
        case (?f) {
         let principal = Array.find<User.UserFollowBasic>(f.follows, func x = x.userID == userID);
          switch (principal) {
            case null false;
            case (_) true;
          }
      };
    };
  };

  // Follow user
  public shared({ caller }) func getFollowUser({userID: Principal}): async () {
    assert (Principal.equal(caller, userID) == false);
    switch (userToData.get(userID)) {
        case null {};
        case (?u) {
          switch (followToData.get(caller)) {
            case null {
              followToData.put(caller, {
                userID = caller; // User ID
                follows = [{userID = u.userID; sha256ID = u.sha256ID; name = u.name; avatarURL = u.avatarURL; desc = u.desc; isFollow = true}]; // Users I follow
                followers = []; // Users who follow me
              });     
            };
            case (?f) {
              followToData.put(caller, {
                userID = caller; // User ID
                follows = Array.append<User.UserFollowBasic>(f.follows, [{userID = u.userID; sha256ID = u.sha256ID; name = u.name; avatarURL = u.avatarURL; desc = u.desc; isFollow = true}]); // Users I follow
                followers = f.followers; // Users who follow me
              });
            };
          };
        };
    }; 
    switch (userToData.get(caller)) {
      case null {};
      case (?u) {
        switch (followToData.get(userID)) {
          case null {
            followToData.put(userID, {
              userID = userID; // User ID
              follows = []; // Users I follow
              followers = [{userID = u.userID; sha256ID = u.sha256ID; name = u.name; avatarURL = u.avatarURL; desc = u.desc; isFollow = true}]; // Users who follow me
            });
          };
          case (?f) {
            followToData.put(userID, {
              userID = userID; // User ID
              follows = f.follows; // Users I follow
              followers = Array.append<User.UserFollowBasic>(f.followers, [{userID = u.userID; sha256ID = u.sha256ID; name = u.name; avatarURL = u.avatarURL; desc = u.desc; isFollow = true}]); // Users who follow me
            });
          };
        };
      };
     }; 
  };

  // Unfollow user
  public shared({ caller }) func getCancelFollowUser({userID: Principal}): async () {
    switch (followToData.get(caller)) {
      case null {};
      case (?f) {
         followToData.put(caller, {
          userID = caller; // User ID
          follows = Array.filter<User.UserFollowBasic>(f.follows, func x = x.userID != userID); // Users I follow
          followers = f.followers; // Users who follow me
        });
      };
    };
    switch (followToData.get(userID)) {
      case null {};
      case (?f) {
        followToData.put(userID, {
          userID = userID; // User ID
          follows = f.follows; // Users I follow
          followers = Array.filter<User.UserFollowBasic>(f.followers, func x = x.userID != caller); // Users who follow me
        });
      };
    }
  };

  // Get recommended user list by follower count
  public query({ caller }) func getUserList(): async [User.UserFollowBasic] {
     var list = Array.sort(Iter.toArray(followToData.entries()), func (a1: (Principal, User.UserFollow), a2: (Principal, User.UserFollow)): Order.Order {
        if (a1.1.followers.size() <= a2.1.followers.size()) {
          return #greater;
        } else if (a1.1.followers.size() >= a2.1.followers.size()) {
          return #less;
        } else {
          return #equal;
        }
      });
    var listSize = 19;
    if (list.size() < listSize) {
      listSize := list.size()
    };
    let subArray = Array.subArray<(Principal, User.UserFollow)>(list, 0, listSize);
    var listFollowers = Buffer.Buffer<User.UserFollowBasic>(0);
      for((id,user) in subArray.vals()){
        switch (followToData.get(caller)) {
          case null {
            switch (userToData.get(id)) {
              case null {};
              case (?u) { 
                listFollowers.add({userID=u.userID;sha256ID=u.sha256ID;name=u.name;avatarURL=u.avatarURL;desc=u.desc;isFollow=false});
              };
            };
          };
          case (?cf) {
            let principal = Array.find<User.UserFollowBasic>(cf.follows, func x = x.userID == id);
            switch (principal) {
              case null {
                switch (userToData.get(id)) {
                  case null {};
                  case (?u) { 
                    listFollowers.add({userID=u.userID;sha256ID=u.sha256ID;name=u.name;avatarURL=u.avatarURL;desc=u.desc;isFollow=false});
                  };
                };
              };
              case (_) {
                switch (userToData.get(id)) {
                  case null {};
                  case (?u) { 
                    listFollowers.add({userID=u.userID;sha256ID=u.sha256ID;name=u.name;avatarURL=u.avatarURL;desc=u.desc;isFollow=true});
                  };
                };
              };
            }
          };
        };
      };
      Buffer.toArray(listFollowers)
  };

  /*
  * CryptoDisk Related
  */

  // Get file index
  public query({ caller }) func getCryptoDiskFile({fileID: Text}) : async ?Types.FileStorage {
    assert(Principal.equal(caller, cryptoDiskCanister));
    switch (fileStorageToData.get(fileID)) {
      case null null;
      case (?s) {?s};
    };
  };

  // Query item file list with pagination and search
  public query({caller}) func getItemFileCanisterPaged({
    itemID: Text;
    page: Nat;
    pageSize: Nat;
    keyword: ?Text;
  }): async {
    listSize: Nat;
    dataPage: Nat;
    dataList: [Types.FileStorage];
  } {
    let filtered = Buffer.Buffer<Types.FileStorage>(0);
    for ((_, file) in fileStorageToData.entries()) {
      if (file.itemID == itemID and Principal.equal(file.userID, caller)) {
        switch (keyword) {
          case (null) {
            filtered.add(file);
          };
          case (?k) {
            let nameLower = Text.toLowercase(file.name);
            let keywordLower = Text.toLowercase(k);
            if (Text.contains(nameLower, #text keywordLower)) {
              filtered.add(file);
            };
          };
        };
      };
    };
    let (paged, total) = Types.paginate(Buffer.toArray(filtered), page, pageSize);
    {
      listSize = total;
      dataPage = page;
      dataList = paged;
    };
  };

  // Set disk upload license
  public shared({ caller }) func setDiskUploadLicense({fileID:Text;name:Text;fileSize:Int;fileType:Types.FileType}): async Result.Result<Text, Text> {
    assert(Principal.isAnonymous(caller)==false);
    if((await getUserFileSizeByItem({itemID=Principal.toText(caller)})) > 5120){
      #err("You don't have enough upload space");
    }else{
          switch (itemsToData.get(Principal.toText(caller))) {
      case null {
        Item.createOrUpdateItem(itemsToData,Principal.toText(caller),"Crypto Disk",caller,"",[],[],"",0,"1.0","","",[],#InternetComputer,#ICP,#Disk);  
        Item.manageItem(itemsToData,Principal.toText(caller),null,null,null,?false);
      };
      case (?i) {             
        assert (Principal.equal(i.userID, caller));
      };
    };
    switch (userToData.get(caller)) {
      case null {
        #err("You have not registered yet.");
      };
      case (?u) {
        if (u.cyclesBalance > (fileSize * Types.cycles1MbFile)) {
          await CyclesCanister.addCyclesRecord({
            userID = caller;
            amount = fileSize * Types.cycles1MbFile;
            operation = #Sub;
            memo = "Crypto Disk upload";
            balance = u.cyclesBalance;
          });
          fileStorageToData.put(fileID, {
            fileID; // File ID
            itemID = Principal.toText(caller); // Disk space ID
            name; // File name
            size = fileSize; // File size
            fileType; // File type
            fileOrigin = #Disk; // File origin
            userID = caller; // Uploader
            upDateTime = 0; // Update time
            creationTime = Time.now(); // Creation time
            shardFile = []; // Shard storage location
            status = #Default; // Status
          });
          #ok(fileID);
        } else {
          #err("Your Cycle balance is insufficient for this upload.");
        }
      };
    };
    };
  };
  
  // Count file type stats
  public shared query ({ caller }) func getUserFileTypeStatsByItem({ itemID: Text }): async {photos: Nat; documents: Nat; file: Nat; videos: Nat; apps: Nat; others: Nat;} {
    var photos = 0;
    var documents = 0;
    var file = 0;
    var videos = 0;
    var apps = 0;
    var others = 0;
    for ((_, s) in fileStorageToData.entries()) {
      if (s.itemID == itemID and Principal.equal(s.userID, caller)) {
        switch (s.fileType) {
          case (#Photos)    { photos += 1 };
          case (#Documents) { documents += 1 };
          case (#File)      { file += 1 };
          case (#Videos)    { videos += 1 };
          case (#Apps)      { apps += 1 };
          case (#Others)    { others += 1 };
          case (#Item)      {  };
        };
      };
    };
    {photos; documents; file; videos; apps; others;}
  };

  // Get total file size for user item
  public shared query ({ caller }) func getUserFileSizeByItem({ itemID: Text }): async Int {
    var totalSize: Int = 0;
    for ((_, s) in fileStorageToData.entries()) {
      if (s.itemID == itemID and Principal.equal(s.userID, caller)) {
        totalSize += s.size;
      };
    };
    totalSize
  };

  /*
  * NFT Transaction
  */

  // Create NFT transaction
  public shared({ caller }) func createNftTrade({transactionID: Text; from: Principal; to: Principal; price: Nat; token: Types.Tokens; royalty: Nat; creator: Principal}): async Result.Result<Text, Text> {
    assert(Principal.equal(caller, nftCanister));
    let isTransfer: Bool = switch (transferToData.get(transactionID)) {
      case (null) { true };
      case (?t) {
        if (Time.now() > (t.time + Types.second * 10)) {
          true
        } else {
          false
        }
      }
    };
    if (isTransfer) {
        var transfer_price = price;
        if (royalty > 0) {
          transfer_price := (price * (100 - royalty)) / 100;
        };
        var transferResult = await transferToken({from; to; price = transfer_price; token; refund = false});
        switch (transferResult) {
          case (#ok(_)) {
            #ok(transactionID);
          };
          case (#err(_)) { 
            #err("Transaction failed, please check if your balance is sufficient")
          };
        };
    } else {
      #err("Your request is too frequent. Please try again later.");
    }
  };

  /*
  * Data Backup
  */

  // Backup all data
  private func saveAllData(): async () {
    let date = Int.toText(Time.now() / Types.second);
    await Types.backupData({data = Iter.toArray(userToData.entries()); chunkSize = 1000; date;
    saveFunc = func (d: Text, dataList: [(Principal, User.User)]): async () { await SaveCanister.saveUserToSave({ date = d; dataList })}});
    await Types.backupData({data=Iter.toArray(itemsToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Item.Items)]) : async () { await SaveCanister.saveItemToSave({ date = d; dataList })}});
    await Types.backupData({data = Iter.toArray(followToData.entries()); chunkSize = 1000; date;
    saveFunc = func (d: Text, dataList: [(Principal, User.UserFollow)]): async () { await SaveCanister.saveFollowToSave({ date = d; dataList })}});
    await Types.backupData({data=Iter.toArray(fileStorageToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Types.FileStorage)]) : async () { await SaveCanister.saveStoreToSave({ date = d; dataList })}});
    await Types.backupData({data = Iter.toArray(tradeToData.entries()); chunkSize = 1000; date;
    saveFunc = func (d: Text, dataList: [(Text, Trade.Transaction)]): async () { await SaveCanister.saveTradeToSave({ date = d; dataList })}});
    await Types.backupData({data = Iter.toArray(refundsToData.entries()); chunkSize = 1000; date;
    saveFunc = func (d: Text, dataList: [(Text, Trade.Refunds)]): async () { await SaveCanister.saveFundsToSave({ date = d; dataList })}});
  };

  ignore Timer.recurringTimer<system>(#seconds 604800, saveAllData);

  // Manual data backup
  public shared({ caller }) func setSaveAllData({date:Text}): async () {
    assert(Principal.equal(caller,ownerAdmin));
    await Types.backupData({data=Iter.toArray(userToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Principal, User.User)]) : async () { await SaveCanister.saveUserToSave({ date = d; dataList })}});
    await Types.backupData({data=Iter.toArray(itemsToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Item.Items)]) : async () { await SaveCanister.saveItemToSave({ date = d; dataList })}});
    await Types.backupData({data=Iter.toArray(followToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Principal, User.UserFollow)]) : async () { await SaveCanister.saveFollowToSave({ date = d; dataList })}});
    await Types.backupData({data=Iter.toArray(fileStorageToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Types.FileStorage)]) : async () { await SaveCanister.saveStoreToSave({ date = d; dataList })}});    
    await Types.backupData({data=Iter.toArray(tradeToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Trade.Transaction)]) : async () { await SaveCanister.saveTradeToSave({ date = d; dataList })}});
    await Types.backupData({data=Iter.toArray(refundsToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Trade.Refunds)]) : async () { await SaveCanister.saveFundsToSave({ date = d; dataList })}});
  };
  

  /*
  * redeemCode
  */

  //Cycles
  public shared({ caller }) func addCyclesRedeemCode({userID:Principal}): async (Bool) {
    assert(Principal.equal(caller,rewardCanister));
      switch (userToData.get(userID)) {
        case null {false};
        case (?u) { 
          User.upDateUserCycles(userToData,userID,u.cyclesBalance + Types.cycles1T*5);
          await CyclesCanister.addCyclesRecord({
              userID;
              amount = Types.cycles1T*5;
              operation = #Add;
              memo = "Redeem Code";
              balance = u.cyclesBalance;
            });
          true
        };
      };
  };
};
