import Cycles "mo:base/ExperimentalCycles";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Int "mo:base/Int";
import Bool "mo:base/Bool";
import Blob "mo:base/Blob";

import Prim "mo:⛔";

shared ({caller = owner}) actor class Canister() = this {

  public type FileChunkPath = {
      chunkID: Text; // Chunk ID
      fileID: Text; // File ID
      itemID: Text; // Item ID
      userID: Principal; // Uploader
      file: Blob; // File
      fileIndex: Nat; // File index
      creationTime: Int; // Creation time
  };

  private stable var storeToData_s: [(Text, FileChunkPath)] = [];
  private let storeToData = HashMap.fromIter<Text, FileChunkPath>(storeToData_s.vals(), 0, Text.equal, Text.hash);

  system func preupgrade() {
    storeToData_s := Iter.toArray(storeToData.entries());
  };
  system func postupgrade() {
    storeToData_s := [];
  };

  public type FileLedger = actor {
      uploadFileStore : shared ({userID: Principal; chunkID: Text; canister: Principal; fileID: Text}) ->  ();
      queryLicense : query ({fileID: Text; userID: Principal}) ->  async(Bool);
  };
  let fileLedgers: FileLedger = actor("yffxi-vqaaa-aaaak-qcrnq-cai");

  let centerCanister: Principal = Principal.fromText("yffxi-vqaaa-aaaak-qcrnq-cai");

  /*
  * Basic Queries
  */

  public query func getSize() : async Nat {
      Prim.rts_memory_size();
  };

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
  * File Operations
  */

  // Total size of file storage
  public query func getStoreSize(): async (Int) {
    Iter.toArray(storeToData.entries()).size()
  };

  // Upload file -- only file author
  public shared({caller}) func uploadFile({chunkID: Text; fileID: Text; itemID: Text; index: Nat; file: Blob}): async(Bool) {
    assert(Principal.isAnonymous(caller)==false);
    // Query license
    let license = await fileLedgers.queryLicense({fileID; userID=caller});
    switch(license) {
      case(false) {false};
      case(true) {
          storeToData.put(chunkID,{
            chunkID; // Chunk ID
            fileID; // File ID
            itemID; // Item ID
            userID = caller;
            file; // File
            fileIndex = index; // File index
            creationTime = Time.now(); // Creation time
          });

          uploadFileLicense({userID = caller; fileID; chunkID});
          true;
        };
    };
  };

  // Update Canister upload license
  public shared({ caller }) func uploadFileLicense({userID: Principal; fileID: Text; chunkID: Text}): () {
    assert(Principal.equal(caller, Principal.fromActor(this)));
    try {
      fileLedgers.uploadFileStore({fileID; chunkID; userID; canister=Principal.fromActor(this)});
    } catch (e : Error) {
      uploadFileLicense({userID; fileID; chunkID});
    };
  };

  // Download file
  public query func downloadFile({chunkID:Text}): async(?FileChunkPath) {
    // Get file list tuple
      switch(storeToData.get(chunkID)) {
        case (null) {null};
        case (?u) {
            ?u
        };
    };
  };

  // Query file by ChunkID
  public query func queryChunkID({chunkID: Text}): async(?{
      chunkID: Text; // Chunk ID
      fileID: Text; // File ID
      userID: Principal; // Uploader
      fileIndex: Nat; // File index
      creationTime: Int; // Creation time
  }) {
    // Get file list tuple
      switch(storeToData.get(chunkID)) {
        case (null) {null};
        case (?u) {
            ?u
        };
    };
  };

  // Delete storage
  public shared({ caller }) func deleteFile({fileID: Text}): async () { 
    if(Principal.equal(caller, centerCanister)){
        // Get file list tuple
      let storeToDataList = Iter.toArray(storeToData.entries());
       for((id,file) in storeToDataList.vals()){
          if(file.fileID == fileID){
              storeToData.delete(id)
          };
      };
    }
  };

  // Clear storage, remove files not in fileList
  public shared({ caller }) func clearFile({fileList: [Text]}): async () {  
    if(Principal.equal(caller, centerCanister)){
        // Get file list tuple
      let storeToDataList = Iter.toArray(storeToData.entries());
      for((id,file) in storeToDataList.vals()){
          let isfileID = Array.find<Text>(fileList, func x = x == file.chunkID);
          switch (isfileID) {
            case null {
               storeToData.delete(id)
            };
            case (_) {};
          }
      };
    }
  };

  // Delete all storage for an item
  public shared({ caller }) func deleteitemFile({itemID: Text}): async () {  
    if(Principal.equal(caller, centerCanister)){
      // Get file list tuple
      let storeToDataList = Iter.toArray(storeToData.entries());
     for((id,file) in storeToDataList.vals()){
        if(file.itemID == itemID){
            storeToData.delete(id)
        };
      };
    }
  };
};
