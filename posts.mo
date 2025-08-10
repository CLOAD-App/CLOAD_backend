import Text "mo:base/Text";
import Int "mo:base/Int";
import HashMap "mo:base/HashMap";
import Time "mo:base/Time";

import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Types "types";
import User "user";

module { 

  // Post
  public type Posts = {
    postsID: Text; // Post ID
    user: Types.UserBasic; // User information
    content: Text; // Post content
    likes: [Principal]; // Likes
    mediaContent: Text; // Attached content
    mediaType: MediaType; // Attached content type
    createTime: Int; // Publish time
    replies: [Text]; // Reply list
    parentTweetId: Text; // Parent tweet ID
    isActive: Bool;
  };

  // Attached content type
  public type MediaType = {
    #Image; // Image
    #Item; // Item
    #Url; // Link
    #User; // User
    #Null; // None
  };

  // Create post
  public func setPosts(
    postsToData: HashMap.HashMap<Text, Posts>, postsID: Text, user: Types.UserBasic, content: Text, likes: [Principal], 
    mediaContent: Text, mediaType: MediaType, replies: [Text], parentTweetId: Text
  ): () {
      // Check if the post already exists
    switch (postsToData.get(postsID)) { 
      case (null) {
        postsToData.put(postsID, {
            postsID; // Post ID
            user; // User information
            content; // Post content
            likes; // Likes
            mediaContent; // Attached content
            mediaType; // Attached content type
            createTime = Time.now(); // Publish time
            replies; // Reply list
            parentTweetId; // Parent tweet ID
            isActive = true;
        });
      }; 
      case (_) {}; 
    };  
  };

  // Delete post
  public func removePosts(
    postsToData: HashMap.HashMap<Text, Posts>, postsID: Text
  ): () {
     switch (postsToData.get(postsID)) { 
        case (null) {}; 
        case (?p) {
          postsToData.put(postsID, {p with isActive = false});
          // Get parent details and update reply list
          switch (postsToData.get(p.parentTweetId)) { 
            case (null) {}; 
            case (?post) {
              // Remove the ID from the parent's reply list
              updateReplies(postsToData, post.postsID, Array.filter<Text>(post.replies, func x = x != p.postsID));
            }; 
          };
        }; 
      };    
  };

  // Update reply list
  public func updateReplies(
    postsToData: HashMap.HashMap<Text, Posts>, postsID: Text, replies: [Text]
  ): () {
     switch (postsToData.get(postsID)) { 
        case (null) {}; 
        case (?p) {
          postsToData.put(postsID, {p with replies});
        }; 
      };    
  };

  // Update like information
  public func updatePostsLikes(
    postsToData: HashMap.HashMap<Text, Posts>, postsID: Text, likes: [Principal]
  ): () {
     switch (postsToData.get(postsID)) { 
        case (null) {}; 
        case (?p) {
          postsToData.put(postsID, {p with likes});
        }; 
      };    
  };

}
