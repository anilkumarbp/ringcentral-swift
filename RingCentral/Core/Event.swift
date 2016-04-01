//
//  Event.swift
//  RingCentral
//
//  Created by Anil Kumar BP on 3/30/16.
//  Copyright © 2016 Anil Kumar BP. All rights reserved.
//

import Foundation

class Event <E:Any,R:Any> {
    var handlers = Array<(E,R) -> Void>()
    
    func listen(handler: (E,R) -> Void) {
        handlers.append(handler)
    }
    
    func emit(event: E,response: R) {
        for handler in handlers {
            handler(event,response)
        }
    }
}