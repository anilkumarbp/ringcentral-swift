//
//  Subscription.swift
//  RingCentral
//
//  Created by Anil Kumar BP on 2/10/16.
//  Copyright © 2016 Anil Kumar BP. All rights reserved.
//

import Foundation
import PubNub
import CryptoSwift

public class Subscription: NSObject, PNObjectEventListener {
    
  
    /// Fields of subscription
    public var events: [String: String] = [:]
    let platform: Platform!
    var pubnub: PubNub?
    var eventFilters: [String] = []
    var keepPolling: Bool = false
    var subscription: [String: AnyObject]?
    var function: ((arg: String) -> Void) = {(arg) in }
    let renewHandicapMs: Double = 2 * 60 * 1000;
    let pollInterval = 10 * 1000;
    var timeout: AnyObject? = AnyObject?()
    var eventNotification = Event<String,NSError>()

    
    
    /// Initializes a subscription with Platform
    ///
    /// - parameter platform:        Authorized platform
    public init(platform: Platform) {
        self.subscription = [:]
        self.platform = platform
        self.timeout = nil
        events["notification"] = "notification"
        events["removeSuccess"] = "removeSuccess"
        events["removeError"] = "removeError"
        events["renewSuccess"] = "renewSuccess"
        events["renewError"] = "renewError"
        events["subscribeSuccess"] = "subscribeSuccess"
        events["subscribeError"] = "subscribeError"
    }

    
    /// func subscribed
    ///
    /// @response: Bool    If the subcription is active
    public func subscribed() -> Bool {
        return (self.subscription!["id"] != nil && self.subscription!["deliveryMode"] != nil && self.subscription!["deliveryMode"]!["subscriberKey"] != nil && self.subscription!["deliveryMode"]!["address"] != nil)
    }
    
    /// func alive
    ///
    /// @response: Bool    If the subcription is active
    public func alive() -> Bool {
        return self.subscribed() && NSDate().timeIntervalSince1970 < self.expirationTime()
    }
    
    /// func expirationTime
    ///
    ///@response: Bool     If the subscription is active
    public func expirationTime() -> NSTimeInterval {
        return NSDate().timeIntervalSince1970 - self.renewHandicapMs
    }
    
    /// Returns PubNub object
    ///
    /// - returns: PubNub object
    public func getPubNub() -> PubNub? {
        return pubnub
    }
    
    /// Returns the platform
    ///
    /// - returns: Platform
    public func getPlatform() -> Platform {
        return platform
    }
    
    /// Adds event for PubNub
    ///
    /// - parameter events:          List of events to add
    /// - returns: Subscription
    public func addEvents(events: [String]) -> Subscription {
        for event in events {
            self.eventFilters.append(event)
        }
        return self
    }
    
    /// Sets events for PubNub (deletes all previous ones)
    ///
    /// - parameter events:          List of events to set
    /// - returns: Subscription
    public func setevents(events: [String]) -> Subscription {
        self.eventFilters = events
        return self
    }
    
    /// Returns all the event filters
    ///
    /// - returns: [String] of all the event filters
    private func getFullEventFilters() -> [String] {
        return self.eventFilters
    }
    
    
    /// Registers for a new subscription or renews an old one
    ///
    /// - parameter options:         List of options for PubNub
    public func register(options: [String: AnyObject] = [String: AnyObject](), completion: (inner: () throws -> (apiresponse: ApiResponse?,exception: NSException?)) -> Void) {
       
    do{
            
        if (alive()) {
            return try renew(options) {
                (inner: () throws -> (apiresponse: ApiResponse?,exception: NSException?)) in
            
            }
        } else {
            return try subscribe(options) {
                (inner: () throws -> (apiresponse: ApiResponse?,exception: NSException?)) in
            }
        }
    } catch let error as NSError {
           self.eventNotification.emit(self.events["renewError"]!, response: error)
           completion(inner: {throw err})
        }
    }
    
    
    /// Renews the subscription
    ///
    /// - parameter options:         List of options for PubNub
    public func renew(options: [String: AnyObject], completion: (inner: () throws -> (apiresponse: ApiResponse?,exception: NSException?)) -> Void) {
        
        do {
            if(!self.subscribed()) {
            throw NSError(domain: "No subscription", code: 400, userInfo: nil)
        }

            // include PUT instead of the apiCall
            try platform.put("/subscription/" + (self.subscription!["id"] as! String),
                body: [
                    "eventFilters": getFullEventFilters()
                ]) {
                    (apiresponse,exception) in
                    let dictionary = apiresponse!.getDict()
                    if let _ = dictionary["errorCode"] {
                        do {
                            
                                try self.subscribe(options) {
                                  (inner: () throws -> (apiresponse: ApiResponse?,exception: NSException?)) in
                                }
                            } catch let err {
                                self.eventNotification.emit(self.events["renewError"]!, response: err as NSError);
                                completion(inner: {throw err})
                            }
                    } else {
                        self.subscription!["expiresIn"] = dictionary["expiresIn"] as! NSNumber
                        self.subscription!["expirationTime"] = dictionary["expirationTime"] as! String
                    }
                }
        } catch let err {
            self.eventNotification.emit(self.events["renewError"]!, response: err as NSError)
            completion(inner: {throw err})
            self.reset()
            }
    }
    
    
    
