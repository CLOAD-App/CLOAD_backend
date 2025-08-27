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

persistent actor this{

  /*
  * 储存信息
  */

  // 用户信息
  private var userToData_s: [(Principal, User.User)] = [];
  private transient let userToData = HashMap.fromIter<Principal, User.User>(userToData_s.vals(), 0, Principal.equal, Principal.hash);
  // 关注信息
  private var followToData_s: [(Principal, User.UserFollow)] = [];
  private transient let followToData = HashMap.fromIter<Principal, User.UserFollow>(followToData_s.vals(), 0, Principal.equal, Principal.hash);
  // 项目信息
  private var itemsToData_s: [(Text, Item.Items)] = [];
  private transient let itemsToData = HashMap.fromIter<Text, Item.Items>(itemsToData_s.vals(), 0, Text.equal, Text.hash);

  // 文件索引存储
  private var fileStorageToData_s: [(Text, Types.FileStorage)] = [];
  private transient let fileStorageToData = HashMap.fromIter<Text, Types.FileStorage>(fileStorageToData_s.vals(), 0, Text.equal, Text.hash);

  private transient var fileToData = HashMap.fromIter<Text, Types.FilePath>([].vals(), 0, Text.equal, Text.hash);
  // 用户交易信息
  private var tradeToData_s: [(Text, Trade.Transaction)] = [];
  private transient let tradeToData = HashMap.fromIter<Text, Trade.Transaction>(tradeToData_s.vals(), 0, Text.equal, Text.hash);
  // 用户退款信息
  private var refundsToData_s: [(Text, Trade.Refunds)] = [];
  private transient let refundsToData = HashMap.fromIter<Text, Trade.Refunds>(refundsToData_s.vals(), 0, Text.equal, Text.hash);

  //交易防止重复记录
  private transient var transferToData = TrieMap.fromEntries<Text, TransferHash>([].vals(), Text.equal, Text.hash);
  public type TransferHash = {
    userID: Principal;//用户
    transferID:Text; //交易ID
    state: Bool; //交易状态
    time: Int;//时间
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

  transient let ownerAdmin :Principal = Principal.fromText("cfklm-6bmf5-bovci-hk76c-rue3p-axnze-w2tjc-vpfdk-wppgd-xj2yv-2qe");
  transient let featureAdmin :Principal = Principal.fromText("uwvp7-5unl6-4dyas-6jbow-q4uqv-3g7i7-pyigh-qabzl-vixut-mbsiu-kqe");
  transient let cyclesAddr :Principal = Principal.fromText("an2fu-wmt2w-7fhvx-2g6qp-pq5pc-gdxu3-jfcr5-epiid-qhdzc-xnv3a-mae");

  transient let rewardCanister :Principal = Principal.fromText("pva7i-yqaaa-aaaak-qugpq-cai");
  transient let contentCanister :Principal = Principal.fromText("lyr3s-lqaaa-aaaak-qugvq-cai");
  transient let cryptoDiskCanister :Principal = Principal.fromText("ecvgk-vqaaa-aaaak-quhrq-cai");
  transient let nftCanister :Principal = Principal.fromText("24t7b-laaaa-aaaak-quf6q-cai");

  //储存canister列表
  transient let canisterList = HashMap.fromIter<Principal, Text>([
    (Principal.fromText("uxnnd-rqaaa-aaaag-ace5a-cai"),"fileCanister"),
    (Principal.fromText("4p5dy-miaaa-aaaam-ab2oa-cai"),"fileCanister2"),
    (Principal.fromText("svxfy-yqaaa-aaaap-abuga-cai"),"fileCanister3"),
    (Principal.fromText("3dl5t-uaaaa-aaaag-acfya-cai"),"fileCanister4"),
    (Principal.fromText("hpr35-caaaa-aaaap-qb5iq-cai"),"fileCanister5"),
    (Principal.fromText("rxcyh-iaaaa-aaaap-abuna-cai"),"fileCanister6"),
    (Principal.fromText("q6pid-uqaaa-aaaam-ab3aq-cai"),"fileCanister7"),
    (Principal.fromText("rqd6t-fyaaa-aaaap-abunq-cai"),"fileCanister8"),
    (Principal.fromText("k2t4j-ziaaa-aaaan-qlaea-cai"),"fileCanister9"),
    (Principal.fromText("g63fc-2iaaa-aaaap-qb5na-cai"),"fileCanister10"),
    (Principal.fromText("o5sb7-liaaa-aaaak-qczfq-cai"),"fileCanister11"),
    (Principal.fromText("g2us3-2iaaa-aaaak-qcytq-cai"),"fileCanister12"),
    (Principal.fromText("3qqsr-qiaaa-aaaak-afifa-cai"),"fileCanister13"),
    (Principal.fromText("3kyd7-hqaaa-aaaap-abvua-cai"),"fileCanister14"),
    (Principal.fromText("3nzfl-kiaaa-aaaap-abvuq-cai"),"fileCanister15"),
    (Principal.fromText("fkhy5-giaaa-aaaak-qcy3q-cai"),"fileCanister16"),
    (Principal.fromText("ehj4t-jaaaa-aaaak-qcy4a-cai"),"fileCanister17"),
    (Principal.fromText("eai2h-eyaaa-aaaak-qcy4q-cai"),"fileCanister18"),
    (Principal.fromText("ejlr3-sqaaa-aaaak-qcy5a-cai"),"fileCanister19"),
    (Principal.fromText("eokxp-7iaaa-aaaak-qcy5q-cai"),"fileCanister20"),
    (Principal.fromText("siaw4-kaaaa-aaaap-qb6yq-cai"), "fileCanister21"),
    (Principal.fromText("txmhs-uiaaa-aaaal-qdeeq-cai"), "fileCanister22"),
    (Principal.fromText("virj5-kaaaa-aaaal-adomq-cai"), "fileCanister23"),
    (Principal.fromText("jcnx3-maaaa-aaaap-abwva-cai"), "fileCanister24"),
    (Principal.fromText("t6pmo-caaaa-aaaal-qdefa-cai"), "fileCanister25"),
    (Principal.fromText("r6uyh-yqaaa-aaaam-ab43a-cai"), "fileCanister26"),
    (Principal.fromText("qduyu-vyaaa-aaaak-qc3kq-cai"), "fileCanister27"),
    (Principal.fromText("qkxti-dqaaa-aaaak-qc3la-cai"), "fileCanister28"),
    (Principal.fromText("qzuhz-xyaaa-aaaan-qlr3q-cai"), "fileCanister29"),
    (Principal.fromText("euh6p-caaaa-aaaag-qc6fa-cai"), "fileCanister30"),
    (Principal.fromText("67nfn-bqaaa-aaaak-qlqgq-cai"), "fileCanister31"),
    (Principal.fromText("wpraf-gqaaa-aaaag-aci6a-cai"), "fileCanister32"),
    (Principal.fromText("sbd5a-4iaaa-aaaap-qb6za-cai"), "fileCanister33"),
    (Principal.fromText("egbjw-oqaaa-aaaag-qc6ga-cai"), "fileCanister34"),
    (Principal.fromText("rzv6t-viaaa-aaaam-ab43q-cai"), "fileCanister35"),
    (Principal.fromText("fjxno-daaaa-aaaak-afkkq-cai"), "fileCanister36"),
    (Principal.fromText("sgc3u-rqaaa-aaaap-qb6zq-cai"), "fileCanister37"),
    (Principal.fromText("ebapc-diaaa-aaaag-qc6gq-cai"), "fileCanister38"),
    (Principal.fromText("jfmrp-byaaa-aaaap-abwvq-cai"), "fileCanister39"),
    (Principal.fromText("faugs-viaaa-aaaak-afkla-cai"), "fileCanister40")
  ].vals(), 0, Principal.equal, Principal.hash);


  //同步
  public type SaveCanisterApi = actor {
      saveUserToSave : shared ({date:Text;dataList:[(Principal, User.User)]}) -> async ();
      saveFollowToSave : shared ({date:Text;dataList:[(Principal, User.UserFollow)]}) -> async ();
      saveItemToSave : shared ({date:Text;dataList:[(Text, Item.Items)]}) -> async ();
      saveStoreToSave : shared ({date:Text;dataList:[(Text, Types.FileStorage)]}) -> async ();
      saveTradeToSave : shared ({date:Text;dataList:[(Text, Trade.Transaction)]}) -> async ();
      saveFundsToSave : shared ({date:Text;dataList:[(Text, Trade.Refunds)]}) -> async ();
  };

  public type CyclesCanisterApi = actor {
      monitorAndTopUp : shared ({canisterId: Principal; threshold: Nat; topUpAmount: Nat}) -> async ({status: Text;transferred: Nat;refunded: Nat  });
      checkAndTopUpAllCanisters : shared ({list: [Principal]}) -> async ([(Principal, Nat, Nat)]);
      addCyclesRecord: shared ({ userID: Principal; amount: Int; operation: { #Add; #Sub }; memo: Text;balance:Int }) -> async ();
  };

  //Canister交互
  transient let LedgerICP : Types.Ledger = actor("ryjl3-tyaaa-aaaaa-aaaba-cai");
  transient let LedgerCkBTC : Types.Ledger = actor("mxzaz-hqaaa-aaaar-qaada-cai");
  transient let TC : Types.CyclesCanister = actor("rkp4c-7iaaa-aaaaa-aaaca-cai");
  transient let SaveCanister : SaveCanisterApi = actor("emmm6-kaaaa-aaaak-qlnwa-cai");
  transient let CyclesCanister : CyclesCanisterApi = actor("j6jj7-caaaa-aaaak-qugyq-cai");


  /*
  * 管理员相关
  */
  
  //获取项目文件ID列表
  public query({ caller }) func getfileToData(): async [(Text, Types.FilePath)] {
   assert(Principal.equal(caller,ownerAdmin));
    Iter.toArray(fileToData.entries())
  };
  
  //认证项目
  public shared({ caller }) func owItemVerified({itemID:Text;bool:Bool}):async () {
    assert(Principal.equal(caller,ownerAdmin));
    Item.updateItemVerified(itemsToData,itemID,bool);
  };

  //修改用户类型
  public shared({ caller }) func setUserType({userID:Principal;role:Types.UserRole}):async () {
    assert(Principal.equal(caller,ownerAdmin));
    User.upDateUserRole(userToData,userID,role);
  };

  //设置推荐项目
  public shared({ caller }) func setManageItem({itemID: Text; tags:?[Text]; origin: ?Text ;exposure: ?Int;}):async () {
    assert(Principal.equal(caller,ownerAdmin));
    Item.manageItem(itemsToData,itemID,tags,origin,exposure,null);
  };

  //清理所有失效碎片文件
  public shared({ caller }) func deleteFileInvalid(): async () {
    assert(Principal.equal(caller,ownerAdmin));
    await deleteFileInvalidAll()
  };

  
  /*
  * Cycle信息
  */
  
  //补充容器Cycles
  public shared({ caller }) func replenishCycles({canisterId:Principal;}):async ({status: Text;transferred: Nat;refunded: Nat  }) {
    assert(Principal.equal(caller,featureAdmin));
    await CyclesCanister.monitorAndTopUp({
        canisterId;
        threshold = Types.cycles1T*2;
        topUpAmount = Types.cycles1T;
      });
  };

  //补充容器Cycles
  public shared({ caller }) func replenishCyclesAll({list:[Principal];}):async ([(Principal, Nat, Nat)]) {
    assert(Principal.equal(caller,featureAdmin));
    await CyclesCanister.checkAndTopUpAllCanisters({list});
  };

  //获取Cycles余额
  public func getCycleBalance() : async Nat {
    return Cycles.balance();
  };

  // 接收cycles的函数
  public func wallet_receive() : async { accepted: Nat } {
    let available = Cycles.available();
    let accepted = Cycles.accept<system>(available);
    return { accepted = accepted };
  };

  //获取cycles价格
  public shared func cyclesPrice(): async (Nat64) {
  let data = await TC.get_icp_xdr_conversion_rate();
    data.data.xdr_permyriad_per_icp;
  };

  //添加用户充值Cycles
  public shared({ caller }) func addUserCycles({amount:Nat}):  async Result.Result<Nat64, Text> {
    if (amount <= 10_000) {
      return #err("Amount too small");
    };
    let res = await LedgerICP.icrc1_transfer({
        memo = null;
        from_subaccount = ?Account.toSubaccount(caller);
        to = {
          owner = cyclesAddr;
          subaccount = null;
        };
        amount = amount-10_000;
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
                User.upDateUserCycles(userToData,caller,u.cyclesBalance + Nat64.toNat(cPrice));
                //添加Cycles记录
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
  * 基本信息
  */

  public shared func getTokenConfig(token: Types.Tokens) : async { ledger: Types.Ledger; fee: Nat } {
    switch (token) {
      case (#ICP) { { ledger = LedgerICP; fee = 10000 } };
      case (#CKBTC) { { ledger = LedgerCkBTC; fee = 10 } };
      // 增加其他交易对
    }
  };

  //获取充值地址
  public query({ caller }) func getDepositAddress():async Text {
    let acc = Account.toAccount({
      subaccount = caller;
      owner = Principal.fromActor(this);
    });
    return Account.toText(acc);
  };

  //获取子账户地址
  public query({ caller }) func getSubaccountForCaller() : async Blob {
    Account.toSubaccount(caller);
  };

  //提款到指定地址
  public shared({ caller }) func withdrawICP ({to:Types.IcrcAccount;price:Nat;token:Types.Tokens}) : async Result.Result<Nat, Text> {  
    assert(not Principal.isAnonymous(caller));

    let tokens = await getTokenConfig(token);
    if (price == 0) return #err("Amount must be > 0");
    if (price <= tokens.fee) return #err("Amount must be greater than fee");

    let res = await tokens.ledger.icrc1_transfer({
        memo = null;
        from_subaccount = ?Account.toSubaccount(caller);
        to = to;
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

  //交易转账
  private func transferToken ({from:Principal;to:Principal;price:Nat;token:Types.Tokens;refund:Bool}) : async Result.Result<Nat, Text> {  
    let tokens = await getTokenConfig(token);
    var prices = price;
    if(refund){
      if (price < tokens.fee) {
        return #err("The price is insufficient to cover the fee");
      };
      prices:= price - tokens.fee;
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

  //手续费交易到公户--仅通过方法调用
  private func transferFee ({caller: Principal;amount:Nat;token:Types.Tokens}) : async Result.Result<Nat, Text> {
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
  * 用户相关
  */


  //创建用户
  public shared({ caller }) func createUser({name:Text}):async Result.Result<Bool, Text> {
   if (Principal.isAnonymous(caller)==false){
      let sha256ID = await Types.genRandomSha256Id();
      User.createUser(userToData,caller,sha256ID,name);
      #ok(true);
    }else{
      #err("Unable to set user information using anonymous identity, please refresh and try again")
    }
  };

  //获取用户详情
  public query({ caller }) func getUser(): async ?User.User {
   switch (userToData.get(caller)) {
      case null null;
      case (?u) { ?u };
    };
  };

  //获取用户详情
  public query func getUserBasic({ caller:Principal }): async ?Types.UserBasic {
   switch (userToData.get(caller)) {
      case null null;
      case (?u) { ?u };
    };
  };

  // 搜索用户
  public query func searchUser({userName: ?Text}): async [Types.UserBasic] {
    let userList = Iter.toArray(userToData.entries());
    //筛选模糊搜索的用户
    let list =  switch(userName) {
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

  //获取用户列表
  public query func getUserListPrincipal(): async [Principal] {
   var itemList = Buffer.Buffer<Principal>(0);
      for((id,item) in Iter.toArray(userToData.entries()).vals()){
        itemList.add(item.userID);
      };
      Buffer.toArray(itemList);
  };

  //获取用户数量
  public query func getUserSize(): async Nat {
    let list = Iter.toArray(userToData.entries());
    return list.size()
  };
  
  
  //设置用户信息
  public shared({ caller }) func setUserInfo({
    name:Text;desc:Text;address:Text;avatarURL:Text;
    backgroundURL:Text;twitterURL:Text;emailURL:Text
  }):async Result.Result<Bool, Text> {
    if (Principal.isAnonymous(caller)==false){
      User.upDateUserDetail(userToData,caller,name,desc,address,avatarURL,backgroundURL,twitterURL,emailURL);
      #ok(true)
    }else{
      #err("Unable to set user information using anonymous identity, please refresh and try again")
    }
  };

  //通过sha256ID获取Principal
  public query func sha256IDToPrincipal({sha256ID: Text}): async ?Principal {
    let list = Iter.toArray(userToData.entries());
    let principal = Array.find<(Principal,User.User)>(list, func (id,x) = x.sha256ID == sha256ID);
    switch (principal) {
      case null null;
      case (?(id,_)) ?id;
    }
  };

  //通过Principal获取sha256ID
  public query func principalToSha256ID({user: Principal}): async Text {
    switch (userToData.get(user)) {
      case null "";
      case (?u) u.sha256ID;
    }
  };

  //批量获取用户详情
  public query func getUserIDList({userList: [Principal]}): async [Types.UserBasic] {
    let list = Buffer.Buffer<Types.UserBasic>(0);
    for(userID in userList.vals()){
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
  * 项目相关
  */

  //创建/更新项目信息 /更新项目状态
  public shared({ caller }) func createOrUpDateItem({
    itemID: Text;name: Text; website: Text;tags: [Text];types: [Text];
    desc: Text; price: Nat; version: Text; logo: Text;coverImage: Text; contentImage: [Text];blockchain: Types.Blockchain; 
    currency: Types.Tokens;area: Types.Modules;
  }
  ):async Result.Result<Text, Text>{
    if (Principal.isAnonymous(caller)==false){
      if (Text.size(name) == 0 or Text.size(name) > 64) return #err("Invalid name");
      if (Text.size(desc) > 4000) return #err("Description too long");
      if (Text.size(website) > 512) return #err("URL too long");
      if (tags.size() > 5 or types.size() > 3) return #err("Too many tags/types");
      var itemIDs = itemID;
      //判断修改人是否是作者
      switch (itemsToData.get(itemID)) {
        case null {
           itemIDs := await Types.genRandomSha256Id();
        };
        case (?i) {             
          assert (Principal.equal(i.userID, caller));
        };
      };
      Item.createOrUpdateItem(itemsToData,itemIDs,name,caller,website,tags,types,desc,price,version,logo,coverImage,contentImage,blockchain,currency,area);
      //判断用户是否为认证用户 自动认证项目
      switch (userToData.get(caller)) {
        case null {};
        case (?u) { 
          if(u.role==#Project){
            Item.updateItemVerified(itemsToData,itemIDs,true);
          }
         };
      };
      #ok(itemIDs);
    }else{
      #err("Sorry, items cannot be posted/edited anonymously")
    }
  };

  //获取项目详情
  public query func getItem({itemID: Text}): async ?Item.Items {
   switch (itemsToData.get(itemID)) {
      case (null) null;
      case (?i) {
        if(i.isActive){
          ?i
        }else{
          null
        }
      };
    }
  };

  //批量获取项目详情
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

  // 获取项目列表
  public query func getItems({area:Types.Modules;types:Text;name:?Text;verified:Bool;page:Nat;pageSize:Nat}): async {
      listSize:Nat;
      dataList:[Item.Items];
      dataPage:Nat;
  } {
    //获取项目列表元组
    var itemList = Buffer.Buffer<Item.Items>(0);

    //储存筛选后的项目
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
   
    //筛选模糊搜索的项目
    let list =  switch(name) {
      case (null) Buffer.toArray(itemList);
      case (?i) {
        let items = Buffer.Buffer<Item.Items>(0);
        for(item in itemList.vals()){
            let upperText = Text.toUppercase(item.name);
            let upperPattern = Text.toUppercase(i);
          if(Text.contains(upperText, #text upperPattern)){
            items.add(item);
          };
        };
        Buffer.toArray(items);
      }
    };


    let (pagedItems, total) = Types.paginate(list, page, pageSize);

    {listSize = total;dataList = pagedItems;dataPage = page;}
  };

  //获取推荐项目列表
  public query func getItemList({area:Types.Modules;types:{#Downloads;#Favorites;#Price;#CreationTime;#Rating;#Exposure};page:Nat;pageSize:Nat}): async {
      listSize:Nat;
      dataList:[Item.Items];
      dataPage:Nat;
  } {
    //获取项目列表元组
    var list = Buffer.Buffer<Item.Items>(0);

    //储存筛选后的项目
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

  //更新项目状态
  public shared({ caller }) func userUpdateItemStatus({itemID:Text;available:Bool}): async Result.Result<Text, Text> {
    assert(Principal.isAnonymous(caller)==false);
     //判断修改人是否是作者
    switch (itemsToData.get(itemID)) {
      case null {};
      case (?i) {             
        assert (Principal.equal(i.userID, caller));
      };
    };
    var goLive :Bool=false;
    if(available){
      for((id,item) in Iter.toArray(fileStorageToData.entries()).vals()){
        if(item.itemID == itemID and item.status == #Succes){
          Item.updateItemStatus(itemsToData,itemID,#Succes);
          goLive := true;
        };
      };
      if(goLive){
        #ok("Launch successful! Your project is now available to users.")
      }else{
        #err("Project launch failed. Please retry or check the project file status.")
      };
    }else{
      Item.updateItemStatus(itemsToData,itemID,#Failed);
      #ok("The project has been taken down")
    }
  };

  //更新项目下载量
  public shared func uploadItemDownload({itemID: Text}): async () {
   switch (itemsToData.get(itemID)) {
      case (null) {};
      case (?i) {
       Item.updateItemDownloadsOrFavorites(itemsToData,itemID,?(i.downloads + 1),null,null,null);
      };
    }
  };

  //更新项目评分
  public shared({ caller }) func uploadItemRating({itemID: Text;rating:Float}): async () {
    assert(Principal.equal(caller,contentCanister));
    switch (itemsToData.get(itemID)) { 
      case (null) {}; 
      case (_) {
        Item.updateItemDownloadsOrFavorites(itemsToData,itemID,null,null,null,?rating);
      };
    };
  };

  //更新项目收藏量
  public shared({ caller }) func uploadItemFavorites({itemID: Text;favorite:Int}): async () {
    assert(Principal.equal(caller,contentCanister));
    switch (itemsToData.get(itemID)) { 
      case (null) {};
      case (?i) {
        Item.updateItemDownloadsOrFavorites(itemsToData,itemID,null,?(i.favorites + favorite),null,null);
      };
    };
  };

  //获取项目总数
  public query func getItemQuantity(): async Nat {
      let list = Iter.toArray(itemsToData.entries());
      return list.size()
  };

  //获取项目下载总数
  public query func getItemDownload(): async Int {
    let list = Iter.toArray(itemsToData.entries());
      var amount:Int=0;
      for((id,item) in list.vals()){
       amount:=amount + item.downloads;
      };
    return amount
  };

  //获取项目ID列表
  public query func getItemsID(): async [{name:Text;value:Text}] {
    //获取项目列表元组
    var itemList = Buffer.Buffer<{name:Text;value:Text}>(0);
    for((id,item) in Iter.toArray(itemsToData.entries()).vals()){
        if(item.isActive and item.verified){
            itemList.add({name=item.name;value=item.itemID});

        };
    };
    Buffer.toArray(itemList);
  };

  /*
  * 用户发布相关
  */

  //通过用户ID获取项目列表
  public query func getUserItemList({caller:Principal;page:Nat;pageSize:Nat}): async {
      listSize:Nat;
      dataList:[Item.Items];
      dataPage:Nat;
  } {
    //获取项目列表元组
    var itemList = Buffer.Buffer<Item.Items>(0);

    //储存筛选后的项目
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

  //通过用户ID获取项目数据详情
  public query({caller}) func getUserItemInfo(): async {downloads:Int;favorites:Int;rating:Float;size:Int} {
    //获取项目列表元组
    var downloads:Int = 0;
    var favorites:Int = 0;
    var rating:Float = 0;
    var size:Int = 0;

    //储存筛选后的项目
    for((id,item) in Iter.toArray(itemsToData.entries()).vals()){
        if(Principal.equal(item.userID, caller) and item.isActive){
            downloads := downloads+item.downloads;
            favorites := favorites+item.favorites;
            rating := rating+item.rating;
            size:=size+1;
        };
    };
   {downloads;favorites;rating;size}
  };

  //获取用户项目总数
  public query func getUserItemSize({caller:Principal}): async Nat {
    //获取项目列表元组
    var itemList = Buffer.Buffer<Item.Items>(0);
    //储存筛选后的项目
    for((id,item) in Iter.toArray(itemsToData.entries()).vals()){
        if(Principal.equal(item.userID, caller) and item.isActive){
            itemList.add(item);
        };
    };
    return itemList.size();
  };

  /*
  * 文件管理操作
  */
  //储存1MB一天大约需要消耗 1070万 Cycles
  
  //获取用户项目占用空间
  public query({ caller }) func getUserItemfileSize(): async Int {
    //获取作品列表元组
    let list = Iter.toArray(fileStorageToData.entries());
    //储存筛选后的作品
    var fileSize :Int= 0;
      for((id,file) in list.vals()){
          if(Principal.equal(file.userID, caller)){
            fileSize := file.size + fileSize;
          };
      };

    return fileSize
  };

  //返回可用的canister储存列表
  public query func getAllFileCanister(): async[(Principal, Text)] {
    Iter.toArray(canisterList.entries())
  };

  //设置上传许可 上传/更新文件
  public shared({ caller }) func setUploadLicense({itemID:Text;fileID:Text;name:Text;fileSize:Int;}): async Result.Result<Text, Text> {
    assert(Principal.isAnonymous(caller)==false);
    //判断修改人是否是作者
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
        // 计算文件总消耗fileSize
        if(u.cyclesBalance > (fileSize * Types.cycles1MbFile)){
          if(u.role == #User){ 
            Item.updateItemVerified(itemsToData,itemID,false);
          };
          //记录用户Cycles
          await CyclesCanister.addCyclesRecord({
            userID = caller;
            amount = fileSize * Types.cycles1MbFile;
            operation = #Sub;
            memo = "File upload";
            balance = u.cyclesBalance;
          });

          //判断是否存在重复fileID
          switch (fileStorageToData.get(fileID)) {
            case null {};
            case (?f) {
              if (not Principal.equal(f.userID, caller)) {
                return #err("fileID already used by another user");
              };
            };
          };

          //创建文件基础索引
          fileStorageToData.put(fileID,{
            fileID; //文件ID
            itemID; //作品ID
            name; //文件名
            size = fileSize; // 文件大小
            fileType=#Item; //文件类型
            fileOrigin=#Upload;//文件来源
            userID = caller;//上传者
            upDateTime=0; //更新时间
            creationTime=Time.now();//创建时间
            shardFile=[];// 分片储存位置
            status=#Default; //状态
          });
        
          #ok(fileID);
        }else{
          #err("Your Cycle balance is insufficient for this upload.");
        }
      };
    };
  };

  //查询Canister上传许可和用户Cycles
  public query func queryLicense({fileID:Text;userID:Principal}): async Bool {
    switch (fileStorageToData.get(fileID)) {
      case null false;
      case (?s) {
      if (not Principal.equal(s.userID, userID)) return false;
        //获取用户Cycles判断是否充足 >10M
        switch (userToData.get(userID)) {
          case null false;
          case (?u) { 
              if(u.cyclesBalance > (Types.cycles1MbFile*10)){
                true
              }else{
                false
              }
           };
        };
        
      };
    };
  };

  //查询文件状态
  public query func getFileState({fileID:Text}): async Bool {
    switch (fileStorageToData.get(fileID)) {
      case null false;
      case (_) {
          true
      };
    };
  };

  //更新文件索引 创建文件初始索引
  public shared({ caller }) func uploadFileStore({userID:Principal;chunkID:Text;canister:Principal;fileID:Text}): async () {
      //从canister列表中寻找canister
      switch (canisterList.get(caller)) {
        case (null) {};
        case (_) {
          //存储到临时存储
          switch (userToData.get(userID)) {
            case null {};
            case (?u) {
              //防止重复提交
              switch (fileToData.get(chunkID)) {
                case null {
                  //更新用户Cycles 1MB
                  User.upDateUserCycles(userToData,userID,u.cyclesBalance - Types.cycles1MbFile);
                  fileToData.put(chunkID,{
                    fileID; //文件ID
                    chunkID;//分片ID
                    canister; //文件储存Canister
                  })
                };
                case (_) {};
              };
            };
          }
        };
      };
  };

  //查询FileToData临时文件列表
  public query({ caller }) func queryFileToData({fileID:Text}): async ([{chunkID:Text;canister:Principal}]) {
      //判断用户是否为项目创建者或管理员
      switch (fileStorageToData.get(fileID)) {
        case (null) {};
        case (?i) {
          if(Principal.equal(i.userID, caller)){
            //创建者
          }else{
            assert(Principal.equal(caller,ownerAdmin));
          };
        };
      };
      //筛选文件队列
      var list = Buffer.Buffer<{chunkID:Text;canister:Principal}>(0);
      for((id,file) in Iter.toArray(fileToData.entries()).vals()){
          if(file.fileID==fileID){
            list.add({chunkID=file.chunkID;canister=file.canister})
          };
      };
      Buffer.toArray(list);
  };

  //完成文件上传 更新索引 防止同步导致的问题
  public shared({ caller }) func uploadFileFinish({fileID:Text}): async () {
    //获取文件索引信息
    switch (fileStorageToData.get(fileID)) {
      case (null) {};
      case (?s) {
        //验证用户
        assert (Principal.equal(s.userID, caller));
        //筛选文件队列
        var list = Buffer.Buffer<{chunkID:Text;canister:Principal}>(0);
        for((id,file) in Iter.toArray(fileToData.entries()).vals()){
            if(file.fileID==fileID){
              list.add({chunkID=file.chunkID;canister=file.canister})
            };
        };
        fileStorageToData.put(fileID,{ s with upDateTime=Time.now();shardFile=Buffer.toArray(list)});
        //改变状态
        if(list.size() >= s.size){
          fileStorageToData.put(fileID,{ s with upDateTime=Time.now();shardFile=Buffer.toArray(list);status=#Succes});
          Item.updateItemStatus(itemsToData,s.itemID,#Succes);
        };
      };
    }; 
  };


  //删除文件索引/文件
  public shared({ caller }) func deleteFile({itemID:Text;fileID:Text}): async () {
    //判断修改人是否是作者
    switch (itemsToData.get(itemID)) {
      case null {};
      case (?i) {             
        assert (Principal.equal(i.userID, caller));
      };
    };
    //删除文件 
    fileStorageToData.delete(fileID);
    //更新项目状态
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

  //定时清理所有失效 过期 碎片文件
  private func deleteFileInvalidAll(): async () {
    var list = HashMap.fromIter<Principal, [Text]>([].vals(), 0, Principal.equal, Principal.hash);
    for((id,item) in Iter.toArray(fileStorageToData.entries()).vals()){
      //筛选上传成功 或 正在上传的文件 （10分钟内） 
        if(item.status == #Succes or item.creationTime + (10 * Types.minute) > Time.now()){
          //计算文件大小扣除每个储存成功的用户的cycles 
          switch (userToData.get(item.userID)) {
            case null {};
            case (?u) {
              if(u.cyclesBalance > (item.size*Types.cycles1Mb1DayFile)){
                User.upDateUserCycles(userToData,u.userID,u.cyclesBalance-(item.size*Types.cycles1Mb1DayFile));
                //记录用户Cycles
                await CyclesCanister.addCyclesRecord({
                  userID = u.userID;
                  amount =item.size * Types.cycles1Mb1DayFile;
                  operation = #Sub;
                  memo = "File storage fee";
                  balance = u.cyclesBalance;
                });

                //循环文件分片列表 匹配Canister与文件分片ID
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
                //更新文件属性
                Item.updateItemStatus(itemsToData,item.itemID,#Failed);
              }
            }
          };
        };
    };
    var time :Nat = 0;
    //清理文件 将成功的文件保存 清理fileList列表中不存在的
    for((id,canister) in Iter.toArray(list.entries()).vals()){
        let fileStore:Types.StoreCanister = actor(Principal.toText(id));
        time:=time+1;
        let _ = Timer.setTimer<system>(#nanoseconds(time*Types.millisecond*100), func() : async () {
          fileStore.clearFile({fileList=canister});
        });  
    };
    //清理文件队列
    fileToData:= HashMap.fromIter<Text, Types.FilePath>([].vals(), 0, Text.equal, Text.hash);
  };

  //启动循环计时器 每24小时执行一次清理任务
  ignore Timer.recurringTimer<system>(#nanoseconds (Types.hour*24), deleteFileInvalidAll);  

  //获取项目文件ID列表
  public query func getItemFileCanister({itemID:Text}): async[Types.FileStorageBasic] {
    //获取文件列表元组
    var list = Buffer.Buffer<Types.FileStorageBasic>(0);
    //储存筛选后的项目
    for((id,item) in Iter.toArray(fileStorageToData.entries()).vals()){
        if(item.itemID == itemID and item.fileOrigin != #Disk){
            list.add(item);
        };
    };
    Buffer.toArray(list);
  };

  //获取用户全部文件列表
  public query({ caller }) func getFileList(): async[Types.FileStorage] {
    //获取文件列表元组
    var list = Buffer.Buffer<Types.FileStorage>(0);
    //储存筛选后的项目
    for((id,item) in Iter.toArray(fileStorageToData.entries()).vals()){
        if(Principal.equal(item.userID, caller) and item.fileOrigin != #Disk){
            list.add(item);
        };
    };
    Buffer.toArray(list);
  };

  //获取全部项目占用空间
  public query func getItemFileSize(): async Int {
    //获取作品列表元组
    let list = Iter.toArray(fileStorageToData.entries());
    //储存筛选后的作品
    var fileSize :Int= 0;
      for((id,file) in list.vals()){
          fileSize := file.size + fileSize;
      };

    return fileSize
  };

  //获取文件索引
  public query({ caller }) func getFileCanisterList({fileID:Text;itemID:Text}): async ?Types.FileStorage {
   //获取订单列表
    var isTrade:Bool = false;
    for((id,trade) in Iter.toArray(tradeToData.entries()).vals()){
        //用户购买订单存在且状态正确
        if(Principal.equal(trade.userID, caller) and trade.itemID == itemID and trade.isActive){
          isTrade:=true
        };
    };
    //或用户为项目创建者
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
          if (s.itemID != itemID) { return null }; 
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
  * 交易操作 购买 退款
  */

  //创建交易
  public shared({ caller }) func createTrade({itemID:Text}):async Result.Result<Text, Text> {
    assert(Principal.isAnonymous(caller)==false);
    let transactionID = await Types.genRandomSha256Id();
    let isTransfer : Bool = switch(transferToData.get(transactionID)) {
      case (null) { true };
      case (?t) {
        if(Time.now()  > ( t.time + Types.second * 10)){
          true
        }else{
          false
        }
      }
    };
    if(isTransfer){
      transferToData.put(transactionID,{userID = caller;transferID=transactionID;state=false;time = Time.now()});
      //判断是否已经购买
      if((await getIsItemTrade({userID=caller;itemID=itemID})) == null){
        //判断该项目是否存在
        switch (itemsToData.get(itemID)) {
          case (null) {
            #err("Unexpected error: No purchase record")
          };
          case (?i) {
            //判断商品状态
            if((i.status==#Succes)){
              //判断商品价格
              if(i.price > 0){
                //此处执行转账方法 成功将商品加入仓库
                var transferResult = await transferToken({from=caller;to=i.userID;price=i.price;token=i.currency;refund=false});
                //判断是否交易成功后创建交易
                switch (transferResult) {
                  case (#ok(_)) {
                  //判断是否是免手续费账户 收取手续费
                  // switch (fundedToData.get(caller)) {
                  //   case null {
                  //     var transferFeeResult = await transferFee({caller=i.userID;amount=(i.price*5)/100;token=i.currency});
                  //   };
                  //   case (?f) {};
                  // };
                  transferToData.delete(transactionID);
                  Trade.createTransaction(tradeToData,transactionID,caller,i.userID,i.itemID,i.price,i.currency);
                  #ok(transactionID);
                  };
                  case (#err(_)) { 
                    #err("Transaction failed, please check if your balance is sufficient")
                  };
                };
              }else{
                //免费商品 免费入库
                transferToData.delete(transactionID);
                Trade.createTransaction(tradeToData,transactionID,caller,i.userID,i.itemID,i.price,i.currency);
                #ok(transactionID);
              };
            }else{
              #err("The current product has been removed from the shelves")
            };
          };
        };
      }else{
          #err("You already own this work and cannot purchase it again")
      };
    }else{
      #err("Your request is too frequent. Please try again later.");
    }
  };

  //获取当前项目是否已购买
  public query func getIsItemTrade({userID:Principal;itemID:Text}): async ?Text {
    //获取项目交易表
   let list = Iter.toArray(tradeToData.entries());
    //储存我的仓库
    var buy  :?Text = null;
    for((id,item) in list.vals()){
      if(Principal.equal(item.userID, userID) and (item.itemID == itemID) and item.isActive){
        buy := ?item.transactionID;
      }
   };
   return buy;
  };

  //获取订单数据详情
  public query({caller}) func getTradeInfo(): async {refunded:Int;refunding:Int;size:Int;earnings:Int} {
    //获取项目列表元组
    var refunded:Int = 0;
    var refunding:Int = 0;
    var earnings:Int = 0;
    var size:Int = 0;

    //储存总订单数
    for((id,trade) in Iter.toArray(tradeToData.entries()).vals()){
        if(Principal.equal(trade.authorID, caller) ){
            size:=size+1;
        };
    };
    earnings := size;
    //筛选退款中 and 已退款的项目数
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
   {refunded;refunding;size;earnings}
  };

  //获取订单详情
  public query({ caller }) func getItemTradeInfo({transactionID: Text}): async ?Trade.Transaction {
   switch (tradeToData.get(transactionID)) {
      case null null;
      case (?t) {
        if (Principal.equal(caller, t.userID) or Principal.equal(caller, t.authorID) or Principal.equal(caller, ownerAdmin)) {
        ?t
      } else null
      };
    }
  };

  //获取用户项目购买列表--仅限当前用户  
  public query({ caller }) func getItemTradeList({page:Nat;pageSize:Nat}): async {
      listSize:Nat;
      dataList:[(Text, Item.Items)];
      dataPage:Nat;
  } {
    //获取商品交易表
   let tradeList = Iter.toArray(tradeToData.entries());
    //储存我的仓库
   let itemList = Buffer.Buffer<(Text, Item.Items)>(0);
   for((id,trade) in tradeList.vals()){
      if(Principal.equal(trade.userID, caller) and trade.isActive){
        switch (itemsToData.get(trade.itemID)) {
          case null {};
          case (?i) {
            itemList.add((trade.transactionID, i));
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

  //发起退款 前置-判断是否已存在交易记录-是否已经发起退款
  public shared({ caller }) func createRefunds({transactionID:Text;refundReason:Text}):async Result.Result<Text, Text> {
      //判断是否已存在交易记录
      switch (tradeToData.get(transactionID)) {
        case (null) {
          #err("Unexpected error: No purchase record")
        };
        case (?t) {
          //判断是否是免费商品
          if(t.paymentAmount > 0){
            //判断是否超过退款时间
            if(t.creationTime + Types.hour*48 > Time.now()){
              //判断购买用户是否正确
              if((Principal.equal(t.userID, caller))){
                //判断退款记录是否存在
                switch (refundsToData.get(transactionID)) {
                  case (null){
                  //创建退款
                  Trade.createRefunds(refundsToData,transactionID,t.userID,t.authorID,t.paymentAmount,refundReason);
                  #ok(transactionID)
                  };
                  case (_) {
                    #err("A refund has been initiated for this transaction")
                  };
                };
              }else{
                #err("The current product has been removed from the shelves")
              };
            }else{
              #err("The 48 hour refund period has exceeded")
            };
          }else{
            #err("The order payment amount is 0, so no refund is needed")
          };
        };
      };
  };

 //获取退款记录详情
  public query({ caller }) func getRefundsInfo({transactionID:Text}): async ?Trade.Refunds {
   switch (refundsToData.get(transactionID)) {
      case null null;
      case (?r) {
        if (Principal.equal(caller, r.userID) or Principal.equal(caller, r.authorID) or Principal.equal(caller, ownerAdmin)) {
        ?r
      } else null
      };
    }
  };

  //批准退款
  public shared({ caller }) func approveRefund({transactionID:Text;rejectRefundReason:Text;refund:Bool}):async Result.Result<Text, Text> {
    let isTransfer : Bool = switch(transferToData.get(transactionID)) {
      case (null) { true };
      case (?u) {
        if(Time.now()  > ( u.time + Types.second * 10)){
          true
        }else{
          false
        }
      }
    };
    if(isTransfer){
      transferToData.put(transactionID,{userID = caller;transferID=transactionID;state=false;time = Time.now()});
      //判断该退款信息是否存在
      switch (refundsToData.get(transactionID)) {
        case null {
          #err("Unexpected error: The refund information does not exist")
        };
        case (?r) {
          //判断调用人是否为项目方
          if((Principal.equal(r.authorID, caller))){
            //判断退款记录状态
              if(r.refund==#Default and r.isActive==true){
                //同意 or 拒绝
                switch(refund){ 
                    case (true) {
                      //获取订单
                      switch (tradeToData.get(transactionID)) { 
                          case (null) {
                            #err("No orders related to this order ID were obtained")
                          }; 
                          case (?t) {
                            //执行退款转账操作
                            var transferResult = await transferToken({from=r.authorID;to=r.userID;price=r.refundAmount;token=t.currency;refund=true});
                            //判断是否交易成功后创建交易
                              switch (transferResult) {
                                case (#ok(_)) {
                                transferToData.delete(transactionID);
                                Trade.setRefundsStatus(refundsToData,transactionID,"Approve Refund",#Succes);
                                //删除用户订单
                                Trade.setTradeIsActive(tradeToData,transactionID,false);     
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
                      Trade.setRefundsStatus(refundsToData,transactionID,rejectRefundReason,#Failed);
                      #ok(transactionID);
                    };
                };
              }else{
                #err("Unexpected error: Refund status is abnormal")
              }
          }else{
            #err("Unexpected error: Insufficient permissions. You are not the publisher of this project")
          };
        };
      };
     }else{
      #err("Your request is too frequent. Please try again later.")
     }
  };

  
  //退款列表
  public query({ caller }) func getRefundList({status:Types.Status;page:Nat;pageSize:Nat}): async {
      listSize:Nat;
      dataList:[Trade.Refunds];
      dataPage:Nat;
  } {
    //获取退款列表
   let refundsList = Iter.toArray(refundsToData.entries());
    //储存与我有关的退款
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

  //用户退款列表
  public query({ caller }) func getUserRefundList({status:Types.Status;page:Nat;pageSize:Nat}): async {
      listSize:Nat;
      dataList:[Trade.Refunds];
      dataPage:Nat;
  } {
    //获取退款列表
   let refundsList = Iter.toArray(refundsToData.entries());
    //储存与我有关的退款
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


  //订单列表
  public query({ caller }) func getTradeList({page:Nat;pageSize:Nat}): async {
      listSize:Nat;
      dataList:[Trade.Transaction];
      dataPage:Nat;
  }{
    //获取订单列表
   let tradeList = Iter.toArray(tradeToData.entries());
    //储存与我有订单列表
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

  //超时手动退款
  public shared({ caller }) func userRefund({transactionID:Text}):async Result.Result<Text, Text> {
    assert(Principal.isAnonymous(caller)==false);
    let isTransfer : Bool = switch(transferToData.get(transactionID)) {
      case (null) { true };
      case (?u) {
        if(Time.now()  > ( u.time + Types.second * 10)){
          true
        }else{
          false
        }
      }
    };
    if(isTransfer){
      transferToData.put(transactionID,{userID = caller;transferID=transactionID;state=false;time = Time.now()});
    //判断该退款信息是否存在
    switch (refundsToData.get(transactionID)) {
      case null {
        #err("Unexpected error: The refund information does not exist")
      };
      case (?r) {
        if((Principal.equal(r.userID, caller))){
        //判断退款状态
          if(r.refund==#Default and r.createTime+ Types.hour*48 < Time.now() and r.isActive==true){
             //获取订单
              switch (tradeToData.get(transactionID)) { 
                  case (null) {
                    #err("No orders related to this order ID were obtained")
                  }; 
                  case (?t) {
                    //执行退款转账操作
                    var transferResult = await transferToken({from=r.authorID;to=caller;price=r.refundAmount;token=t.currency;refund=true});
                    //判断是否交易成功后创建交易
                      switch (transferResult) {
                        case (#ok(_)) {
                        transferToData.delete(transactionID);
                        Trade.setRefundsStatus(refundsToData,transactionID,"Approve Refund",#Succes);
                        //删除用户订单
                        Trade.setTradeIsActive(tradeToData,transactionID,false);     
                        #ok(transactionID);
                        };
                        case (#err(_)) { 
                          #err("Transaction failed, please check if your balance is sufficient")
                        };
                      };
                  }; 
              };   
          }else{
            #err("Unexpected error: Refund status is abnormal")
          }
        }else{
          #err("Unexpected error: Insufficient permissions. You are not the publisher of this project")
        };
      };
      };
     }else{
      #err("Your request is too frequent. Please try again later.")
     }
  };


  /*
  * 关注用户
  */

  //获取我关注的/关注我的用户数
  public query func getFollowToFollowers({userID:Principal}): async {follows:Nat;followers:Nat} {
   switch (followToData.get(userID)) {
      case null {
        return {follows=0;followers=0}
      };
      case (?f) {
        return {follows=f.follows.size();followers=f.followers.size()}
      };
    };
  };


  //获取用户的关注列表
  public query({ caller }) func getFollow({userID:Principal}): async [User.UserFollowBasic] {
     switch (followToData.get(userID)) {
        case null {
          return []
        };
        case (?f) {
        //获取我关注的用户详情 填充用户信息
        var listFollows = Buffer.Buffer<User.UserFollowBasic>(0);
        for(user in f.follows.vals()){
          if(Principal.equal(caller, userID)){
            listFollows.add(user);
          }else{
            switch (followToData.get(caller)) {
              case null {};
              case (?cf) {
                let principal = Array.find<User.UserFollowBasic>(cf.follows, func x = x.userID == user.userID);
                switch (principal) {
                  case null {
                    listFollows.add({userID=user.userID;sha256ID=user.sha256ID;name=user.name;avatarURL=user.avatarURL;desc=user.desc;isFollow=false});
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

  //获取用户的粉丝列表
  public query({ caller }) func getFollower({userID:Principal}): async [User.UserFollowBasic] {
     switch (followToData.get(userID)) {
        case null {
          return []
        };
        case (?f) {
      //获取关注我的用户详情 填充用户信息
        var listFollowers = Buffer.Buffer<User.UserFollowBasic>(0);
        for(user in f.followers.vals()){
          switch (followToData.get(caller)) {
            case null {};
            case (?cf) {
              let principal = Array.find<User.UserFollowBasic>(cf.follows, func x = x.userID == user.userID);
              switch (principal) {
                case null {
                  listFollowers.add({userID=user.userID;sha256ID=user.sha256ID;name=user.name;avatarURL=user.avatarURL;desc=user.desc;isFollow=false});
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

  //获取我是否关注该用户
  public query({ caller }) func getFollowIsUser({userID:Principal}): async (Bool) {
     switch (followToData.get(caller)) {
        case null {false};
        case (?f) {
        //判断我关注的用户列表中是否存在该用户
         let principal = Array.find<User.UserFollowBasic>(f.follows, func x = x.userID == userID);
          switch (principal) {
            case null false;
            case (_) true;
          }
      };
    };
  };
    // 工具函数：判断 follows 列表中是否已包含指定用户
  func containsFollow(list : [User.UserFollowBasic], target : Principal) : Bool {
    switch (Array.find<User.UserFollowBasic>(list, func x = x.userID == target)) {
      case null false;
      case (?_) true;
    };
  };

  //关注用户
  public shared({ caller }) func getFollowUser({ userID : Principal }) : async () {
    assert(Principal.equal(caller, userID) == false);

    var didAdd : Bool = false;

    // 1) 更新我这边的 follows
    switch (userToData.get(userID)) {
      case null { /* 目标用户不存在，直接返回 */ () };
      case (?u) {
        switch (followToData.get(caller)) {
          case null {
            // 我这里没有任何记录 -> 一定是首次关注
            didAdd := true;
            followToData.put(caller, {
              userID = caller;
              follows = [{
                userID = u.userID; sha256ID = u.sha256ID; name = u.name;
                avatarURL = u.avatarURL; desc = u.desc; isFollow = true
              }];
              followers = [];
            });
          };
          case (?f) {
            if (containsFollow(f.follows, userID) == false) {
              didAdd := true;
              followToData.put(caller, {
                userID = caller;
                follows = Array.append<User.UserFollowBasic>(
                  f.follows,
                  [{
                    userID = u.userID; sha256ID = u.sha256ID; name = u.name;
                    avatarURL = u.avatarURL; desc = u.desc; isFollow = true
                  }]
                );
                followers = f.followers;
              });
            } // 已存在则不重复追加（幂等）
          };
        };
      };
    };

    // 2) 仅在“新增成功”时，同步到被关注用户的 followers
    if (didAdd) {
      switch (userToData.get(caller)) {
        case null { /* 理论上不应发生 */ () };
        case (?u) {
          switch (followToData.get(userID)) {
            case null {
              followToData.put(userID, {
                userID = userID;
                follows = [];
                followers = [{
                  userID = u.userID; sha256ID = u.sha256ID; name = u.name;
                  avatarURL = u.avatarURL; desc = u.desc; isFollow = true
                }];
              });
            };
            case (?f) {
              if (containsFollow(f.followers, caller) == false) {
                followToData.put(userID, {
                  userID = userID;
                  follows = f.follows;
                  followers = Array.append<User.UserFollowBasic>(
                    f.followers,
                    [{
                      userID = u.userID; sha256ID = u.sha256ID; name = u.name;
                      avatarURL = u.avatarURL; desc = u.desc; isFollow = true
                    }]
                  );
                });
              };
            };
          };
        };
      };
    };
  };

  //取关用户
  public shared({ caller }) func getCancelFollowUser({ userID : Principal }) : async () {
    var didRemove : Bool = false;

    // 1) 从我这边的 follows 移除对方
    switch (followToData.get(caller)) {
      case null { /* 我没有任何关注 */ () };
      case (?f) {
        let newFollows =
          Array.filter<User.UserFollowBasic>(f.follows, func x = x.userID != userID);
        didRemove := (newFollows.size() < f.follows.size()); // 有变化才算真的取关
        if (didRemove) {
          followToData.put(caller, {
            userID = caller;
            follows = newFollows;
            followers = f.followers;
          });
        };
      };
    };

    // 2) 仅在“确实移除”时，从对方的 followers 移除我
    if (didRemove) {
      switch (followToData.get(userID)) {
        case null { () };
        case (?f) {
          let newFollowers =
            Array.filter<User.UserFollowBasic>(f.followers, func x = x.userID != caller);
          if (newFollowers.size() < f.followers.size()) {
            followToData.put(userID, {
              userID = userID;
              follows = f.follows;
              followers = newFollowers;
            });
          };
        };
      };
    };
  };

  //根据关注量返回推荐用户列表
  public query({ caller }) func getUserList(): async [User.UserFollowBasic] {
    
    //按照粉丝量排序
     var list = Array.sort(Iter.toArray(followToData.entries()), func (a1 : (Principal, User.UserFollow) , a2 : (Principal, User.UserFollow) ) : Order.Order {
        if (a1.1.followers.size() < a2.1.followers.size()) {
          return #greater;
        } else if (a1.1.followers.size() > a2.1.followers.size()) {
          return #less;
        } else {
          return #equal;
        }
      });

    var listSize = 19;
    if(list.size() < listSize){
      listSize := list.size()
    };

    //选取前20
    let subArray = Array.subArray<(Principal, User.UserFollow)>(list, 0, listSize);
    var listFollowers = Buffer.Buffer<User.UserFollowBasic>(0);
      
      //筛选并判断我是否关注
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
  * cryptoDisk相关
  */

  // 获取文件索引
  public query({ caller }) func getCryptoDiskFile({fileID: Text}) : async ?Types.FileStorage {
    // 限定只能由 cryptoDiskCanister 调用
    assert(Principal.equal(caller, cryptoDiskCanister));
    // 查找并返回对应文件信息
    switch (fileStorageToData.get(fileID)) {
      case null null;
      case (?s) {?s};
    };
  };

  // 查询项目文件列表（支持分页和文件名搜索）
  public query({caller}) func getItemFileCanisterPaged({
    itemID: Text;
    page: Nat;
    pageSize: Nat;
    keyword: ?Text;
  }) : async {
    listSize: Nat;
    dataPage: Nat;
    dataList: [Types.FileStorage];
  } {
    let filtered = Buffer.Buffer<Types.FileStorage>(0);
    for ((_, file) in fileStorageToData.entries()) {
      if (file.itemID == itemID and Principal.equal(file.userID, caller)) {
        // 如果提供了关键字，则执行模糊匹配（忽略大小写）
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


  //设置上传许可
  public shared({ caller }) func setDiskUploadLicense({fileID:Text;name:Text;fileSize:Int;fileType:Types.FileType}): async Result.Result<Text, Text> {
    assert(Principal.isAnonymous(caller)==false);
    //判断是否已创建Disk空间
    if((await getUserFileSizeByItem({itemID=Principal.toText(caller)})) > 5120){
      #err("You don't have enough upload space");
    }else{
          switch (itemsToData.get(Principal.toText(caller))) {
      case null {
        //创建硬盘信息
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
        // 计算文件总消耗fileSize
        if(u.cyclesBalance > (fileSize * Types.cycles1MbFile)){
          //记录用户Cycles
          await CyclesCanister.addCyclesRecord({
            userID = caller;
            amount = fileSize * Types.cycles1MbFile;
            operation = #Sub;
            memo = "Crypto Disk upload";
            balance = u.cyclesBalance;
          });

          //判断是否存在重复fileID
          switch (fileStorageToData.get(fileID)) {
            case null {};
            case (?f) {
              if (not Principal.equal(f.userID, caller)) {
                return #err("fileID already used by another user");
              };
            };
          };

          //创建文件基础索引
          fileStorageToData.put(fileID,{
            fileID; //文件ID
            itemID = Principal.toText(caller) ; //硬盘空间ID
            name; //文件名
            size = fileSize; // 文件大小
            fileType; //文件类型
            fileOrigin=#Disk;//文件来源
            userID = caller;//上传者
            upDateTime=0; //更新时间
            creationTime=Time.now();//创建时间
            shardFile=[];// 分片储存位置
            status=#Default; //状态
          });
        
          #ok(fileID);
        }else{
          #err("Your Cycle balance is insufficient for this upload.");
        }
      };
    };
    };
  };
  
  //统计文件类型数量
  public shared query ({ caller }) func getUserFileTypeStatsByItem({ itemID: Text }) : async {photos: Nat;documents: Nat;file: Nat;videos: Nat;apps: Nat;others: Nat;} {
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
    {photos;documents;file;videos;apps;others;}
  };

  // 统计用户某个项目下所有文件的总大小
  public shared query ({ caller }) func getUserFileSizeByItem({ itemID: Text }) : async Int {
    var totalSize :Int= 0;
    for ((_, s) in fileStorageToData.entries()) {
      if (s.itemID == itemID and Principal.equal(s.userID, caller)) {
        totalSize += s.size;
      };
    };
    totalSize
  };

  /*
  * NFT交易
  */

  //创建交易
  public shared({ caller }) func createNftTrade({transactionID:Text;from:Principal;to:Principal;price:Nat;token:Types.Tokens;royalty:Nat;creator:Principal}):async Result.Result<Text, Text> {
    // 限定只能由 nftCanister 调用
    assert(Principal.equal(caller, nftCanister));
    let isTransfer : Bool = switch(transferToData.get(transactionID)) {
      case (null) { true };
      case (?t) {
        if(Time.now()  > ( t.time + Types.second * 10)){
          true
        }else{
          false
        }
      }
    };
    if(isTransfer){
        var transfer_price = price;
        if(royalty > 0){
          //判断是否存在版税
          transfer_price := (price * (100 - royalty)) / 100;
          //扣除版税 price * royalty / 100
        };
        var transferResult = await transferToken({from;to;price=transfer_price;token;refund=false});
        //判断是否交易成功后创建交易
        switch (transferResult) {
          case (#ok(_)) {
          //判断执行成功后的处理
            #ok(transactionID);
          };
          case (#err(_)) { 
            #err("Transaction failed, please check if your balance is sufficient")
          };
        };
    }else{
      #err("Your request is too frequent. Please try again later.");
    }
  };



  /*
  * 定时备份用户数据
  */


  //备份数据
  private func saveAllData(): async () {
    let date = Int.toText(Time.now() / Types.second);
    // 备份用户数据
    await Types.backupData({data=Iter.toArray(userToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Principal, User.User)]) : async () { await SaveCanister.saveUserToSave({ date = d; dataList })}});
    // 备份项目数据
    await Types.backupData({data=Iter.toArray(itemsToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Item.Items)]) : async () { await SaveCanister.saveItemToSave({ date = d; dataList })}});
    // 备份用户关注数据
    await Types.backupData({data=Iter.toArray(followToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Principal, User.UserFollow)]) : async () { await SaveCanister.saveFollowToSave({ date = d; dataList })}});
    // 备份文件索引数据
    await Types.backupData({data=Iter.toArray(fileStorageToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Types.FileStorage)]) : async () { await SaveCanister.saveStoreToSave({ date = d; dataList })}});
    // 备份交易数据
    await Types.backupData({data=Iter.toArray(tradeToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Trade.Transaction)]) : async () { await SaveCanister.saveTradeToSave({ date = d; dataList })}});
    // 备份退款数据
    await Types.backupData({data=Iter.toArray(refundsToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Trade.Refunds)]) : async () { await SaveCanister.saveFundsToSave({ date = d; dataList })}});
  };

  ignore Timer.recurringTimer<system>(#seconds 604800, saveAllData);

  //手动存储数据
  public shared({ caller }) func setSaveAllData({date:Text}): async () {
    assert(Principal.equal(caller,ownerAdmin));
    // 备份用户数据
    await Types.backupData({data=Iter.toArray(userToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Principal, User.User)]) : async () { await SaveCanister.saveUserToSave({ date = d; dataList })}});
    // 备份项目数据
    await Types.backupData({data=Iter.toArray(itemsToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Item.Items)]) : async () { await SaveCanister.saveItemToSave({ date = d; dataList })}});
    // 备份用户关注数据
    await Types.backupData({data=Iter.toArray(followToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Principal, User.UserFollow)]) : async () { await SaveCanister.saveFollowToSave({ date = d; dataList })}});
    // 备份文件索引数据
    await Types.backupData({data=Iter.toArray(fileStorageToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Types.FileStorage)]) : async () { await SaveCanister.saveStoreToSave({ date = d; dataList })}});
    // 备份交易数据
    await Types.backupData({data=Iter.toArray(tradeToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Trade.Transaction)]) : async () { await SaveCanister.saveTradeToSave({ date = d; dataList })}});
    // 备份退款数据
    await Types.backupData({data=Iter.toArray(refundsToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Trade.Refunds)]) : async () { await SaveCanister.saveFundsToSave({ date = d; dataList })}});
  };
  

  /*
  * redeemCode相关
  */

  //Cycles兑换码
  public shared({ caller }) func addCyclesRedeemCode({userID:Principal}): async (Bool) {
    assert(Principal.equal(caller,rewardCanister));
      //新增Cycles
      switch (userToData.get(userID)) {
        case null {false};
        case (?u) { 
          User.upDateUserCycles(userToData,userID,u.cyclesBalance + Types.cycles1T*5);
          //记录用户Cycles
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
