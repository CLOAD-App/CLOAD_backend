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

import Types "types";

shared ({caller = owner}) actor class Canister() = this {
  let ownerAdmin :Principal = Principal.fromText("");
  public type Standard = {
    #ICRC7; 
    #EXT; 
    #DIP721; 
  };

  public type NFT_Types = {
    #Listed; 
    #Delist; 
    #Buy; 
  };
  // Collection data structure
  type Collection = {
    id: Text;                   // Unique ID of the Collection, e.g., canister ID or slug
    symbol: Text;               // Symbol
    name: Text;                 // Display name (e.g., CLOAD Genesis)
    description: Text;          // Description (supports multiline Markdown)
    logo: Text;                 // Icon link (recommended square 512x512)
    banner: Text;              // Banner image (homepage large image)
    creator: Principal;         // Creator identity (or contract deployer)
    nft_canister: Principal;    // Corresponding NFT canister ID
    total_supply: Nat;         // Total supply (optional)
    standard: [Standard];          // Standard, e.g., "ICRC-7" / "EXT" / "DIP721"
    created_at: Int;            // Timestamp
    verified: Bool;             // Whether verified
    categories: [Text];         // Category tags 
    royalty: Nat;              // Royalty percentage 
    currency: [Types.Tokens];   // Default currency 
    nft: [Text];               // Default currency 
    listed: Bool;               // Whether listed on the market
    social_links: {
      website: ?Text;           // Official website
      twitter: ?Text;           // Twitter link
      discord: ?Text;           // Discord link
      telegram: ?Text;          // Telegram link
      github: ?Text;            // GitHub link
      medium: ?Text;            // Medium link
    };
    metaMap: [{key: Text; match: Text; filter: Bool}]; // Metadata
  };

  // NFT data structure
  type NFT_Registry = {
    reg_id: Text;
    token_id: Nat; // Unique identifier for the NFT
    collection_id: Text;   // Associated Collection
    nft_canister: Principal;    // Corresponding NFT canister ID
    seller: Principal; // Seller identity
    owner: Principal; // Current owner identity
    price: Nat; // In the smallest unit of ICRC Token
    currency: Types.Tokens; 
    created_at: Int; // Creation timestamp
    status: Types.Status; 
    expiration: ?Int; // Optional delisting time
    isActive: Bool;
  };

  // Transaction record
  type Transaction = {
    transactionID: Text; // Unique identifier for the transaction record
    types: NFT_Types; // Type of transaction record
    reg_id: Text; // Unique registration identifier for the NFT
    token_id: Nat; // Unique identifier for the NFT
    collection_id: Text; // Associated Collection
    from: Principal; // Seller identity
    to: Principal; // Buyer identity
    price: Nat; // Transaction price
    currency: Types.Tokens; // Currency type used
    timestamp: Int; // Transaction timestamp
  };

  // Collection list
  private stable var collectionList_s: [(Text, Collection)] = [];
  private let collectionList = HashMap.fromIter<Text, Collection>(collectionList_s.vals(), 0, Text.equal, Text.hash);

  // Listed NFT list
  private stable var listedNFTs_s: [(Text, NFT_Registry)] = [];
  private let listedNFTs = HashMap.fromIter<Text, NFT_Registry>(listedNFTs_s.vals(), 0, Text.equal, Text.hash);

  // Transaction list
  private stable var transactionToData_s: [(Text, Transaction)] = [];
  private let transactionToData = HashMap.fromIter<Text, Transaction>(transactionToData_s.vals(), 0, Text.equal, Text.hash);

  // Discord information
  private stable var discordToData_s: [(Principal, Types.Discord)] = [];
  private let discordToData = HashMap.fromIter<Principal, Types.Discord>(discordToData_s.vals(), 0, Principal.equal, Principal.hash);

  // Funded information
  private stable var nftToData_s: [Types.NFT] = [];
  private let nftToData: Buffer.Buffer<Types.NFT> = Types.fromArray(nftToData_s);

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
    createNftTrade: shared ({transactionID: Text; from: Principal; to: Principal; price: Nat; token: Types.Tokens; royalty: Nat; creator: Principal}) -> async Result.Result<Text, Text>;
  };
  let center: CenterCanister = actor("yffxi-vqaaa-aaaak-qcrnq-cai");

  /*
  * Market Related
  */

  // Register NFT
  public shared({ caller }) func registerCollection({newCol: Collection}): async () {
    assert(Principal.equal(caller, ownerAdmin)); // Only admin can call

    switch (collectionList.get(newCol.id)) {
      case null {
        // Add new
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
          metaMap = newCol.metaMap; // Metadata
        };
        collectionList.put(fresh.id, fresh);
      };
      case (_) {};
    };
  };

  // Update NFT
  public shared({ caller }) func updataCollection({id: Text; creator: Principal; logo: Text; description: Text; banner: Text; nft: [Text];}): async () {
    assert(Principal.equal(caller, ownerAdmin)); // Only admin can call
    switch (collectionList.get(id)) {
      case null {};
      case (?c) {
        // Update specified fields
        let updated = {
          c with
          creator;
          description;
          logo;
          banner;
          nft;
        };
        collectionList.put(c.id, updated);
      };
    };
  };

  // Get details of a specific Collection
  public query func getCollection({id: Text}) : async ?Collection {
    collectionList.get(id)
  };

  // Get all Collection list
  public query func getAllCollections() : async [Collection] {
    Iter.toArray(collectionList.vals())
  };

  // Batch transfer NFTs (ICRC7) from Canister to external
  private func nft_transfer_batch({args: [{ to: Principal; token_id: Nat }]; canister: Text}) : async [Bool] {
    let Icrc7_Api: Types.Icrc7 = actor(canister);

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
    // Iterate through each result
    var results: [Bool] = [];
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

  // NFT transfer from Canister to external
  private func nft_transfer({to: Principal; token_id: Nat; canister: Text}) : async (Bool) {
    let Icrc7_Api: Types.Icrc7 = actor(canister);

    let nowNat64: Nat64 = Nat64.fromIntWrap(Time.now());

    let res = await Icrc7_Api.icrc7_transfer([{
        to = { owner = to; subaccount = null };
        token_id;
        memo = null;
        from_subaccount = null;
        created_at_time = ?nowNat64;
    }]);
    // Process transfer result
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

  // Verify if NFT belongs to the current Canister
  private func nft_verify({token_id: Nat; canister: Text}) : async (Bool) {
    let Icrc7_Api: Types.Icrc7 = actor(canister);
    let res = await Icrc7_Api.icrc7_owner_of([token_id]);
    switch (res[0]) {
      case (?ownerRecord) {
        if (Principal.equal(ownerRecord.owner, Principal.fromActor(this))) {
          true;
        } else {
          false;
        };
      };
      case null {
        // If null is returned, the NFT does not exist or is not owned by the current user
        false;
      };
    };
  };

  // Verify if NFT belongs to the specified user
  private func nft_verify_user({token_id: Nat; userID: Principal; canister: Text}) : async (Bool) {
    let Icrc7_Api: Types.Icrc7 = actor(canister);
    let res = await Icrc7_Api.icrc7_owner_of([token_id]);
    switch (res[0]) {
      case (?ownerRecord) {
        if (Principal.equal(ownerRecord.owner, userID)) {
          true;
        } else {
          false;
        };
      };
      case null {
        // If null is returned, the NFT does not exist or is not owned by the current user
        false;
      };
    };
  };

  // Register NFT (not enabled)
  public shared({ caller }) func regListedNFT({nft: NFT_Registry}) : async (Bool) {
    assert(false); 
    switch (listedNFTs.get(nft.reg_id)) {
      case null {
        // Verify if the NFT belongs to the current user
        if (await nft_verify_user({token_id = nft.token_id; userID = caller; canister = nft.collection_id})) {
          // Check if the NFT is already registered
          for ((id,nfts) in Iter.toArray(listedNFTs.entries()).vals()) {
            if (nfts.collection_id == nft.collection_id and nfts.token_id == nft.token_id and nfts.isActive) {
             // If it exists, update status to inactive
                let updatedNFT: NFT_Registry = {
                  nfts with
                  isActive = false;
                };
              listedNFTs.put(nft.reg_id, updatedNFT);
            };
          }; 

          // Register NFT
          let newNFT: NFT_Registry = {
            reg_id = nft.reg_id;
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
          listedNFTs.put(nft.reg_id, newNFT);
          true
        } else {
          false;
        };
      };
      case (?nft) {
        false
      };
    };
  };

  // List NFT, add new record (not enabled)
  public shared({ caller }) func upsertListedNFT({reg_id: Text; activityID: Text;}) : async () {
    assert(false); 
    switch (listedNFTs.get(reg_id)) {
      case null {};
      case (?nft) {
        // Verify if the platform already holds the NFT
        if (await nft_verify({token_id = nft.token_id; canister = nft.collection_id})) {
          assert(Principal.equal(caller, nft.seller));
          await addTransaction({transactionID = activityID; reg_id = nft.reg_id; to = Principal.fromActor(this); types = #Listed});
        };
      };
    };
  };

  // NFT update operation
  public shared({ caller }) func updateNFT({nft: NFT_Registry}) : async (Bool) {
    switch (listedNFTs.get(nft.reg_id)) {
      case null {false};
      case (?n) {
        // Update NFT, only the original seller can modify certain fields
        assert(Principal.equal(caller, nft.seller));
        let updatedNFT: NFT_Registry = {
          n with
          price = nft.price;
          expiration = nft.expiration;
        };
        listedNFTs.put(n.reg_id, updatedNFT);
        true
      };
    };
  };

  // Delist an NFT
  public shared({ caller }) func unlistNFT({reg_id: Text; activityID: Text}) : async Bool {
    switch (listedNFTs.get(reg_id)) {
      case (null) return false;
      case (?nft) {
        // Only the seller can delist
        if (not Principal.equal(nft.seller, caller)) return false;
        // Delist operation
        // Call Canister to transfer NFT back to the original owner
        if (await nft_transfer({to = nft.seller; token_id = nft.token_id; canister = nft.collection_id})) {
          // Update NFT status
          let updatedNFT: NFT_Registry = {nft with isActive = false; status = #Failed};
          listedNFTs.put(nft.reg_id, updatedNFT);
          await addTransaction({transactionID = activityID; reg_id = nft.reg_id; to = nft.seller; types = #Delist});
          true
        } else {
          false;
        }
      };
    };
  };

  // Buy NFT
  public shared ({ caller }) func buyNFT({ reg_id: Text }) : async Result.Result<Bool, Text> {
    switch (listedNFTs.get(reg_id)) {
      case (null) {
        return #err("NFT does not exist or is not listed");
      };
      case (?nft) {
        if (nft.isActive == false) {
          return #err("This NFT has been removed from the market or is unavailable");
        };
        if (Principal.equal(nft.seller, caller)) {
          return #err("Can't buy your own NFT");
        };
        switch (collectionList.get(nft.collection_id)) {
          case (null) {
            return #err("NFT collection does not exist");
          };
          case (?c) {
            // (Optional) Execute ICRC token transfer logic, omitted here
            let transferResult = await center.createNftTrade({ 
              transactionID = reg_id;
              from = caller;
              to = nft.seller;
              price = nft.price;
              token = #ICP;
              royalty = c.royalty;
              creator = c.creator; // Pass creator ID
            });
            switch (transferResult) {
                case (#ok(_)) {
                  // Call Canister to transfer NFT to the buyer
                    if (await nft_transfer({to = caller; token_id = nft.token_id; canister = nft.collection_id})) {
                      // Update NFT status
                      let updatedNFT: NFT_Registry = {nft with isActive = false; status = #Succes};
                      listedNFTs.put(nft.reg_id, updatedNFT);
                      // Create transaction record
                      await addTransaction({transactionID = reg_id; reg_id = nft.reg_id; to = caller; types = #Buy});
                      return #ok(true);
                    } else {
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

  // Get all NFT list for a specific Collection (paged)
  public composite query func getNFTsByCollectionPaged({ collection_id: Text}) : async [NFT_Registry] {
    var list = Buffer.Buffer<NFT_Registry>(0);

    let Icrc7_Api: Types.Icrc7 = actor(collection_id);
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

  // Get all NFT list for a specific Collection owned by me
  public composite query({ caller }) func getNFTsByCollectionMe({ collection_id: Text}) : async [NFT_Registry] {
    var list = Buffer.Buffer<NFT_Registry>(0);
    // Get NFTs held by the Canister
    let Icrc7_Api: Types.Icrc7 = actor(collection_id);
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

  // Get details of a specific NFT
  public query func getNft({reg_id: Text}) : async ?NFT_Registry {
    listedNFTs.get(reg_id)
  };

  // Get details of a specific NFT by token ID
  public composite query func getTokenNft({token_id: Nat; collection_id: Text;}) : async ?NFT_Registry {
    let Icrc7_Api: Types.Icrc7 = actor(collection_id);
    let tokens = await Icrc7_Api.icrc7_tokens_of({ owner = Principal.fromActor(this); subaccount = null }, null, null);
    // Iterate through all listed NFTs
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

  // Get my listed NFTs (paged)
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

  // Create transaction record
  private func addTransaction({transactionID:Text;reg_id: Text;to: Principal;types:NFT_Types}) : async () {
    switch (transactionToData.get(transactionID)) {
      case null {
        switch (listedNFTs.get(reg_id)) {
          case (null) {};
          case (?nft) {
            // Check if the NFT is transferred from the current Canister
            var owner = Principal.fromActor(this);
            if (Principal.equal(to, Principal.fromActor(this))) {
              owner := nft.seller;
            };

            // Add new transaction record
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

  // Get all transaction records for a specific Collection (paged)
  public query func getTransactionsByCollectionPaged({ collection_id: Text; page: Nat; pageSize: Nat }) : async {
    listSize: Nat;
    dataList: [Transaction];
    dataPage: Nat;
  } {
    var itemList = Buffer.Buffer<Transaction>(0);

    for ((id,tx) in Iter.toArray(transactionToData.entries()).vals()) {
      if (tx.collection_id == collection_id) {
        itemList.add(tx);
      };
    };

    let sortedList = Array.sort(
      Buffer.toArray(itemList),
      func(a: Transaction, b: Transaction): Order.Order {
        // Timestamp from largest to smallest => newest first
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

  // Get all transaction records for a specific Collection and token ID (paged)
  public query func getTransactionsByCollectionAndTokenPaged({ collection_id: Text; token_id: Nat; page: Nat; pageSize: Nat }) : async {
    listSize: Nat;
    dataList: [Transaction];
    dataPage: Nat;
  } {
    var itemList = Buffer.Buffer<Transaction>(0);

    for ((id,tx) in Iter.toArray(transactionToData.entries()).vals()) {
      if (tx.collection_id == collection_id and tx.token_id == token_id) {
        itemList.add(tx);
      };
    };

    let sortedList = Array.sort(
      Buffer.toArray(itemList),
      func(a: Transaction, b: Transaction): Order.Order {
        // Timestamp from largest to smallest => newest first
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

  // Get all transaction records related to the current user (as seller or buyer)
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

  // Get Canister's Cycles balance
  public query func getCycleBalance() : async Nat {
      Cycles.balance();
  };

  // Function to receive cycles
  public func wallet_receive() : async { accepted: Nat } {
    let available = Cycles.available();
    let accepted = Cycles.accept<system>(available);
    return { accepted = accepted };
  };

  // Synchronization
  public type SaveCanister = actor {
      saveNftToSave : shared ({date: Text; dataList: [Types.NFT]}) -> async ();
  };
  let SaveCanister: SaveCanister = actor("emmm6-kaaaa-aaaak-qlnwa-cai");

  // // Record NFT information
  // public shared({ caller }) func nftSave(): async () {
  //   assert(Principal.equal(caller, ownerAdmin));
  //   var nftid = 0;
  //   for(funded in nftList.vals()){
  //       nftid := nftid + 1;
  //       let nft = {
  //           userID = funded.userID;
  //           level = funded.level;
  //           nftID = nftid;
  //           nftTxMap = [];
  //       };
  //       nftToData.add(nft);
  //       discordToData.put(caller, {funded.userID=funded.userID; discord=""; creationTime=0});
  //   };
  // };

  // Get the list of NFTs owned by a specific user
  public query({ caller }) func getUserNFT(): async [Types.NFT] {
    // Use Iter.filter and convert to array
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

  // Query registration record
  public query({ caller }) func getDiscord(): async (?Types.Discord) {
    switch (discordToData.get(caller)) {
          case (null) null;
          case (?f) {
              return ?f;
          };
      };
  };

  // Register record
  public shared({ caller }) func setDiscord({discord: Text}): async (Bool) {
    switch (discordToData.get(caller)) {
          case (null) {
            false
          };
          case (?d) {
            discordToData.put(d.userID,
            {
              userID = d.userID;
              discord = discord;
              creationTime = Time.now()
            });
            true;
          };
      };
  };

  // Get all registration record details
  public query({ caller }) func getDiscordAll(): async [(Principal, Types.Discord)] {
      assert(Principal.equal(caller, ownerAdmin));
      Iter.toArray(discordToData.entries());
  };

  // Get all funded record details
  public query({ caller }) func getFundedAll(): async [Types.NFT] {
      assert(Principal.equal(caller, ownerAdmin));
      Buffer.toArray(nftToData);
  };

  // Backup data
  private func saveAllData(): async () {
    let date = Int.toText(Time.now() / Types.second);
    await Types.backupData({data=Buffer.toArray(nftToData); chunkSize=1000; date;
    saveFunc=func (d: Text, dataList: [Types.NFT]) : async () { await SaveCanister.saveNftToSave({ date = d; dataList })}});
  };

  ignore Timer.recurringTimer<system>(#seconds 604800, saveAllData);

  // Manually save data
  public shared({ caller }) func setSaveAllData({date: Text}): async () {
    assert(Principal.equal(caller, ownerAdmin));
    await Types.backupData({data=Buffer.toArray(nftToData); chunkSize=1000; date;
    saveFunc=func (d: Text, dataList: [Types.NFT]) : async () { await SaveCanister.saveNftToSave({ date = d; dataList })}});
  };

};
