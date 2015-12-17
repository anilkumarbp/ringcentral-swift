//
//  Platform.swift
//  src
//
//  Created by Anil Kumar BP on 11/17/15.
//  Copyright (c) 2015 Anil Kumar BP. All rights reserved.
//

import Foundation

/// Platform used to call HTTP request methods.
public class Platform {
    
    // platform Constants
    public let ACCESS_TOKEN_TTL = "3600"; // 60 minutes
    public let REFRESH_TOKEN_TTL = "604800"; // 1 week
    public let TOKEN_ENDPOINT = "/restapi/oauth/token";
    public let REVOKE_ENDPOINT = "/restapi/oauth/revoke";
    public let API_VERSION = "v1.0";
    public let URL_PREFIX = "/restapi";
    
    
    // Platform credentials
    internal var auth: Auth
    internal var client: Client
    internal let server: String
    internal let appKey: String
    internal let appSecret: String
    internal var appName: String
    internal var appVersion: String
    
    
    /// Constructor for the platform of the SDK
    ///
    /// :param: appKey      The appKey of your app
    /// :param: appSecet    The appSecret of your app
    /// :param: server      Choice of PRODUCTION or SANDBOX
    public init(client: Client, appKey: String, appSecret: String, server: String, appName: String = "", appVersion: String = "") {
        self.appKey = appKey
        self.appName = appName != "" ? appName : "Unnamed"
        self.appVersion = appVersion != "" ? appVersion : "0.0.0"
        self.appSecret = appSecret
        self.server = server
        self.auth = Auth()
        self.client = client
        
    }
    
    
    // Returns the auth object
    ///
    public func returnAuth() -> Auth {
        return self.auth
    }
    
    /// func createUrl
    ///
    /// @param: path              The username of the RingCentral account
    /// @param: options           The password of the RingCentral account
    /// @response: ApiResponse    The password of the RingCentral account
    public func createUrl(path: String, options: [String: AnyObject]) -> String {
        var builtUrl = ""
        if(options["skipAuthCheck"] === true){
            builtUrl = builtUrl + self.server + path
            return builtUrl
        }
        builtUrl = builtUrl + self.server + self.URL_PREFIX + "/" + self.API_VERSION + path
        return builtUrl
    }
    
    /// Authenticates the user with the correct credentials
    ///
    /// :param: username    The username of the RingCentral account
    /// :param: password    The password of the RingCentral account
    public func login(username: String, ext: String, password: String) -> ApiResponse {
        let response = requestToken(self.TOKEN_ENDPOINT,body: [
            "grant_type": "password",
            "username": username,
            "extension": ext,
            "password": password,
            "access_token_ttl": self.ACCESS_TOKEN_TTL,
            "refresh_token_ttl": self.REFRESH_TOKEN_TTL
            ])
        self.auth.setData(response.getDict())
        return response
    }
    
    
    /// Refreshes the Auth object so that the accessToken and refreshToken are updated.
    ///
    /// **Caution**: Refreshing an accessToken will deplete it's current time, and will
    /// not be appended to following accessToken.
    public func refresh() -> ApiResponse {
        if(!self.auth.refreshTokenValid()){
            NSException(name: "Refresh token has expired", reason: "reason", userInfo: nil).raise()
        }
        let response = requestToken(self.TOKEN_ENDPOINT,body: [
            
            "refresh_token": self.auth.refreshToken(),
            "grant_type": "refresh_token",
            "access_token_ttl": self.ACCESS_TOKEN_TTL,
            "refresh_token_ttl": self.REFRESH_TOKEN_TTL
            ])
        self.auth.setData(response.getDict())
        return response
    }
    
    /// func inflateRequest ()
    ///
    /// @param: request     NSMutableURLRequest
    /// @param: options     list of options
    /// @response: NSMutableURLRequest
    ///FIXME Remove path parameter
    public func inflateRequest(path: String, request: NSMutableURLRequest, options: [String: AnyObject]) -> NSMutableURLRequest {
        var check = 0
        if options["skipAuthCheck"] == nil {
            ensureAuthentication()
            let authHeader = self.auth.tokenType() + " " + self.auth.accessToken()
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }

        return request
    }
    
    
    
    
    /// func sendRequest ()
    ///
    /// @param: request     NSMutableURLRequest
    /// @param: options     list of options
    /// @response: ApiResponse
    ///FIXME Remove path parameter
    public func sendRequest(request: NSMutableURLRequest, path: String, options: [String: AnyObject]!, completion: (transaction: ApiResponse) -> Void) { //FIXME Rename transaction
        client.send(inflateRequest(path, request: request, options: options)) {
            (t) in
            completion(transaction: t)
            
        }
    }
    
    ///FIXME Remove path parameter
    public func sendRequest(request: NSMutableURLRequest, path: String, options: [String: AnyObject]!) -> ApiResponse {
        return client.send(inflateRequest(path, request: request, options: options))
    }
    
