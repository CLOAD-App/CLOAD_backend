import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Bool "mo:base/Bool";
import Array "mo:base/Array";
import Iter "mo:base/Iter";

module { 
  
  public let cycles1MbFile: Nat = 2_100_000_000;
  public let cycles1Mb1DayFile: Nat = 11_000_000;
  public let cycles1T: Nat = 1_000_000_000_000;

  public let hour: Nat = 3_600_000_000_000;
  public let minute: Nat = 60_000_000_000;
  public let second: Nat = 1_000_000_000;
  public let millisecond: Nat = 1_000_000;

  // Convert array to buffer
  public func fromArray<X>(elems: [X]): Buffer.Buffer<X> {
    let buff = Buffer.Buffer<X>(elems.size());
    for (elem in elems.vals()) {
      buff.add(elem)
    };
    buff
  };

  // Pagination utility function
  public func paginate<T>(data: [T], page: Nat, pageSize: Nat): ([T], Nat) {
    // Page starts from 1
    let total: Nat = data.size();
    let startIndex: Nat = (page - 1) * pageSize;
    if (startIndex >= total) {
      // If start index exceeds total, return empty list
      return ([], total);
    };
    let count : Nat = if ((total : Int) - (startIndex : Int) >= (pageSize : Int)) pageSize else (total - startIndex : Nat);
    let pageData = Array.subArray(data, startIndex, count);
    return (pageData, total);
  };

  // Backup data
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
      #Photos; // Photos
      #Documents; // Documents
      #File; // File
      #Videos; // Videos
      #Apps; // Apps
      #Others; // Others
      #Item; // Folders
  };

  public type FileOrigin = {
      #Upload;
      #Disk; 
  };
  // Crypto disk
  public type CryptoDisk = {
    userID: Principal; // User ID
    file: FileStorageBasic; // File associated ID
    creationTime: Int; // Creation time
    isPublic: Bool; // Whether public
    isShared: Bool; // Whether shared
    sharedInfo: { link: Text; expireTime: Int }; // Sharing information
    isActive: Bool;
  };

  // User information (old)
  public type UserBasic_old = {
    userID: Principal; // User ID
    sha256ID: Text; // Encrypted ID
    name: Text; // Username
    avatarURL: Text; // User avatar URL
    desc: Text; // User description
  };
  
  public type UserBasic = {
    userID: Principal; // User ID
    sha256ID: Text; // Encrypted ID
    name: Text; // Username
    avatarURL: Text; // User avatar URL
    desc: Text; // User description
    role: UserRole; // User role
    twitterURL: Text; // User Twitter URL
    backgroundURL: Text; // User background URL
    emailURL: Text; // User email URL
    creationTime: Int; // Join time
    lastLoginTime: Int; // Last login time
  };

  // File storage indexed by item ID
    public type FileStorage = {
    fileID: Text; 
    itemID: Text; 
    name: Text; 
    size: Int; 
    fileType:FileType; 
    fileOrigin:FileOrigin;
    userID: Principal;
    upDateTime:Int; 
    creationTime:Int;
    shardFile:
      [{ 
        chunkID:Text;
        canister:Principal; 
      }];
    status: Status; 
  };

  public type FilePath = {
    fileID: Text; 
    chunkID:Text;
    canister:Principal; 
  };

  public type FileStorageBasic = {
    fileID: Text; // File ID
    itemID: Text; // Item ID
    name: Text; // File name
    size: Int; // File chunk size
    fileType: FileType; // File type
    userID: Principal; // Uploader
    creationTime: Int; // Creation time
    status: Status; // Status
  };

  // Favorites
  public type Favorites = {
    userID: Principal; // User ID
    favoritesList: // User favorites list
    [(itemID: Text,
        { 
        userID: Principal; // Author ID
        itemID: Text; // Item ID
        time: Int; // Favorite time
        }
    )];
  };

  // Rating
  public type Rating = {
    itemID: Text; // Item ID
    ratingList: // User rating list
    [(userID: Principal, // User ID
        { 
        rating: Float; // Rating
        comment: Text; // Comment
        dislike: Int; // Dislike
        like: Int; // Like
        time: Int; // Time
        }
    )];
  };

  // Rating return list type
  public type RatingList = { 
      rating: Float;
      comment: Text;
      time: Int;
      name: Text;
      avatarURL: Text;
  };

  public type CyclesRecordEntry = {
    amount: Int; // Changed amount
    operation: { #Add; #Sub; }; // Change type
    memo: Text; // Memo
    balance: Int; // Balance before change
    time: Int; // Time
  };

  // Cycles record
  public type CyclesRecord = {
    userID: Principal; // User ID
    records: [CyclesRecordEntry]; // Change records
  };

  // Feature
  public type Feature = {
    featureID: Text; // Feature ID
    title: Text; // Feature title
    desc: Text; // Feature description
    background: Text; // Feature background
    coverImage: Text; // Cover image
    itemList: [Text]; // Item collection
  };

  // User Discord information
  public type Discord = {
    userID: Principal; // User ID
    discord: Text; // Associated ID
    creationTime: Int; // Creation time
  };

  // User NFT information
  public type NFT = {
    nftID: Int; // NFT ID
    userID: Principal; // User ID
    level: Int; // Level
    nftTxMap: [Text]; // NFT transfer records
  };

  // Status information
  public type Status = {
    #Succes; // Success
    #Failed; // Failed
    #Default; // Default
  };

  // User role
  public type UserRole = {
    #User; // User
    #Admin; // Admin
    #Project; // Project
    #Owner; // Owner
  };
  
  type Balance = Nat;
  
  public type AccountIdText = Text;
  public type SubaccountBlob = Blob;
  public type Account = { owner: Principal; subaccount: ?Blob };

  public type Tokens = {
      #ICP;
      #CKBTC;
  };
  
  public type CKBTC = {
      e8s: Nat64;
  };

  public type ICP = {
      e8s: Nat64;
  };

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
    from_subaccount: ?Blob;
    to: Account;
    amount: Balance;
    fee: ?Balance;
    memo: ?Blob;
    created_at_time: ?Nat64;
  };

  type TimeError = {
    #TooOld;
    #CreatedInFuture: { ledger_time: Timestamp };
  };

  type TransferError = TimeError or {
    #BadFee: { expected_fee: Balance };
    #BadBurn: { min_burn_amount: Balance };
    #InsufficientFunds: { balance: Balance };
    #Duplicate: { duplicate_of: TxIndex };
    #TemporarilyUnavailable;
    #GenericError: { error_code: Nat; message: Text };
  };

  public type TransferResult = {
      #Ok: TxIndex;
      #Err: TransferError;
  };

  public type AccountBalanceArgs = {
      account: AccountIdentifier;
  };

  public type AccountBalanceICRC1 = {
      owner: Principal;
      subaccount: ?Blob
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
    icrc1_transfer(args: TransferArgs): async TransferResult;
      icrc1_balance_of: shared query AccountBalanceICRC1 -> async Nat;
  };

  public type CyclesCanister = actor {
      get_icp_xdr_conversion_rate: shared query() -> async ({certificate: Blob; data: {xdr_permyriad_per_icp: Nat64; timestamp_seconds: Nat64}; hash_tree: Blob});
  };

  public type StoreCanister = actor {
      deleteFile: shared ({fileID: Text}) -> ();
      clearFile: shared ({fileList: [Text]}) -> ();
  };

  public type Icrc7TransferArgs = {
    to: { owner: Principal; subaccount: ?Blob };
    token_id: Nat;
    memo: ?Blob;
    from_subaccount: ?Blob;
    created_at_time: ?Nat64;
  };

  public type Icrc7 = actor {
    icrc7_transfer: shared [Icrc7TransferArgs] -> async [?TransferResult];
    icrc7_tokens_of: shared query ({ owner: Principal; subaccount: ?Blob }, ?Nat, ?Nat) -> async [Nat];
    icrc7_owner_of: shared query [Nat] -> async [?{ owner: Principal; subaccount: ?Blob }];
  };
}
