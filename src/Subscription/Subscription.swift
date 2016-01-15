//
//  Subscription.swift
//  src
//
//  Created by Anil Kumar BP on 11/20/15.
//  Copyright (c) 2015 Anil Kumar BP. All rights reserved.
//



import Foundation
import PubNub

public class Subscription: NSObject, PNObjectEventListener {
    
    public static var EVENT_NOTIFICATION: String = "notification"
    public static var EVENT_REMOVE_SUCCESS: String = "removeSuccess"
    public static var EVENT_RENEW_SUCCESS: String = "removeError"
    public static var EVENT_RENEW_ERROR: String = "renewError"
    public static var EVENT_SUBSCRIBE_SUCCESS: String = "subscribeSuccess"
    public static var EVENT_SUBSCRIBE_ERROR: String = "subscribeError"
    
    
    /// Fields of subscription
    let platform: Platform!
    var pubnub: PubNub?
    var eventFilters: [String] = []
    var _keepPolling: Bool = false
    var subscription: ISubscription?
    var function: ((arg: String) -> Void) = {(arg) in }
    
    
    /// Initializes a subscription with Platform
    ///
    /// :param: platform        Authorized platform
    public init(platform: Platform) {
        self.platform = platform
    }
    
    /// Structure holding information about how PubNub is delivered
    struct IDeliveryMode {
        var transportType: String = "PubNub"
        var encryption: Bool = false
        var address: String = ""
        var subscriberKey: String = ""
        var secretKey: String?
        var encryptionKey: String = ""
    }
    
    /// Structure holding information about the details of PubNub
    struct ISubscription {
        var eventFilters: [String] = []
        var expirationTime: String = ""
        var expiresIn: NSNumber = 0
        var deliveryMode: IDeliveryMode = IDeliveryMode()
        var id: String = ""
        var creationTime: String = ""
        var status: String = ""
        var uri: String = ""
    }
    
    /// Returns PubNub object
    ///
    /// :returns: PubNub object
    public func getPubNub() -> PubNub? {
        return pubnub
    }
    
    /// Returns the platform
    ///
    /// :returns: Platform
    public func getPlatform() -> Platform {
        return platform
    }
    
    /// Adds event for PubNub
    ///
    /// :param: events          List of events to add
    /// :returns: Subscription
    public func addEvents(events: [String]) -> Subscription {
        for event in events {
            self.eventFilters.append(event)
        }
        return self
    }
    
    /// Sets events for PubNub (deletes all previous ones)
    ///
    /// :param: events          List of events to set
    /// :returns: Subscription
    public func setevents(events: [String]) -> Subscription {
        self.eventFilters = events
        return self
    }
    
    /// Returns all the event filters
    ///
    /// :returns: [String] of all the event filters
    private func getFullEventFilters() -> [String] {
        return self.eventFilters
    }
    
    /// Registers for a new subscription or renews an old one
    ///
    /// :param: options         List of options for PubNub
    public func register(options: [String: AnyObject] = [String: AnyObject](), completion: (transaction: ApiResponse) -> Void) {
        if (isSubscribed()) {
            return renew(options) {
                (t) in
                completion(transaction: t)
            }
        } else {
            return subscribe(options) {
                (t) in
                completion(transaction: t)
            }
        }
    }
    
    /// Renews the subscription
    ///
    /// :param: options         List of options for PubNub
    public func renew(options: [String: AnyObject], completion: (transaction: ApiResponse) -> Void) {
        
        // include PUT instead of the apiCall
        platform.put("/subscription/" + subscription!.id,
            body: [
                "eventFilters": getFullEventFilters()
            ]) {
                (transaction,exception) in
                let dictionary = transaction!.getDict()
                if let error = dictionary["errorCode"] {
                    self.subscribe(options){
                        (t) in
                        completion(transaction: t)
                    }
                } else {
                    self.subscription!.expiresIn = dictionary["expiresIn"] as! NSNumber
                    self.subscription!.expirationTime = dictionary["expirationTime"] as! String
                }
        }
    }
    
    /// Subscribes to a channel with given events
    ///
    /// :param: options         Options for PubNub
    public func subscribe(options: [String: AnyObject], completion: (transaction: ApiResponse) -> Void) {
        
        // Create Subscription
        platform.post("/subscription",
            body: [
                "eventFilters": getFullEventFilters(),
                "deliveryMode": [
                    "transportType": "PubNub",
                    "encryption": "false"
                ]
            ])  {
                (transaction,exception) in
                
                let dictionary = transaction!.getDict()
                println("The subscription dictionary is :", dictionary)
                var sub = ISubscription()
                sub.eventFilters =      dictionary["eventFilters"] as! [String]
                self.eventFilters =     dictionary["eventFilters"] as! [String]
                sub.expirationTime =    dictionary["expirationTime"] as! String
                sub.expiresIn =         dictionary["expiresIn"] as! NSNumber
                sub.id =                dictionary["id"] as! String
                sub.creationTime =      dictionary["creationTime"] as! String
                sub.status =            dictionary["status"] as! String
                sub.uri =               dictionary["uri"] as! String
                self.subscription = sub
                var del = IDeliveryMode()
                var dictDelivery =      dictionary["deliveryMode"] as! NSDictionary
                del.transportType =     dictDelivery["transportType"] as! String
                del.encryption =        dictDelivery["encryption"] as! Bool
                del.address =           dictDelivery["address"] as! String
                del.subscriberKey =     dictDelivery["subscriberKey"] as! String
                del.secretKey =         dictDelivery["secretKey"] as? String
                del.encryptionKey =     dictDelivery["encryptionKey"] as! String
                self.subscription!.deliveryMode = del
                self.subscribeAtPubnub()
        }
    }
    
