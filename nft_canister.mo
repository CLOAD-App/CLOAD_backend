import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Bool "mo:base/Bool";
import Timer "mo:base/Timer";
import Cycles "mo:base/ExperimentalCycles";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Order "mo:base/Order";
import TrieMap "mo:base/TrieMap";

import Types "types";

shared ({caller = owner}) persistent actor class Canister() = this {
  transient let ownerAdmin :Principal = Principal.fromText("cfklm-6bmf5-bovci-hk76c-rue3p-axnze-w2tjc-vpfdk-wppgd-xj2yv-2qe");
  
  //状态信息
  public type Standard = {
    #ICRC7; 
    #EXT; 
    #DIP721; 
  };

    
  //状态信息
  public type NFT_Types = {
    #Listed; 
    #Delist; 
    #Buy; 
    #Trading; 
  };

  // Collection 数据结构
  type Collection = {
    id: Text;                   // Collection 的唯一ID，例如 canister ID 或 slug
    symbol: Text;                 // 符号
    name: Text;                 // 显示名称（如 CLOAD Genesis）
    description: Text;          // 简介（支持多行 Markdown）
    logo: Text;                 // 图标链接（推荐正方形 512x512）
    banner: Text;              // 横幅图（首页大图）
    creator: Principal;         // 创建者身份（或合约部署者）
    nft_canister: Principal;    // 对应的 NFT canister ID
    total_supply: Nat;          // 总数（可选）
    standard: [Standard];       // 标准，如 "ICRC-7" / "EXT" / "DIP721"
    created_at: Int;            // 时间戳
    verified: Bool;             // 是否认证（平台官方标注）
    categories: [Text];         // 分类标签
    royalty: Nat;              // 版税百分比（basis points）
    currency: [Types.Tokens];   // 默认货币（如 ICP, BTC, ETH）
    nft: [Text];               //NFT展示图片
    listed: Bool;              // 是否在市场上架
    social_links: {
      website: ?Text;           // 官方网站
      twitter: ?Text;          // Twitter 链接
      discord: ?Text;          // Discord 链接
      telegram: ?Text;         // Telegram 链接
      github: ?Text;           // GitHub 链接
      medium: ?Text;           // Medium 链接
    };
    metaMap:[{key:Text;match:Text;filter:Bool}]; //元数据
  };

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

  //交易记录
  type Transaction = {
    transactionID: Text; // 交易记录的唯一标识符
    types: NFT_Types; // 交易记录的类型
    reg_id: Text; // NFT 的唯一登记标识符
    token_id: Nat; // NFT 的唯一标识
    collection_id: Text; // Collection 关联
    from: Principal; // 卖家身份
    to: Principal; // 买家身份
    price: Nat; // 交易价格
    currency: Types.Tokens; // 使用的货币类型
    timestamp: Int; // 交易时间戳
  };

  //交易锁
  private transient var transferToData = TrieMap.fromEntries<Text, TransferHash>([].vals(), Text.equal, Text.hash);
  public type TransferHash = {
    userID: Principal;//用户
    transferID:Text; //交易ID
    state: Bool; //交易状态
    time: Int;//时间
  };

  // 获取交易记录列表

  //Collection 列表
  private var collectionList_s: [(Text, Collection)] = [];
  private transient let collectionList = HashMap.fromIter<Text, Collection>(collectionList_s.vals(),0,Text.equal,Text.hash);

  // listedNFT 列表
  private var listedNFTs_s: [(Text, NFT_Registry)] = [];
  private transient let listedNFTs = HashMap.fromIter<Text, NFT_Registry>(listedNFTs_s.vals(),0,Text.equal,Text.hash);

  // Transaction 列表
  private var transactionToData_s: [(Text, Transaction)] = [];
  private transient let transactionToData = HashMap.fromIter<Text, Transaction>(transactionToData_s.vals(),0,Text.equal,Text.hash);

  // Discord信息
  private var discordToData_s: [(Principal, Types.Discord)] = [];
  private transient let discordToData = HashMap.fromIter<Principal, Types.Discord>(discordToData_s.vals(), 0, Principal.equal, Principal.hash);

  // funded信息
  private var nftToData_s : [Types.NFT] = [];
  private transient let nftToData : Buffer.Buffer<Types.NFT> = Types.fromArray(nftToData_s);

  system func preupgrade() {
    nftToData_s := Buffer.toArray(nftToData);
    discordToData_s := Iter.toArray(discordToData.entries());
    collectionList_s := Iter.toArray(collectionList.entries());
    listedNFTs_s := Iter.toArray(listedNFTs.entries());
    transactionToData_s := Iter.toArray(transactionToData.entries());
  };

  system func postupgrade() {
    nftToData_s := [];
    discordToData_s := [];
    collectionList_s := [];
    listedNFTs_s := [];
    transactionToData_s := [];
  };

  public type CenterCanister = actor {
    createNftTrade : shared ({transactionID:Text;from:Principal;to:Principal;price:Nat;token:Types.Tokens;royalty:Nat;creator:Principal}) -> async Result.Result<Text, Text>;
  };
  transient let center:CenterCanister = actor("yffxi-vqaaa-aaaak-qcrnq-cai");


  //同步
  public type SaveCanister = actor {
      saveNftToSave : shared ({date:Text;dataList:[Types.NFT]}) -> async ();
      saveNFTsToSave : shared ({date:Text;dataList:[(Text, NFT_Registry)]}) -> async ();
  };

  transient let SaveCanister : SaveCanister = actor("emmm6-kaaaa-aaaak-qlnwa-cai");

  /*
  * Market相关
  */


  //登记NFT
  public shared({ caller }) func registerCollection({newCol: Collection}): async () {
    assert(Principal.equal(caller, ownerAdmin)); // 仅管理员可调用

    switch (collectionList.get(newCol.id)) {
      case null {
        // 新增
        let fresh: Collection = {
          id = newCol.id;
          symbol = newCol.symbol;
          name = newCol.name;
          description = newCol.description;
          logo = newCol.logo;
          banner = newCol.banner;
          creator = newCol.creator;
          nft_canister = newCol.nft_canister;
          total_supply = newCol.total_supply;
          standard = newCol.standard;
          created_at = Time.now();
          verified = false;
          nft = newCol.nft;
          categories = newCol.categories;
          royalty = newCol.royalty;
          currency = newCol.currency;
          listed = true;
          social_links = newCol.social_links;
          metaMap = newCol.metaMap; // 元数据
        };
        collectionList.put(fresh.id, fresh);
      };
      case (_) {};
    };
  };


  //更新NFT
  public shared({ caller }) func updataCollection({id:Text;creator:Principal;logo:Text;description: Text;banner:Text;nft:[Text];total_supply:Nat}): async () {
    assert(Principal.equal(caller, ownerAdmin)); // 仅管理员可调用
    switch (collectionList.get(id)) {
      case null {};
      case (?c) {
        // 更新指定字段
        let updated = {
          c with
          creator;
          description;
          logo;
          banner;
          nft;
          total_supply;
        };
        collectionList.put(c.id, updated);
      };
    };
  };

  // 获取某个 Collection 的详情
  public query func getCollection({id: Text}) : async ?Collection {
    collectionList.get(id)
  };

  // 获取所有 Collection 列表
  public query func getAllCollections() : async [Collection] {
    Iter.toArray(collectionList.vals())
  };

 
  //批量转移NFT ICRC7 从Canister往外转移
  private func nft_transfer_batch({args: [{ to: Principal;  token_id: Nat }];canister:Text}) : async [Bool] {
    let Icrc7_Api : Types.Icrc7 = actor(canister);

    let transfers = Array.map<{ to: Principal; token_id: Nat }, Types.Icrc7TransferArgs>(
      args,
      func(arg: { to: Principal; token_id: Nat }): Types.Icrc7TransferArgs {
        {
          to = { owner = arg.to; subaccount = null };
          token_id = arg.token_id;
          memo = null;
          from_subaccount = null;
          created_at_time = null;
        }
      }
    );
    let res = await Icrc7_Api.icrc7_transfer(transfers);
    // 遍历每个结果项
    if (Array.size(res) == 0) return [];
    var results : [Bool] = [];
    for (i in Iter.range(0, Array.size(res) - 1)) {
      let resultBool = switch (res[i]) {
        case (null) false;
        case (?r) 
          switch (r) {
            case (#Ok(_)) true;
            case (#Err(_)) false;
          };
      };
      results := Array.append(results, [resultBool]);
    };
  return results;
  };


  //nft 转移 从Canister往外转移
  private func nft_transfer({to:Principal;token_id:Nat;canister:Text}) : async (Bool) {
    let Icrc7_Api : Types.Icrc7 = actor(canister);

    let nowNat64 : Nat64 = Nat64.fromIntWrap(Time.now());

    let res = await Icrc7_Api.icrc7_transfer([{
        to = { owner = to; subaccount = null };
        token_id;
        memo = null;
        from_subaccount = null;
        created_at_time = ?nowNat64;
    }]);
    // 处理转移结果

    if(Array.size(res) < 1){
      return false
    };

    switch (res[0]) {
      case (null) {
          false
      };
      case (?result) {
        switch (result) {
          case (#Ok(_)) true;
          case (#Err(_)) false;
        };
      };
    }; 
  };

  //判断NFT是否归属当前Canister
  private func nft_verify({token_id:Nat;canister:Text}) : async (Bool) {
    let Icrc7_Api : Types.Icrc7 = actor(canister);
    let res = await Icrc7_Api.icrc7_owner_of([token_id]);
    switch (res[0]) {
      case (?ownerRecord) {
        if(Principal.equal(ownerRecord.owner, Principal.fromActor(this))){
          true;
        }else{
          false;
        };
      };
      case null {
        // 如果返回 null，说明该 NFT 不存在或不归属当前 用户
        false;
      };
    };
  };

  //判断NFT是否归属当前Canister
  private func nft_verify_user({token_id:Nat;userID:Principal;canister:Text}) : async (Bool) {
    let Icrc7_Api : Types.Icrc7 = actor(canister);
    let res = await Icrc7_Api.icrc7_owner_of([token_id]);
    switch (res[0]) {
      case (?ownerRecord) {
        if(Principal.equal(ownerRecord.owner, userID)){
          true;
        }else{
          false;
        };
      };
      case null {
        // 如果返回 null，说明该 NFT 不存在或不归属当前 用户
        false;
      };
    };
  };

  //登记NFT 
  public shared({ caller }) func regListedNFT({nft: NFT_Registry}) : async Result.Result<Text, Text>  {
      assert(Principal.isAnonymous(caller)==false);

      let reg_id = await Types.genRandomSha256Id();
      switch (listedNFTs.get(reg_id)) {
        case null {
          //验证NFT归属权是否为当前用户
          if(await nft_verify_user({token_id = nft.token_id;userID = caller;canister = nft.collection_id})) {
            //判断该NFT是否已经存在登记记录
            for ((id,nfts) in Iter.toArray(listedNFTs.entries()).vals()) {
              if (nfts.collection_id == nft.collection_id and nfts.token_id == nft.token_id and nfts.isActive) {
                // 如果存在，更新状态为不可用
                  let updatedNFT: NFT_Registry = {
                    nfts with
                    isActive = false;
                  };
                listedNFTs.put(nfts.reg_id, updatedNFT);
              };
            }; 

            // 登记NFT
            let newNFT: NFT_Registry = {
              reg_id = reg_id;
              token_id = nft.token_id;
              collection_id = nft.collection_id;
              nft_canister = nft.nft_canister;
              price = nft.price;
              currency = nft.currency;
              expiration = nft.expiration;
              seller = caller;
              owner = Principal.fromActor(this);
              created_at = Time.now();
              status = #Default;
              isActive = true;
            };
            listedNFTs.put(reg_id, newNFT);
            return #ok(reg_id);
          }else{
            return #err("You do not own this NFT or it is not in your wallet");
          };
           
        };
        case (?nft) {
          return #err("NFT registration failed, please try again");
        };
      };
  };

  //上架NFT 新增记录
  public shared({ caller }) func upsertListedNFT({reg_id: Text;}) : async () {
    assert(Principal.isAnonymous(caller)==false);
    switch (listedNFTs.get(reg_id)) {
      case null {};
      case (?nft) {
        // 验证平台是否已持有该NFT
        if(await nft_verify({token_id = nft.token_id;canister = nft.collection_id})) {
          assert(Principal.equal(caller, nft.seller));
          await addTransaction({reg_id; to = Principal.fromActor(this);types = #Listed});
        };
      };
    };
  };

  //NFT 更新操作
  public shared({ caller }) func updateNFT({nft: NFT_Registry}) : async Result.Result<Bool, Text> {
    switch (listedNFTs.get(nft.reg_id)) {
      case null {#err("NFT not found. Please verify the contract and token ID")};
      case (?n) {
        // 更新 NFT，仅允许原 seller 修改部分字段
        assert(Principal.equal(caller, n.seller));

         //判断是否有正在交易中的记录
        switch (transferToData.get(nft.reg_id)) {
          case null {};
          case (?t) {
            if (t.state and Time.now() - t.time < (Types.minute*2)) {
              // 如果有正在交易中的记录且交易时间未结束，不能修改
              return #err("The NFT is currently in a trade; please try again later");
            };
          };
        };

        let updatedNFT: NFT_Registry = {
          n with
          price = nft.price;
          expiration = nft.expiration;
        };
        listedNFTs.put(n.reg_id, updatedNFT);
        #ok(true);
      };
    };
  };

  // 下架某个 NFT
  public shared({ caller }) func unlistNFT({reg_id: Text}) : async Result.Result<Bool, Text> {
    switch (listedNFTs.get(reg_id)) {
      case (null) return #err("NFT not found. Please verify the contract and token ID");
      case (?nft) {
        // 只能卖家本人才能下架
        if (not Principal.equal(nft.seller, caller)) return #err("You not the owner of this NFT and cannot perform this action");

        //判断是否有正在交易中的记录
        switch (transferToData.get(nft.reg_id)) {
          case null {};
          case (?t) {
            if (t.state and Time.now() - t.time < (Types.minute*2)) {
              // 如果有正在交易中的记录且交易时间未结束，不能下架
              return #err("The NFT is currently in a trade; please try again later");
            };
          };
        };

        let transfer = await nft_transfer({to = nft.seller; token_id = nft.token_id; canister = nft.collection_id});
        // 调用Canister转移NFT回原所有者
        if (transfer) {
          // 更新 NFT 状态
          let updatedNFT: NFT_Registry = {nft with isActive = false;status = #Failed};
          listedNFTs.put(nft.reg_id, updatedNFT);
          await addTransaction({reg_id; to = nft.seller;types = #Delist});
          #ok(true);
        }else{
          return #err("NFT transfer failed. Please contact the administrator for verification");
        }
      };
    };
  };

  // 购买 NFT
  public shared ({ caller }) func buyNFT({ reg_id: Text }) : async Result.Result<Bool, Text> {
    assert(Principal.isAnonymous(caller)==false);
    switch (listedNFTs.get(reg_id)) {
      case (null) {
        return #err("NFT does not exist or is not listed");
      };
      case (?nft) {
        //执行交易中
        let verified = await nft_verify({ token_id = nft.token_id; canister = nft.collection_id });
        if (verified != true) {
          return #err("NFT not in escrow");
        };
        if (nft.isActive == false) {
          return #err("This NFT has been removed from the market or is unavailable");
        };

        if (Principal.equal(nft.seller, caller)) {
          return #err("Can't buy your own NFT");
        };

        switch (collectionList.get(nft.collection_id)) {
          case (null) {
            return #err("nft collection does not exist");
          };
          case (?c) {
            if(nft.status==#Failed){
              return #err("This NFT has been delisted. Please refresh and try again");
            };
            
            transferToData.put(reg_id,{userID = caller;transferID=reg_id;state=true;time = Time.now()});

            // （可选）执行 ICRC 代币转账逻辑，此处略过
            let transferResult = await center.createNftTrade({ 
              transactionID = reg_id;
              from = caller;
              to = nft.seller;
              price = nft.price;
              token = #ICP;
              royalty = c.royalty;
              creator = c.creator; // 传递创作者 ID
            });
            switch (transferResult) {
                case (#ok(_)) {
                 // 调用Canister转移NFT 给购买者
                    if (await nft_transfer({to = caller; token_id = nft.token_id;canister = nft.collection_id})) {
                      // 更新 NFT 状态
                      let updatedNFT: NFT_Registry = {nft with isActive = false;status = #Succes};
                      listedNFTs.put(nft.reg_id, updatedNFT);
                      //更新锁状态
                      transferToData.delete(reg_id);

                      // 创建交易记录
                      await addTransaction({reg_id; to = caller;types = #Buy});
                      return #ok(true);
                    }else{
                      return #err("NFT transfer failed");
                    };
                  #ok(true);
                };
                case (#err(_)) { 
                  #err("Transaction failed, please check if your balance is sufficient")
                };
              };
          };
        };
      };
    };
  };



  // 获取某个 Collection 的所有 NFT 列表
  public composite query func getNFTsByCollectionPaged({ collection_id: Text}) : async [NFT_Registry] {
    var list = Buffer.Buffer<NFT_Registry>(0);

    let Icrc7_Api : Types.Icrc7 = actor(collection_id);
    let tokens = await Icrc7_Api.icrc7_tokens_of({ owner = Principal.fromActor(this); subaccount = null }, null, null);

    for ((id,nft) in Iter.toArray(listedNFTs.entries()).vals()) {
      if (nft.collection_id == collection_id and nft.isActive) {
        switch (Array.find<Nat>(tokens, func x = x == nft.token_id)) {
          case null {};
          case (?_) {
            list.add(nft);
          };
        }
      };
    };

    Buffer.toArray(list)
  };

  // 获取某个 Collection 下与我的所有 NFT 列表
  public composite query({ caller }) func getNFTsByCollectionMe({ collection_id: Text}) : async [NFT_Registry] {
    var list = Buffer.Buffer<NFT_Registry>(0);
    //获取Canister 持有的 NFT
    let Icrc7_Api : Types.Icrc7 = actor(collection_id);
    let tokens = await Icrc7_Api.icrc7_tokens_of({ owner = Principal.fromActor(this); subaccount = null }, null, null);

    for ((id,nft) in Iter.toArray(listedNFTs.entries()).vals()) {
      if (nft.collection_id == collection_id and nft.isActive and Principal.equal(nft.seller, caller)) {
          switch (Array.find<Nat>(tokens, func x = x == nft.token_id)) {
            case null {};
            case (?_) {
              list.add(nft);
            };
          }
      };
    };
    Buffer.toArray(list)
  };

  // 获取某个 Nft 的详情
  public query func getNft({reg_id: Text}) : async ?NFT_Registry {
    listedNFTs.get(reg_id)
  };

  // 获取某个 Nft 的详情
  public composite query func getTokenNft({token_id: Nat;collection_id: Text;}) : async ?NFT_Registry {
    let Icrc7_Api : Types.Icrc7 = actor(collection_id);
    let tokens = await Icrc7_Api.icrc7_tokens_of({ owner = Principal.fromActor(this); subaccount = null }, null, null);
    // 遍历所有已上架的 NFT
    for ((id,nft) in Iter.toArray(listedNFTs.entries()).vals()) {
      if (nft.collection_id == collection_id and nft.token_id == token_id and nft.isActive) {
           switch (Array.find<Nat>(tokens, func x = x == nft.token_id)) {
          case null {};
          case (?_) {
            return ?nft;
          };
        }
      };
    }; 
    return null;
  };

  // 获取我已上架的 NFT 列表
  public query func getMyListedNFTsPaged({ userID: Principal; page: Nat; pageSize: Nat }) : async {
    listSize: Nat;
    dataList: [NFT_Registry];
    dataPage: Nat;
  } {
    var itemList = Buffer.Buffer<NFT_Registry>(0);

    for ((id,nft) in Iter.toArray(listedNFTs.entries()).vals()) {
      if (nft.seller == userID and nft.isActive) {
        itemList.add(nft);
      };
    };

    let (pagedItems, total) = Types.paginate(Buffer.toArray(itemList), page, pageSize);

    {
      listSize = total;
      dataList = pagedItems;
      dataPage = page;
    }
  };


  //创建交易记录
  private func addTransaction({reg_id:Text;to: Principal;types:NFT_Types}) : async() {
    let transactionID = await Types.genRandomSha256Id();

    switch (transactionToData.get(transactionID)) {
      case null {
        switch (listedNFTs.get(reg_id)) {
          case (null) {};
          case (?nft) {
            
            var owner = Principal.fromActor(this);
           if(Principal.equal(to,Principal.fromActor(this))){
              owner := nft.seller;
           };


           // 新增交易记录
            let transaction: Transaction = {
              transactionID;
              types;
              reg_id = nft.reg_id;
              token_id = nft.token_id;
              collection_id = nft.collection_id;
              from = owner;
              to = to; 
              price = nft.price;
              currency = nft.currency;
              timestamp = Time.now();
            };
            transactionToData.put(transactionID, transaction);
          };
        };
      };
      case (?nft) {};
    };
  };


  // 获取某个 Collection 下的所有交易记录列表
  public query func getTransactionsByCollectionPaged({ collection_id: Text; page: Nat; pageSize: Nat }) : async {
    listSize: Nat;
    dataList: [Transaction];
    dataPage: Nat;
  } {
    var itemList = Buffer.Buffer<Transaction>(0);

    for ((id,tx) in Iter.toArray(transactionToData.entries()).vals()) {
      if (tx.collection_id == collection_id and tx.types != #Trading) {
        itemList.add(tx);
      };
    };

    let sortedList = Array.sort(
      Buffer.toArray(itemList),
      func(a: Transaction, b: Transaction): Order.Order {
        // timestamp 从大到小 => 最新排前面
        if (a.timestamp > b.timestamp) { #less }
        else if (a.timestamp < b.timestamp) { #greater }
        else { #equal }
      }
    );

    let (pagedItems, total) = Types.paginate(sortedList, page, pageSize);

    {
      listSize = total;
      dataList = pagedItems;
      dataPage = page;
    }
  };

  // 获取某个 Collection 下指定 token_id 的所有交易记录列表
  public query func getTransactionsByCollectionAndTokenPaged({ collection_id: Text; token_id: Nat; page: Nat; pageSize: Nat }) : async {
    listSize: Nat;
    dataList: [Transaction];
    dataPage: Nat;
  } {
    var itemList = Buffer.Buffer<Transaction>(0);

    for ((id,tx) in Iter.toArray(transactionToData.entries()).vals()) {
      if (tx.collection_id == collection_id and tx.token_id == token_id and tx.types != #Trading) {
        itemList.add(tx);
      };
    };

      let sortedList = Array.sort(
        Buffer.toArray(itemList),
        func(a: Transaction, b: Transaction): Order.Order {
          // timestamp 从大到小 => 最新排前面
          if (a.timestamp > b.timestamp) { #less }
          else if (a.timestamp < b.timestamp) { #greater }
          else { #equal }
        }
      );

    let (pagedItems, total) = Types.paginate(sortedList, page, pageSize);

    {
      listSize = total;
      dataList = pagedItems;
      dataPage = page;
    }
  };


  // 获取当前用户相关的所有交易记录列表（作为卖家或买家）
  public query ({ caller }) func getMyTransactionsPaged({ page: Nat; pageSize: Nat }) : async {
    listSize: Nat;
    dataList: [Transaction];
    dataPage: Nat;
  } {
    var itemList = Buffer.Buffer<Transaction>(0);

    for ((id,tx) in Iter.toArray(transactionToData.entries()).vals()) {
      if (Principal.equal(tx.from, caller) or Principal.equal(tx.to, caller)) {
        itemList.add(tx);
      };
    };

    let (pagedItems, total) = Types.paginate(Buffer.toArray(itemList), page, pageSize);

    {
      listSize = total;
      dataList = pagedItems;
      dataPage = page;
    }
  };


  //获取Canister的Cycles余额
  public query func getCycleBalance() : async Nat {
      Cycles.balance();
  };

   // 接收cycles的函数
  public func wallet_receive() : async { accepted: Nat } {
    let available = Cycles.available();
    let accepted = Cycles.accept<system>(available);
    return { accepted = accepted };
  };



  // // 记录NFT信息
  // public shared({ caller }) func nftSave(): async () {
  //   assert(Principal.equal(caller,ownerAdmin));
  //   var nftid = 0;
  //   for(funded in nftList.vals()){
  //       nftid :=nftid+1;
  //       let nft = {
  //           userID = funded.userID;
  //           level = funded.level;
  //           nftID = nftid;
  //           nftTxMap = [];
  //       };
  //       nftToData.add(nft);
  //       discordToData.put(caller,{funded.userID=funded.userID;discord="";creationTime=0});
  //   };
  // };

  // 获取某个用户拥有的 NFT 列表
  public query({ caller }) func getUserNFT(): async [Types.NFT] {
    // 使用 Iter.filter 然后转为数组
    let userNFTs = Iter.toArray<Types.NFT>(
      Iter.filter<Types.NFT>(
        nftToData.vals(),
        func (nft: Types.NFT): Bool {
          nft.userID == caller
        }
      )
    );

    return userNFTs;
  };

  // 查询登记记录
  public query({ caller }) func getDiscord(): async (?Types.Discord) {
    switch (discordToData.get(caller)) {
          case (null) null;
          case (?f) {
              return ?f;
          };
      };
  };


  // 登记记录
  public shared({ caller }) func setDiscord({discord:Text}): async (Bool) {
    switch (discordToData.get(caller)) {
          case (null) {
            false
          };
          case (?d) {
            discordToData.put(d.userID,
            {
              userID=d.userID;
              discord=discord;
              creationTime=Time.now()
            });
            true;
          };
      };
  };

  //获取全部记录详情
  public query({ caller }) func getDiscordAll():async  [(Principal, Types.Discord)] {
      assert(Principal.equal(caller,ownerAdmin));
      Iter.toArray(discordToData.entries());
  };

  //获取全部记录详情
  public query({ caller }) func getFundedAll():async [Types.NFT] {
      assert(Principal.equal(caller,ownerAdmin));
      Buffer.toArray(nftToData);
  };


  //备份数据
  private func saveAllData(): async () {
    let date = Int.toText(Time.now() / Types.second);
    await Types.backupData({data=Buffer.toArray(nftToData);chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [Types.NFT]) : async () { await SaveCanister.saveNftToSave({ date = d; dataList })}});
    await Types.backupData({data=Iter.toArray(listedNFTs.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, NFT_Registry)]) : async () { await SaveCanister.saveNFTsToSave({ date = d; dataList })}});
  };

  ignore Timer.recurringTimer<system>(#seconds 604800, saveAllData);

  //手动存储数据
  public shared({ caller }) func setSaveAllData({date:Text}): async () {
    assert(Principal.equal(caller,ownerAdmin));
    await Types.backupData({data=Buffer.toArray(nftToData);chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [Types.NFT]) : async () { await SaveCanister.saveNftToSave({ date = d; dataList })}});
    await Types.backupData({data=Iter.toArray(listedNFTs.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, NFT_Registry)]) : async () { await SaveCanister.saveNFTsToSave({ date = d; dataList })}});
  };

};