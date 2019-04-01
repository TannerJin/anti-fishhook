//
//  BaseTest.swift
//  Base
//
//  Created by jintao on 2019/3/31.
//  Copyright © 2019 jintao. All rights reserved.
//

import Foundation
import fishhookProtection

// fishhook NSLog
public func fishhookNSLog(newMethod: UnsafeMutableRawPointer) {
    var oldMethod: UnsafeMutableRawPointer?
    replaceSymbol("NSLog", newMethod: newMethod, oldMethod: &oldMethod)
}

public func protectNSLog() {
    resetSymbol("NSLog")
}
