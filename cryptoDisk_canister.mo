import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Bool "mo:base/Bool";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Cycles "mo:base/ExperimentalCycles";

import Item "item";
import Types "types";

shared ({caller = owner}) actor class Canister() = this {
  
  let ownerAdmin :Principal = Principal.fromText("");
  let center :Principal = Principal.fromText("yffxi-vqaaa-aaaak-qcrnq-cai");

  // Cycles record
  private stable var cryptoDiskToData_s: [(Text, Types.CryptoDisk)] = [];
  private let cryptoDiskToData = HashMap.fromIter<Text, Types.CryptoDisk>(cryptoDiskToData_s.vals(), 0, Text.equal, Text.hash);

  public type CenterCanister = actor {
      getCryptoDiskFile : query ({ fileID:Text }) -> async (?Types.FileStorage);
  };
  let centerApi:CenterCanister = actor("yffxi-vqaaa-aaaak-qcrnq-cai");

  system func preupgrade() {
    cryptoDiskToData_s := Iter.toArray(cryptoDiskToData.entries());
  };

  system func postupgrade() {
    cryptoDiskToData_s := [];
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

    // Create sharing record
    public shared({ caller }) func updateFileVisibility({
        fileID: Text;
        isPublic: ?Bool;
        isShared: ?Bool;
        sharedInfo: ?{ link: Text; expireTime: Int };
    }) : async Result.Result<Text, Text> {
    let now = Time.now();
        // Check if the record exists
        switch (cryptoDiskToData.get(fileID)) {
            case null {
                // Get file information
                switch (await centerApi.getCryptoDiskFile({ fileID })) {
                    case null {
                        return #err("File not found.");
                    };
                    case (?file) {
                        // Verify file owner
                        assert(Principal.equal(file.userID, caller)); 
                        let newDisk: Types.CryptoDisk = {
                            userID = caller;
                            file = file;
                            creationTime = now;
                            isPublic = Option.get(isPublic, false);
                            isShared = Option.get(isShared, false);
                            sharedInfo = Option.get(sharedInfo, { link = ""; expireTime = 0 });
                            isActive = true;
                        };
                        cryptoDiskToData.put(fileID, newDisk);
                        return #ok("New file record created with visibility settings.");
                    };
                };
                
            };

            // If exists, perform update
            case (?disk) {
                assert(Principal.equal(disk.userID, caller));

                let updatedDisk = {
                    disk with
                    isPublic = Option.get(isPublic, disk.isPublic);
                    isShared = Option.get(isShared, disk.isShared);
                    sharedInfo = Option.get(sharedInfo, disk.sharedInfo);
                };

                cryptoDiskToData.put(fileID, updatedDisk);
                return #ok("Visibility updated successfully.");
            };
        };
    };

    // Delete record
    public shared({ caller }) func deleteCryptoDiskRecord({fileID: Text}) : async () {
        switch (cryptoDiskToData.get(fileID)) {
            case null {};
            case (?disk) {
                assert(Principal.equal(caller, disk.userID)); 
                cryptoDiskToData.delete(fileID); 
            };
        };
    };

    // Get file visibility record status
    public shared({ caller }) func getCryptoDiskStatus({fileID: Text}) : async (?Types.CryptoDisk) {
        switch (cryptoDiskToData.get(fileID)) {
            case null null;
            case (?disk) {
                assert(Principal.equal(disk.userID, caller)); 
                ?disk
            };
        };
    };

    // Get user's public file list
    public query func getUserPublicFiles({ userID: Principal }) : async [(Text, Types.CryptoDisk)] {
        // Get all files
        let allFiles = Iter.toArray(cryptoDiskToData.entries());

        // Filter public files for the specified user
        let publicFiles = Array.filter<(Text, Types.CryptoDisk)>(allFiles,func (entry) {
            let f = entry.1;Principal.equal(f.userID, userID) and f.isActive and f.isPublic;
            }
        );

        // Sort (by creation time in descending order)
        Array.sort<(Text, Types.CryptoDisk)>(
            publicFiles,
            func (a, b) {
            if (a.1.creationTime > b.1.creationTime) {
                #less;
            } else if (a.1.creationTime < b.1.creationTime) {
                #greater;
            } else {
                #equal;
            }
            }
        );
    };

    // Get file index by shared link
    public composite query func getFileBySharedLink({ link: Text }) : async (?Item.Store) {
        for ((_, disk) in cryptoDiskToData.entries()) {
            if (
                disk.isShared and
                disk.sharedInfo.link == link and
                Time.now() < disk.sharedInfo.expireTime and
                disk.isActive
            ) {
            // Get real file index information
            let store = await centerApi.getCryptoDiskFile({ fileID = disk.file.fileID });
            return store;
            };
        };
        return null; // Not found or expired
    };

    // Get file index by public file
    public composite query func getFileByPublic({ fileID: Text }) : async (?Item.Store) {
        switch (cryptoDiskToData.get(fileID)) {
            case null {
                return null;
            };
            case (?disk) {
                if (disk.isPublic and disk.isActive) {
                    // Get real file index information
                    let store = await centerApi.getCryptoDiskFile({ fileID = disk.file.fileID });
                    return store;
                } else {
                    return null;
                };
            };
        };
    };
}
