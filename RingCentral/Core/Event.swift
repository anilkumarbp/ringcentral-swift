//
//  Event.swift
//  RingCentral
//
//  Created by Anil Kumar BP on 3/30/16.
//  Copyright © 2016 Anil Kumar BP. All rights reserved.
//

import Foundation

class Event <T:Any> {
    var handlers = Array<(T) -> Void>()
    
    func listen(handler: (T) -> Void) {
        handlers.append(handler)
    }
    
    func emit(object: T) {
        for handler in handlers {
            handler(object)
        }
    }
}