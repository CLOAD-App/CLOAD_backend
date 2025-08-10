import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Bool "mo:base/Bool";
import Types "types";

  /*
  * User Related Operations
  */

module {

  // User
  public type User = {
    userID: Principal; // User ID
    sha256ID: Text; // Encrypted ID
    name: Text; // Username
    desc: Text; // User description
    address: Text; // Address
    avatarURL: Text; // User avatar URL
    backgroundURL: Text; // User background URL
    twitterURL: Text; // User Twitter URL
    emailURL: Text; // User email URL
    cyclesBalance: Int; // User available Cycles balance
    lastLoginTime: Int; // Last login time
    creationTime: Int; // Join time
    role: Types.UserRole; // User role
    protocol: Bool; // User agreement
    isActive: Bool; // Whether active
  };

  public type UserFollowBasic = {
    userID: Principal; // User ID
    sha256ID: Text; // Encrypted ID
    name: Text; // Username
    avatarURL: Text; // User avatar URL
    desc: Text; // User description
    isFollow: Bool; // Return value
  };

  public type UserFollow = {
    userID: Principal; // User ID
    follows: [UserFollowBasic]; // Users I follow
    followers: [UserFollowBasic]; // Users who follow me
  };

  // Create user with default username as sha256ID and other fields empty
  public func createUser(userToData: HashMap.HashMap<Principal, User>, caller: Principal, sha256ID: Text, name: Text): () {
    switch (userToData.get(caller)) {
      case null {
        let newUser = {
              userID = caller; // User ID
              sha256ID;
              name; // Username
              desc = ""; // User description
              address = ""; // Address
              avatarURL = "https://upcdn.io/W142iHH/raw/uploads/2024/09/01/4kNBCjVT7f-file.txt"; // User avatar URL
              backgroundURL = ""; // User background URL
              twitterURL = ""; // User Twitter URL
              emailURL = ""; // User email URL
              cyclesBalance = 500_000_000_000; // User available Cycles balance
              role = #User;
              lastLoginTime = Time.now(); // Last login time
              creationTime = Time.now();
              protocol = false;
              isActive = true;
            };
         userToData.put(caller, newUser);
      };
      case (_) {}
    }
  };

  // Update user details
  public func upDateUserDetail(userToData: HashMap.HashMap<Principal, User>, 
    caller: Principal, name: Text, desc: Text, address: Text,
    avatarURL: Text, backgroundURL: Text,
    twitterURL: Text, emailURL: Text): () {
    switch (userToData.get(caller)) {
      case null {};
      case (?u) {
        userToData.put(caller, { u with name; desc; address; avatarURL; backgroundURL; twitterURL; emailURL });
      }
    }
  };

  // Update user cycles balance
  public func upDateUserCycles(userToData: HashMap.HashMap<Principal, User>, 
    caller: Principal, cyclesBalance: Int): () {
    switch (userToData.get(caller)) {
      case null {};
      case (?u) {
        userToData.put(caller, { u with cyclesBalance });
      }
    }
  };

  // Update user role (owner only)
  public func upDateUserRole(userToData: HashMap.HashMap<Principal, User>, 
    caller: Principal, role: Types.UserRole): () {
    switch (userToData.get(caller)) {
      case null {};
      case (?u) {
        userToData.put(caller, { u with role });
      }
    }
  };

}