    /// Subscribes to a channel with given events
    ///
    /// - parameter options:         Options for PubNub
    public func subscribe(options: [String: AnyObject], completion: (inner: () throws -> (apiresponse: ApiResponse?,exception: NSException?)) -> Void)  {
 
        do {
        // Create Subscription
        try platform.post("/subscription",
            body: [
                "eventFilters": getFullEventFilters(),
                "deliveryMode": [
                    "transportType": "PubNub",
                    "encryption": "false"
                ]
            ])  {
                    (apiresponse,exception) in
                
                    let dictionary = apiresponse!.getDict()
                    print("The subscription dictionary is :", dictionary, terminator: "")
                    self.setSubscriptions(dictionary)
                    self.subscribeAtPubnub()
               }
        } catch let err {
            self.reset()
            self.eventNotification.emit(self.events["subscribeError"]!,response: err as NSError)
            completion(inner: {throw err})
        }
    }
    
    
    /// Re - Subscribes to a channel with given events
    ///
    /// - parameter options:         Options for PubNub
    public func resubscribe(options: [String: AnyObject], completion: (inner: () throws -> (apiresponse: ApiResponse?,exception: NSException?)) -> Void)  {
        self.reset()
        self.setevents(self.eventFilters)
        do{
            return try subscribe(options) {
                (inner: () throws -> (apiresponse: ApiResponse?,exception: NSException?)) in
            }
        } catch let err {
            completion(inner: {throw err})
        }
    }
    
    
    /// Remove subscription
    public func remove(options: [String: AnyObject], completion: (inner: () throws -> (apiresponse: ApiResponse?,exception: NSException?)) -> Void) {
        
        do {

        
        if(!self.subscribed()) {
            
            throw NSError(domain: "No subscription", code: 400, userInfo: nil)
            
        }
        
       
            if let sub = subscription {
                // delete the subscription
                try platform.delete("/subscription/" + (sub["id"] as! String)) {
                    (r,e) in
                    self.subscription = nil
                    self.eventFilters = []
                    self.pubnub = nil
                self.reset()
//                self.eventNotification.emit(self.events["subscribeError"]!,response: r as NSError)
                }
            }
        } catch let err {
            self.eventNotification.emit(self.events["removeError"]!,response: err as NSError)
            completion(inner: {throw err})
        }
        


    }
    /// Set the subscription object returned from pubnub
    ///
    /// - parameter
    public func setSubscriptions(sub: [String:AnyObject]) -> Void {
        if sub.count < 0 {
            self.subscription = [String: AnyObject]()
        }
        else {
            self.subscription = sub
        }
    }
    
    /// Sets a method that will run after every PubNub callback
    ///
    /// - parameter functionHolder:      Function to be run after every PubNub callback
    public func setMethod(functionHolder: ((arg: String) -> Void)) {
        self.function = functionHolder
    }
    
    
//    /// Updates the subscription with the one passed in
//    ///
//    /// - parameter subscription:        New subscription passed in
//    private func updateSubscription(subscription: ISubscription) {
//        self.subscription = subscription
//    }
    
    /// Unsubscribes from subscription
    private func reset() {
        let channel = (subscription!["deliveryMode"]!["address"]) as! String
        pubnub?.unsubscribeFromChannelGroups([channel], withPresence: true)
    }
    
    /// Subscribes to a channel given the settings
    private func subscribeAtPubnub() {
        let config = PNConfiguration( publishKey: "", subscribeKey: (subscription!["deliveryMode"]!["subscriberKey"] as! String))
        self.pubnub = PubNub.clientWithConfiguration(config)
        self.pubnub?.addListener(self)
        self.pubnub?.subscribeToChannels([(subscription!["deliveryMode"]!["address"] as! String)], withPresence: true)
    }
    
    /// Notifies   -----> At the moment this is being handled in the client()
    private func notify() {
//        self.eventNotification.emit(self.events["notification"]!,)
    }
    
    /// Method that PubNub calls when receiving a message back from Subscription
    ///
    /// - parameter client:          The client of the receiver
    /// - parameter message:         Message being received back
    public func client(client: PubNub!, didReceiveMessage message: PNMessageResult!) {
        let base64Message = message.data.message as! String
        let base64Key = self.subscription!["deliveryMode"]!["encryptionKey"] as! String
        
        _ = [0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00] as [UInt8]
        _ = AES.randomIV(AES.blockSize)
        do {
            
            
            let decrypted = try AES(key: base64ToByteArray(base64Key), iv: [0x00], blockMode: .ECB).decrypt(base64ToByteArray(base64Message), padding: PKCS7())
            
            let endMarker = NSData(bytes: (decrypted as [UInt8]!), length: decrypted.count)
            if let str: String = NSString(data: endMarker, encoding: NSUTF8StringEncoding) as? String  {
                self.function(arg: str)
            } else {
                NSException(name: "Error", reason: "Error", userInfo: nil).raise()
            }
        } catch {
            print("error")
        }
    }
    
    /// Converts base64 to byte array
    ///
    /// - parameter base64String:        base64 String to be converted
    /// - returns: [UInt8] byte array
    private func base64ToByteArray(base64String: String) -> [UInt8] {
        let nsdata: NSData = NSData(base64EncodedString: base64String, options: NSDataBase64DecodingOptions(rawValue: 0))!
        var bytes = [UInt8](count: nsdata.length, repeatedValue: 0)
        nsdata.getBytes(&bytes, length: nsdata.length)
        return bytes
    }
    
    /// Converts byte array to base64
    ///
    /// - parameter bytes:               byte array to be converted
    /// - returns: String of the base64
    private func byteArrayToBase64(bytes: [UInt8]) -> String {
        let nsdata = NSData(bytes: bytes, length: bytes.count)
        let base64Encoded = nsdata.base64EncodedStringWithOptions([]);
        return base64Encoded;
    }
    
}

