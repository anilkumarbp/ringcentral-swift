//
//  main.swift
//  src
//
//  Created by Anil Kumar BP on 11/17/15.
//  Copyright (c) 2015 Anil Kumar BP. All rights reserved.
//

import Foundation


println("Hello, World!")

var app_key: String = ""
var app_secret = ""
var username = ""
var password = ""
var response: ApiResponse


var rcsdk = SDK(appKey: app_key, appSecret: app_secret, server: SDK.RC_SERVER_SANDBOX, appName: "Swift_Test_Sample", appVersion: "1.0.0")
println("SDK initialized")
var platform = rcsdk.getPlatform()
var subscription = rcsdk.createSubscription()
//var multipartBuilder = rcsdk.createMultipartBuilder()
println("Platform singleton")

// login

platform.login(username, ext:"101", password: password)
    {
        (apiresponse,apiexception) in
        println("Response is :")
        println(apiresponse!.JSONStringify(apiresponse!.getDict(), prettyPrinted: true))
    }
// Test a GET request

platform.refresh()
    {
        (apiresponse,apiexception) in
        println("Response is :")
        println(apiresponse!.JSONStringify(apiresponse!.getDict(), prettyPrinted: true))
    }

platform.get("/account/~/extension/~/call-log")
    {
        (apiresponse,apiexception) in
        println("Response is :")
        println(apiresponse!.JSONStringify(apiresponse!.getDict(), prettyPrinted: true))
    }

// add events to the subscription object
subscription.addEvents(
    [
        "/restapi/v1.0/account/~/extension/~/presence",
        "/restapi/v1.0/account/~/extension/~/message-store"
    ])

subscription.register()
    {
        (apiresponse) in
        println("Subscribing"+apiresponse.JSONStringify(apiresponse.getDict(), prettyPrinted: true))
        println("Subscribing",response.getResponse())
}

//
platform.post("/account/~/extension/~/ringout", body :
    [ "to": ["phoneNumber": "18315941779"],
        "from": ["phoneNumber": "15856234190"],
        "callerId": ["phoneNumber": ""],
        "playPrompt": "true"
    ])
    {
        (apiresponse,apiexception) in
         println(apiresponse!.JSONStringify(apiresponse!.getDict(), prettyPrinted: true))
}

platform.post("/account/~/extension/~/sms", body :
    [ "to": [["phoneNumber": "18315941779"]],
        "from": ["phoneNumber": "15856234190"],
        "text": "Test"
    ])
    {
        (apiresponse,apiexception) in
        println(apiresponse!.JSONStringify(apiresponse!.getDict(), prettyPrinted: true))
}

print("completed ring-out")
