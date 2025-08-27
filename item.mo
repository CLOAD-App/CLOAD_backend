import Text "mo:base/Text";
import Nat "mo:base/Nat";
import HashMap "mo:base/HashMap";
import Time "mo:base/Time";
import Float "mo:base/Float";
import Bool "mo:base/Bool";
import Option "mo:base/Option";

import Types "types";


  /*
  * Project related operations
  */

module {
  public type Items = {
    name: Text; // Project name
    itemID: Text; // Project ID
    userID: Principal; // Publisher ID
    website:Text; // Website
    tags: [Text]; // Project tags
    types:[Text]; // Project types
    desc: Text; // Project description
    price: Nat; // Price
    version: Text; // Version
    origin:Text; // Source
    logo: Text; // Logo image
    coverImage: Text; // Cover image
    contentImage: [Text]; // Content images
    blockchain:Types.Blockchain; // Blockchain
    exposure: Int; // Exposure
    rating:Float; // Rating
    downloads: Int; // Downloads
    favorites: Int; // Favorites
    earnings: Nat; // Earnings
    status: Types.Status; // Status
    currency: Types.Tokens; // Currency type
    area:Types.Modules; // Area
    creationTime:Int; // Creation time
    upDataTime:Int; // Update time
    verified:Bool; // Verified
    isActive:Bool;
  };

  public type ItemBasic = {
    name: Text; // Project name
    itemID: Text; // Project ID
    userID: Principal; // Publisher ID
    coverImage: Text; // Cover image
    area:Text; // Area
  };

  // Create or update project information
  public func createOrUpdateItem(
    itemsToData: HashMap.HashMap<Text, Items>, itemID: Text,name: Text, userID: Principal, website: Text, tags: [Text],types: [Text],
    desc: Text, price: Nat, version: Text, logo: Text,coverImage: Text, contentImage: [Text],blockchain:Types.Blockchain, currency: Types.Tokens, area: Types.Modules
  ):(){
     switch (itemsToData.get(itemID)) {
        case (null) {
           itemsToData.put(itemID, {
            name;itemID;userID;
            website; tags; types; desc; price;version; origin=""; logo;
            coverImage; contentImage;blockchain;exposure=0;rating=0; downloads=0; 
            favorites=0; earnings=0; status=#Default; currency; area;
            creationTime = Time.now();
            upDataTime = Time.now();
            verified = false;
            isActive = true;
          });
        }; 
        case (?i) {
          itemsToData.put(itemID, { i with name;website;tags;types;desc;price;version;logo;coverImage;contentImage;blockchain;currency;upDataTime = Time.now();});
        }; 
      };    
  };

  // Update project status
  public func updateItemStatus(
    itemsToData: HashMap.HashMap<Text, Items>, itemID: Text,status: Types.Status
  ):(){
     switch (itemsToData.get(itemID)) { 
        case (null) {}; 
        case (?i) {
          itemsToData.put(itemID, { i with status});
        }; 
      };    
  };

  // Verify project
  public func updateItemVerified(
    itemsToData: HashMap.HashMap<Text, Items>, itemID: Text,verified: Bool
  ):(){
     switch (itemsToData.get(itemID)) { 
        case (null) {}; 
        case (?i) {
          itemsToData.put(itemID, { i with verified});
        }; 
      };    
  };


  // Update project downloads/favorites/earnings/rating after precondition checks
  public func updateItemDownloadsOrFavorites(itemsToData: HashMap.HashMap<Text, Items>, itemID: Text, downloads:?Int, favorites:?Int,earnings:?Nat,rating:?Float):(){
     switch (itemsToData.get(itemID)) { 
        case (null) {}; 
        case (?i) {
          let iDownloads =  Option.get(downloads, i.downloads);
          let iFavorites = Option.get(favorites, i.favorites);
          let iEarnings = Option.get(earnings, i.earnings);
          let iRating = Option.get(rating, i.rating);
          itemsToData.put(itemID, { i with downloads = iDownloads;favorites = iFavorites;earnings = iEarnings;rating = iRating});
        }; 
      };    
  };
  
  // Manage item: update tags, source, exposure and active status (admin)
  public func manageItem(itemsToData: HashMap.HashMap<Text, Items>, itemID: Text, tags:?[Text], origin: ?Text ,exposure: ?Int, isActive:?Bool):(){
     switch (itemsToData.get(itemID)) { 
        case (null) {}; 
        case (?i) {
          let iTags = Option.get(tags, i.tags);
          let iOrigin = Option.get(origin, i.origin);
          let iExposure = Option.get(exposure, i.exposure);
          let iIsActive = Option.get(isActive, i.isActive);
          itemsToData.put(itemID, { i with tags = iTags;origin = iOrigin;exposure = iExposure;isActive = iIsActive});
        }; 
      };    
  };
}
