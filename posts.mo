import Text "mo:base/Text";
import Int "mo:base/Int";
import HashMap "mo:base/HashMap";
import Time "mo:base/Time";

import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Types "types";
module {

  // Posts data
  public type Posts = {
    postsID:Text; // Post ID
    user:Types.UserBasic;// User info
    content:Text;// Post content
    likes:[Principal];// Likes
    mediaContent:Text; // Additional content
    mediaType:MediaType;// Additional content type
    createTime:Int;// Publish time
    replies:[Text];// Replies list
    parentTweetId:Text;// Parent tweet ID
    isActive:Bool;
  };

  // Additional content types
  public type MediaType = {
    #Image; // Image
    #Item; // Project
    #Url; // Link
    #User; // User
    #NFT; // NFT
    #Null; // None
  };

  // Publish a post
  public func setPosts(
    postsToData: HashMap.HashMap<Text, Posts>, postsID: Text,user:Types.UserBasic, content: Text, likes:[Principal], 
    mediaContent: Text, mediaType: MediaType, replies: [Text], parentTweetId: Text
  ): () {
      // Check if the post already exists
    switch (postsToData.get(postsID)) {
      case (null) {
        postsToData.put(postsID, {
            postsID; // Post ID
            user; // User info
            content; // Post content
            likes; // Likes
            mediaContent; // Additional content
            mediaType; // Additional content type
            createTime=Time.now(); // Publish time
            replies; // Replies list
            parentTweetId; // Parent tweet ID
            isActive = true;
        });
      }; 
      case (_) {}; 
    };  
  };

  // Delete
  public func removePosts(
    postsToData: HashMap.HashMap<Text, Posts>, postsID: Text
  ):(){
     switch (postsToData.get(postsID)) { 
        case (null) {}; 
        case (?p) {
          postsToData.put(postsID, {p with isActive=false});
          // Fetch parent details and update replies
          switch (postsToData.get(p.parentTweetId)) {
            case (null) {}; 
            case (?post) {
              // Remove ID from parent's reply list
              updateReplies(postsToData,post.postsID,Array.filter<Text>(post.replies, func x = x != p.postsID));
            };
          };
        }; 
      };    
  };


  // Update replies list
  public func updateReplies(
    postsToData: HashMap.HashMap<Text, Posts>, postsID: Text,replies: [Text]
  ):(){
     switch (postsToData.get(postsID)) { 
        case (null) {}; 
        case (?p) {
          postsToData.put(postsID, {p with replies});
        };
      };
  };


  // Update like info
  public func updatePostsLikes(
    postsToData: HashMap.HashMap<Text, Posts>, postsID: Text,likes: [Principal]
  ):(){
     switch (postsToData.get(postsID)) { 
        case (null) {}; 
        case (?p) {
          postsToData.put(postsID, {p with likes});
        }; 
      };    
  };



}
