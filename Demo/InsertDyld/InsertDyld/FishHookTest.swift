//
//  InserDyldFishHook.swift
//  InsertDyld
//
//  Created by jintao on 2019/4/1.
//  Copyright © 2019 jintao. All rights reserved.
//

import Foundation
import MachO
import antiFishhook

// fishhook printf
public func fishhookPrint(newMethod: UnsafeMutableRawPointer) {
    var oldMethod: UnsafeMutableRawPointer?
    replaceSymbol("printf", newMethod: newMethod, oldMethod: &oldMethod)
}

// fishhook dladdr
public func fishhookDladdr(newMethod: UnsafeMutableRawPointer) {
    var oldMethod: UnsafeMutableRawPointer?
    for i in 0..<_dyld_image_count() {
        if let name = _dyld_get_image_name(i) {
            let imageName = String(cString: name)
            if imageName.contains("FishHookProtect"),
                let symbol = "dladdr".data(using: String.Encoding.utf8)?.map({$0}),
                let image = _dyld_get_image_header(i)
            {
                replaceSymbol(symbol, image: image, imageSlide: _dyld_get_image_vmaddr_slide(i), newMethod: newMethod, oldMethod: &oldMethod)
                break
            }
        }
    }
}
