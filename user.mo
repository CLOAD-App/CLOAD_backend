import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Bool "mo:base/Bool";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";

import Types "types";

  /*
  * User related operations
  */

module {

  // User
  public type User = {
    userID: Principal; // User ID
    sha256ID:Text; // Encrypted ID
    name: Text; // Username
    desc: Text; // User profile
    address: Text; // Address
    avatarURL: Text; // Avatar URL
    backgroundURL: Text; // Background URL
    twitterURL: Text; // Twitter URL
    emailURL: Text; // Email URL
    cyclesBalance:Int; // Available Cycles balance
    lastLoginTime: Int; // Last login time
    creationTime:Int; // Join time
    role:Types.UserRole; // User role
    protocol:Bool; // User agreement
    isActive:Bool; // Active status
  };



  public type UserFollowBasic = {
    userID: Principal; // User ID
    sha256ID:Text; // Encrypted ID
    name: Text; // Username
    avatarURL: Text; // Avatar URL
    desc: Text; // User profile
    isFollow:Bool; // Return value
  };


  public type UserFollow = {
    userID: Principal; // User ID
    follows: [UserFollowBasic]; // Users I follow
    followers: [UserFollowBasic]; // Users following me
  };


  // Create user: username defaults to sha256ID, other info empty
  public func createUser(userToData:HashMap.HashMap<Principal, User>,caller:Principal,sha256ID:Text,name:Text) : () {
    switch (userToData.get(caller)) {
      case null {
        let newUser = {
              userID = caller; // User ID
              sha256ID;
              name; // Username
              desc=""; // User profile
              address=""; // Address
              avatarURL="https://upcdn.io/W142iHH/raw/uploads/2024/09/01/4kNBCjVT7f-file.txt"; // Avatar URL
              backgroundURL=""; // Background URL
              twitterURL=""; // Twitter URL
              emailURL=""; // Email URL
              cyclesBalance=500000000000; // Available Cycles balance
              role=#User;
              lastLoginTime = Time.now(); // Last login time
              creationTime = Time.now();
              protocol=false;
              isActive=true;
            };
         userToData.put(caller, newUser);
      };
      case (_) {}
    }
  };

  // Update user information
  public func upDateUserDetail(userToData:HashMap.HashMap<Principal, User>, 
    caller: Principal,name:Text,desc:Text,address:Text,
    avatarURL:Text,backgroundURL:Text,
    twitterURL:Text,emailURL:Text) : () {
    switch (userToData.get(caller)) {
      case null {};
      case (?u) {
        userToData.put(caller, { u with name;desc;address;avatarURL;backgroundURL;twitterURL;emailURL});
      }
    }
  };

  // Update user cycles balance
  public func upDateUserCycles(userToData:HashMap.HashMap<Principal, User>, 
    caller: Principal,cyclesBalance:Int) : () {
    switch (userToData.get(caller)) {
      case null {};
      case (?u) {
        userToData.put(caller, { u with cyclesBalance});
      }
    }
  };

  // Update user role (owner)
  public func upDateUserRole(userToData:HashMap.HashMap<Principal, User>, 
    caller: Principal,role:Types.UserRole) : () {
    switch (userToData.get(caller)) {
      case null {};
      case (?u) {
        userToData.put(caller, { u with role});
      }
    }
  };

}