    ///  func requestToken ()
    ///
    /// @param: path    The token endpoint
    /// @param: array   The body
    /// @return ApiResponse
    func requestToken(path: String, body: [String:AnyObject]) -> ApiResponse {
        let authHeader = "Basic" + " " + self.apiKey()
        var headers: [String: String] = [:]
        headers["Authorization"] = authHeader
        headers["Content-type"] = "application/x-www-form-urlencoded;charset=UTF-8"
        var options: [String: AnyObject] = [:]
        options["skipAuthCheck"] = true
        let urlCreated = createUrl(path,options: options)
        let request = self.client.createRequest("POST", url: urlCreated, query: nil, body: body, headers: headers)
        return self.sendRequest(request, path: path, options: options)
    }
    
    
    
    
    /// Base 64 encoding
    func apiKey() -> String {
        let plainData = (self.appKey + ":" + self.appSecret as NSString).dataUsingEncoding(NSUTF8StringEncoding)
        let base64String = plainData!.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
        return base64String
    }
    
    
    
    /// Logs the user out of the current account.
    ///
    /// Kills the current accessToken and refreshToken.
    public func logout() -> ApiResponse {
        let response = requestToken(self.TOKEN_ENDPOINT,body: [
            "token": self.auth.accessToken()
            ])
        self.auth.reset()
        return response
    }
  
    
    
    public func isAuthorized() -> Bool { //FIXME REMOVE
        return auth.isAccessTokenValid()
    }
    
    /// Check if the accessToken is valid
    func ensureAuthentication() {
        if (!self.auth.accessTokenValid()) {
            refresh()
        }
    }
    
    
    
    //  Generic Method calls  ( HTTP ) GET
    ///
    /// @param: url             token endpoint
    /// @param: query           body
    /// @return ApiResponse     Callback
    public func get(url: String, query: [String: String] = ["":""], completion: (response: ApiResponse) -> Void) {
        request([ ///FIXME Assemble request here and send it using sendRequest method
            "method": "GET",
            "url": url,
            "query": query
            ])
            {
                (r) in
                completion(response: r)
                
        }
    }
    
    
    // Generic Method calls  ( HTTP ) POST
    ///
    /// @param: url             token endpoint
    /// @param: body            body
    /// @return ApiResponse     Callback
    public func post(url: String, body: [String: AnyObject] = ["":""], completion: (respsone: ApiResponse) -> Void) {
        request([ ///FIXME Assemble request here and send it using sendRequest method
            "method": "POST",
            "url": url,
            "body": body
            ])
            {
                (r) in
                completion(respsone: r)
                
        }
    }
    
    // Generic Method calls  ( HTTP ) PUT
    ///
    /// @param: url             token endpoint
    /// @param: body            body
    /// @return ApiResponse     Callback
    public func put(url: String, body: [String: AnyObject] = ["":""], completion: (respsone: ApiResponse) -> Void) {
        request([ ///FIXME Assemble request here and send it using sendRequest method
            "method": "PUT",
            "url": url,
            "body": body
            ])
            {
                (r) in
                completion(respsone: r)
                
        }
    }
    
    // Generic Method calls ( HTTP ) DELETE
    ///
    /// @param: url             token endpoint
    /// @param: query           body
    /// @return ApiResponse     Callback
    public func delete(url: String, query: [String: String] = ["":""], completion: (response: ApiResponse) -> Void) {
        request([ ///FIXME Assemble request here and send it using sendRequest method
            "method": "DELETE",
            "url": url,
            "query": query
            ])
            {
                (r) in
                completion(response: r)
                
        }
    }
    
    /// Generic HTTP request method
    ///
    /// @param: options     List of options for HTTP request
    ///FIXME REMOVE
    func request(options: [String: AnyObject]) -> ApiResponse {
        var method = ""
        var url = ""
        var headers = [String: String]()
        headers["Content-Type"] = "application/json"
        headers["Accept"] = "application/json"
        var query: [String: String]?
        var body = [String: AnyObject]()
        if let m = options["method"] as? String {
            method = m
        }
        if let u = options["url"] as? String {
            url =  u
        }
        if let h = options["headers"] as? [String: String] {
            headers = h
        }
        if let q = options["query"] as? [String: String] {
            query = q
        }
        else {
            query = nil
        }
        if let b = options["body"] as? [String: AnyObject] {
            body = options["body"] as! [String: AnyObject]
        }
        
        return sendRequest(self.client.createRequest(method, url: url, query: query, body: body, headers: headers), path: url, options: options)
    }
    
    
    /// Generic HTTP request with completion handler ( call-back )
    ///
    /// :param: options         List of options for HTTP request
    /// :param: completion      Completion handler for HTTP request
    ///FIXME REMOVE
    func request(options: [String: AnyObject], completion: (response: ApiResponse) -> Void) {
        var method = ""
        var url = ""
        var headers = [String: String]()
        headers["Content-Type"] = "application/json"
        headers["Accept"] = "application/json"
        var query: [String: String]?
        var body = [String: AnyObject]()
        if let m = options["method"] as? String {
            method = m
        }
        if let u = options["url"] as? String {
            url =  u
        }
        if let h = options["headers"] as? [String: String] {
            headers = h
        }
        if let q = options["query"] as? [String: String] {
            query = q
        }
        if let b = options["body"] as? [String: AnyObject] {
            body = options["body"] as! [String: AnyObject]
        }

        let urlCreated = createUrl(url,options: options)
        
        sendRequest(self.client.createRequest(method, url: urlCreated, query: query, body: body, headers: headers), path: url, options: options) {
            (r) in
            completion(response: r)
            
        }
        
    }    
}