    /// Sets a method that will run after every PubNub callback
    ///
    /// :param: functionHolder      Function to be ran after every PubNub callback
    public func setMethod(functionHolder: ((arg: String) -> Void)) {
        self.function = functionHolder
    }
    
    /// Checks if currently subscribed
    ///
    /// :returns: Bool of if currently subscribed
    public func isSubscribed() -> Bool {
        if let sub = self.subscription {
            let dil = sub.deliveryMode
            return dil.subscriberKey != "" && dil.address != ""
        }
        return false
    }
    
    /// Emits events
    public func emit(event: String) -> AnyObject {
        return ""
    }
    
    
    
    /// Updates the subscription with the one passed in
    ///
    /// :param: subscription        New subscription passed in
    private func updateSubscription(subscription: ISubscription) {
        self.subscription = subscription
    }
    
    /// Unsubscribes from subscription
    private func unsubscribe() {
        if let channel = subscription?.deliveryMode.address {
            pubnub?.unsubscribeFromChannelGroups([channel], withPresence: true)
        }
        
        
        if let sub = subscription {
            // delete the subscription
            platform.delete("/subscription/" + sub.id) {
                (transaction) in
                self.subscription = nil
                self.eventFilters = []
                self.pubnub = nil
            }
        }
        
    }
    
    /// Subscribes to a channel given the settings
    private func subscribeAtPubnub() {
        let config = PNConfiguration( publishKey: "", subscribeKey: subscription!.deliveryMode.subscriberKey)
        self.pubnub = PubNub.clientWithConfiguration(config)
        self.pubnub?.addListener(self)
        self.pubnub?.subscribeToChannels([subscription!.deliveryMode.address], withPresence: true)
    }
    
    /// Notifies
    private func notify() {
        
    }
    
    /// Method that PubNub calls when receiving a message back from Subscription
    ///
    /// :param: client          The client of the receiver
    /// :param: message         Message being received back
    public func client(client: PubNub!, didReceiveMessage message: PNMessageResult!) {
        var base64Message = message.data.message as! String
        var base64Key = self.subscription!.deliveryMode.encryptionKey
        
        let key = [0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00] as [UInt8]
        let iv = Cipher.randomIV(AES.blockSize)
        let decrypted = AES(key: base64ToByteArray(base64Key), iv: [0x00], blockMode: .ECB)?.decrypt(base64ToByteArray(base64Message), padding: PKCS7())
        
        var endMarker = NSData(bytes: (decrypted as [UInt8]!), length: decrypted!.count)
        if let str: String = NSString(data: endMarker, encoding: NSUTF8StringEncoding) as? String  {
            self.function(arg: str)
        } else {
             NSException(name: "Error", reason: "Error", userInfo: nil).raise()
        }
    }
    
    /// Converts base64 to byte array
    ///
    /// :param: base64String        base64 String to be converted
    /// :returns: [UInt8] byte array
    private func base64ToByteArray(base64String: String) -> [UInt8] {
        let nsdata: NSData = NSData(base64EncodedString: base64String, options: NSDataBase64DecodingOptions(rawValue: 0))!
        var bytes = [UInt8](count: nsdata.length, repeatedValue: 0)
        nsdata.getBytes(&bytes, length: nsdata.length)
        return bytes
    }
    
    /// Converts byte array to base64
    ///
    /// :param: bytes               byte array to be converted
    /// :returns: String of the base64
    private func byteArrayToBase64(bytes: [UInt8]) -> String {
        let nsdata = NSData(bytes: bytes, length: bytes.count)
        let base64Encoded = nsdata.base64EncodedStringWithOptions(nil);
        return base64Encoded;
    }
    
    /// Converts a dictionary represented as a String into a NSDictionary
    ///
    /// :param: string              Dictionary represented as a String
    /// :returns: NSDictionary of the String representation of a Dictionary
    private func stringToDict(string: String) -> NSDictionary {
        var data: NSData = string.dataUsingEncoding(NSUTF8StringEncoding)!
        return NSJSONSerialization.JSONObjectWithData(data, options: nil, error: nil) as! NSDictionary
    }
}