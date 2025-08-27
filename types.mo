import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Bool "mo:base/Bool";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Char "mo:base/Char";
import Random "mo:base/Random";
import SHA256 "Sha256";

 module { 
  
  public let cycles1MbFile : Nat = 2_100_000_000;
  public let cycles1Mb1DayFile : Nat = 11_000_000;
  public let cycles1T : Nat = 1_000_000_000_000;

  public let hour : Nat = 3_600_000_000_000;
  public let minute : Nat = 60_000_000_000;
  public let second : Nat = 1_000_000_000;
  public let millisecond : Nat = 1_000_000;


  public func genRandomSha256Id() : async Text {
    let entropy = await Random.blob();
    let hash = SHA256.fromBlob(#sha256, entropy);
    // 取前16字节（128位）
    let shortHash = Array.take(Blob.toArray(hash), 16);
    // 编码为32位十六进制字符串
    let hexId = SHA256.encode(shortHash);
    return hexId;
  };
  
  //数组转buffer
  public func fromArray<X>(elems: [X]): Buffer.Buffer<X> {
    let buff = Buffer.Buffer<X>(elems.size());
    for (elem in elems.vals()) {
      buff.add(elem)
    };
    buff
  };

   // 分页公共函数
  public func paginate<T>(data: [T], page: Nat, pageSize: Nat) : ([T], Nat) {
    // 要求页码从1开始
    let total :Nat = data.size();
    let startIndex :Nat= (page - 1) * pageSize;
    if (startIndex >= total) {
      // 如果起始索引超过总数，则返回空列表
      return ([], total);
    };
    let count : Nat = if ((total : Int) - (startIndex : Int) >= (pageSize : Int)) pageSize else (total - startIndex : Nat);
    let pageData = Array.subArray(data, startIndex, count);
    return (pageData, total);
  };

  //ID审查
  public func isLen20to32NoSymbol(s: Text, min:Int, max:Int) : Bool {
    let n = Text.size(s);
    if (n < min or n > max) { return false };

    for (c in s.chars()) {
      let x = Char.toNat32(c);
      if (
        not (
          (x >= 0x41 and x <= 0x5A) or   // 'A'..'Z'
          (x >= 0x61 and x <= 0x7A) or   // 'a'..'z'
          (x >= 0x30 and x <= 0x39)      // '0'..'9'
        )
      ) { return false };
    };
    true
  };

  //备份数据
  public func backupData<T>({
    data: [T];
    chunkSize: Nat;
    date: Text;
    saveFunc : (Text, [T]) -> async ()
  }) : async () {
    let total = data.size();
    if (total <= chunkSize) {
      await saveFunc(date, data);
    } else {
      let fullChunks = Nat.div(total, chunkSize);
      // 注意这里是 fullChunks - 1
      for (i in Iter.range(0, fullChunks - 1)) {
        let chunk = Array.subArray(data, i * chunkSize, chunkSize);
        await saveFunc(date, chunk);
      };
      let remainder = total % chunkSize;
      if (remainder != 0) {
        let chunk = Array.subArray(data, fullChunks * chunkSize, remainder);
        await saveFunc(date, chunk);
      };
    };
  };

  public type FileType = {
      #Photos; //图片
      #Documents; //文档
      #File; //文件
      #Videos; //视频
      #Apps; //应用
      #Others; //其他
      #Item; //项目
  };
  
  public type FileOrigin = {
      #Upload;
      #Disk; 
  };

  //加密硬盘
  public type CryptoDisk = {
    userID: Principal; // 用户ID
    file: FileStorageBasic; //文件关联ID
    creationTime:Int; //创建时间
    isPublic: Bool; // 是否已公开
    isShared: Bool; // 是否已共享
    sharedInfo: { link: Text; expireTime: Int }; // 分享信息
    isActive:Bool;
  };

  //用户信息
  public type UserBasic_old = {
    userID: Principal; // 用户ID
    sha256ID:Text; //加密ID
    name: Text; // 用户名
    avatarURL: Text; // 用户头像URL
    desc: Text; // 用户简介
  };
  
  public type UserBasic = {
    userID: Principal; // 用户ID
    sha256ID:Text; //加密ID
    name: Text; // 用户名
    avatarURL: Text; // 用户头像URL
    desc: Text; // 用户简介
    role:UserRole;//用户角色
    twitterURL: Text; // 用户推特地址
    backgroundURL: Text; // 用户背景URL
    emailURL: Text; // 用户邮箱地址
    creationTime:Int; //加入时间
    lastLoginTime: Int; // 最后登录时间
  };

  
  //文件储存 通过项目ID索引项目下的文件
  public type FileStorage = {
    fileID: Text; //文件ID
    itemID: Text; //作品ID
    name: Text; //文件名
    size: Int; // 文件分片大小
    fileType:FileType; //文件类型
    fileOrigin:FileOrigin;//文件来源
    userID: Principal;//上传者
    upDateTime:Int; //更新时间
    creationTime:Int; //创建时间
    shardFile:// 分片储存位置
      [{ 
        chunkID:Text;//分片ID
        canister:Principal; //文件储存Canister
      }];
    status: Status; //状态
  };

  //文件储存位置
  public type FilePath = {
    fileID: Text; //文件ID
    chunkID:Text;//分片ID
    canister:Principal; //文件储存Canister
  };

  //文件储存 通过项目ID索引项目下的文件
  public type FileStorageBasic = {
    fileID: Text; //文件ID
    itemID: Text; //项目ID
    name: Text; //文件名
    size: Int; // 文件分片大小
    fileType:FileType; //文件类型
    userID: Principal;//上传者
    creationTime:Int; //创建时间
    status: Status; //状态
  };

  //收藏
  public type Favorites = {
    userID: Principal; // 用户ID
    favoritesList:// 用户收藏列表
    [(itemID:Text,
        { 
        userID: Principal; // 作者ID
        itemID:Text; // 作品ID
        time:Int; // 收藏时间
        }
    )];
  };

  //评分
  public type Rating = {
    itemID:Text; //项目ID
    ratingList:// 用户评分列表
    [(userID: Principal, // 用户ID
        { 
        rating:Float; // 评分
        comment:Text; //评论
        dislike:Int; //赞
        like:Int; //踩
        time:Int; // 时间
        }
    )];
  };

  //评分返回列表类型
  public type RatingList = { 
      rating:Float;
      comment:Text;
      time:Int;
      name:Text;
      avatarURL:Text;
  };

  public type CyclesRecordEntry = {
    amount: Int; // 发生变动的数据
    operation:{  #Add;  #Sub; }; // 变动类型
    memo:Text; // 备注
    balance:Int; // 发送变动前的余额
    time:Int; // 时间
  };

  //Cycles记录
  public type CyclesRecord = {
    userID: Principal; // 用户ID
    records: [CyclesRecordEntry]; // 变动记录
  };

  //专栏
  public type Feature = {
    featureID:Text; //专栏ID
    title:Text;//专栏标题
    desc:Text;//专栏描述
    background:Text;//专栏背景
    coverImage:Text;//封面图片
    itemList:[Text];// 项目合集
  };

  //用户Discord信息
  public type Discord = {
    userID: Principal; // 用户ID
    discord:Text; //关联ID
    creationTime:Int; //创建时间
  };

  //用户Nft信息
  public type NFT = {
    nftID: Int; //NFT ID
    userID: Principal; // 用户ID
    level:Int; //等级
    nftTxMap: [Text]; //NFT转移记录
  };

  //状态信息
  public type Status = {
    #Succes; //成功
    #Failed; //失败
    #Default; //默认
  };

  //用户权限
  public type UserRole = {
    #User; //用户
    #Admin; //管理员
    #Project;//项目方
    #Owner; //创建者
  };
  
  public type IcrcAccount = {
    owner : Principal;
    subaccount : ?Blob;   // 32字节
  };
  
  public type Tokens = {
    #ICP;
    #CKBTC;
  };

  type Balance = Nat;
  
  public type AccountIdText = Text;
  public type SubaccountBlob = Blob;
  public type Account = { owner : Principal; subaccount : ?Blob };

  public type Blockchain = {
    #Bitcoin;
    #InternetComputer;
    #Ethereum;
    #Solana;
    #BNBChain;
    #Polkadot;
    #Polygon;
    #Avalanche;
  };

  public type Modules = {
    #Game;
    #App;
    #Resource;
    #Disk;
    #All;
  };

  public type CKBTC = {
      e8s : Nat64;
  };

  public type ICP = {
      e8s : Nat64;
  };

  public type Timestamp = {
      timestamp_nanos: Nat64;
  };

  public type AccountIdentifier = Blob;

  public type SubAccount = Nat;

  public type TxIndex = Nat;

  public type Memo = Nat64;

  public type TransferRequest = {
      memo: Nat64;
      from: Nat;
      to: AccountIdText;
      amount: Nat64;
      currency: Tokens;
  };

  type TransferArgs = {
    from_subaccount : ?Blob;
    to : Account;
    amount : Balance;
    fee : ?Balance;
    memo : ?Blob;
    created_at_time : ?Nat64;
  };

  type TimeError = {
    #TooOld;
    #CreatedInFuture : { ledger_time : Timestamp };
  };

  type TransferError = TimeError or {
    #BadFee : { expected_fee : Balance };
    #BadBurn : { min_burn_amount : Balance };
    #InsufficientFunds : { balance : Balance };
    #Duplicate : { duplicate_of : TxIndex };
    #TemporarilyUnavailable;
    #GenericError : { error_code : Nat; message : Text };
  };

  public type TransferResult = {
      #Ok : TxIndex;
      #Err : TransferError;
  };

  public type AccountBalanceArgs = {
      account: AccountIdentifier;
  };

  public type AccountBalanceICRC1 = {
      owner : Principal;
      subaccount : ?Blob
  };

  public type CanisterId = Principal;

  public type BlockHeight = Nat64;

  public type TransactionNotification = {
      from: Principal;
      from_subaccount: ?SubAccount;
      to: CanisterId;
      to_subaccount: ?SubAccount;
      block_height: BlockHeight;
      amount: ICP;
      memo: Memo;
  };

  public type Ledger = actor {
    icrc1_transfer(args : TransferArgs) : async TransferResult;
      icrc1_balance_of : shared query AccountBalanceICRC1 -> async Nat;

  };

  public type CyclesCanister = actor {
      get_icp_xdr_conversion_rate : shared query() -> async ({certificate:Blob; data:{xdr_permyriad_per_icp:Nat64; timestamp_seconds:Nat64}; hash_tree:Blob});
  };

  public type StoreCanister = actor {
      deleteFile : shared ({fileID:Text}) ->  ();
      clearFile : shared ({fileList:[Text]}) ->  ();
  };


  public type Icrc7TransferArgs = {
    to : { owner : Principal; subaccount : ?Blob };
    token_id : Nat;
    memo : ?Blob;
    from_subaccount : ?Blob;
    created_at_time : ?Nat64;
  };

  public type Icrc7 = actor {
    icrc7_transfer : shared [Icrc7TransferArgs] -> async [?TransferResult];
    icrc7_tokens_of : shared query ({ owner : Principal; subaccount : ?Blob }, ?Nat, ?Nat) -> async [Nat];
    icrc7_owner_of : shared query [Nat] -> async [?{ owner : Principal; subaccount : ?Blob }];

  };
 }
