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
import Timer "mo:base/Timer";

import Types "types";

shared ({caller = owner}) persistent actor class Canister() = this {

  transient let ownerAdmin :Principal = Principal.fromText("cfklm-6bmf5-bovci-hk76c-rue3p-axnze-w2tjc-vpfdk-wppgd-xj2yv-2qe");

  // cryptoDisk records
  private var cryptoDiskToData_s: [(Text, Types.CryptoDisk)] = [];
  private transient let cryptoDiskToData = HashMap.fromIter<Text, Types.CryptoDisk>(cryptoDiskToData_s.vals(), 0, Text.equal, Text.hash);

  public type CenterCanister = actor {
      getCryptoDiskFile : query ({ fileID:Text }) -> async (?Types.FileStorage);
  };
  transient let centerApi:CenterCanister = actor("yffxi-vqaaa-aaaak-qcrnq-cai");

  system func preupgrade() {
    cryptoDiskToData_s := Iter.toArray(cryptoDiskToData.entries());
  };

  system func postupgrade() {
    cryptoDiskToData_s := [];
  };

  // Synchronization
  public type SaveCanister = actor {
      saveCryptoDiskToSave : shared ({date:Text;dataList:[(Text, Types.CryptoDisk)]}) -> async ();
  };

  transient let SaveCanister : SaveCanister = actor("emmm6-kaaaa-aaaak-qlnwa-cai");


    
  public query func getCycleBalance() : async Nat {
      Cycles.balance();
  };

   // Function to receive cycles
  public func wallet_receive() : async { accepted: Nat } {
    let available = Cycles.available();
    let accepted = Cycles.accept<system>(available);
    return { accepted = accepted };
  };

    // Create share record
    public shared({ caller }) func updateFileVisibility({
        fileID: Text;
        isPublic: ?Bool;
        isShared: ?Bool;
        expireTime: ?Int;
    }) : async Result.Result<Text, Text> {
    let now = Time.now();
        // Check if record exists
        switch (cryptoDiskToData.get(fileID)) {
            case null {
                // Get file information
                switch (await centerApi.getCryptoDiskFile({ fileID })) {
                    case null {
                        return #err("File not found.");
                    };
                    case (?file) {
                        let link = await Types.genRandomSha256Id();
                        // Verify file owner
                        assert(Principal.equal(file.userID, caller)); 
                        let newDisk: Types.CryptoDisk = {
                            userID = caller;
                            file = file;
                            creationTime = now;
                            isPublic = Option.get(isPublic, false);
                            isShared = Option.get(isShared, false);
                            sharedInfo = { link ; expireTime = Option.get(expireTime, 0) };
                            isActive = true;
                        };
                        cryptoDiskToData.put(fileID, newDisk);
                        return #ok(link);
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
                    sharedInfo = { link = disk.sharedInfo.link; expireTime = Option.get(expireTime, disk.sharedInfo.expireTime) };
                };

                cryptoDiskToData.put(fileID, updatedDisk);
                return #ok(disk.sharedInfo.link);

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

        // Filter specified user's public files
        let publicFiles = Array.filter<(Text, Types.CryptoDisk)>(allFiles,func ((id,entry)) {
            let f = entry;Principal.equal(f.userID, userID) and f.isActive and f.isPublic;
            }
        );

        // Sort by update time descending
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

    // Get file index via link
    public composite query func getFileBySharedLink({ link: Text }) : async (?Types.FileStorage) {
        for ((_, disk) in cryptoDiskToData.entries()) {
            if (
                disk.isShared and
                disk.sharedInfo.link == link and
                Time.now() < disk.sharedInfo.expireTime and
                disk.isActive
            ) {
            // Fetch actual file index info
            let store = await centerApi.getCryptoDiskFile({ fileID = disk.file.fileID });
            return store;
            };
        };
        return null; // Not found or expired
    };

    // Get file index via public file
    public composite query func getFileByPublic({ fileID: Text }) : async (?Types.FileStorage) {
        switch (cryptoDiskToData.get(fileID)) {
            case null {
                return null;
            };
            case (?disk) {
                if (disk.isPublic and disk.isActive) {
                    // Fetch actual file index info
                    let store = await centerApi.getCryptoDiskFile({ fileID = disk.file.fileID });
                    return store;
                } else {
                    return null;
                };
            };
        };
    };


      // Backup data
  private func saveAllData(): async () {
    let date = Int.toText(Time.now() / Types.second);

    await Types.backupData({data=Iter.toArray(cryptoDiskToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Types.CryptoDisk)]) : async () { await SaveCanister.saveCryptoDiskToSave({ date = d; dataList })}});
  };

  ignore Timer.recurringTimer<system>(#seconds 604800, saveAllData);

  // Manually store data
  public shared({ caller }) func setSaveAllData({date:Text}): async () {
    assert(Principal.equal(caller,ownerAdmin));

    await Types.backupData({data=Iter.toArray(cryptoDiskToData.entries());chunkSize=1000;date;
    saveFunc=func (d : Text, dataList : [(Text, Types.CryptoDisk)]) : async () { await SaveCanister.saveCryptoDiskToSave({ date = d; dataList })}});
  };
}
