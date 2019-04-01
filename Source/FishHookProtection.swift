//
//  FishHookProtection.swift
//  FishHookProtect
//
//  Created by jintao on 2019/3/25.
//  Copyright © 2019 jintao. All rights reserved.
//

import Foundation
import MachO

// __TEXT
private let __text_seg_name: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0x5f, 0x5f, 0x54, 0x45, 0x58, 0x54, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
// __stub_helper
private let __stub_helper_name: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0x5f, 0x5f, 0x73, 0x74, 0x75, 0x62, 0x5f, 0x68, 0x65, 0x6c, 0x70, 0x65, 0x72, 0x00, 0x00, 0x00)
// __Linkedit
private let __linkedit_seg_name: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0x5f, 0x5f, 0x4c, 0x49, 0x4e, 0x4b, 0x45, 0x44, 0x49, 0x54, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)

public func resetSymbol(_ symbol: String)
{
    guard let symbolBytes = symbol.data(using: String.Encoding.utf8)?.map({ $0 }) else { return }
    for i in 0..<_dyld_image_count() {
        if let image = _dyld_get_image_header(i) {
            resetSymbol(symbolBytes, image: image, imageSlide: _dyld_get_image_vmaddr_slide(i))
        }
    }
}

public func resetSymbol(_ symbol: [UInt8],
                         image: UnsafePointer<mach_header>,
                         imageSlide slide: Int)
{
    var linkeditCmd: UnsafeMutablePointer<segment_command_64>!
    let linkeditCmdName = SEG_LINKEDIT.data(using: String.Encoding.utf8)!.map({ $0 })
    
    var dyldInfoCmd: UnsafeMutablePointer<dyld_info_command>!
    
    var curSegCommand: UnsafeMutablePointer<segment_command_64>!
    var cur = OpaquePointer(UnsafeRawPointer(image).advanced(by: MemoryLayout<mach_header_64>.size))
    
    for _ in 0..<image.pointee.ncmds {
        curSegCommand = UnsafeMutablePointer<segment_command_64>(cur)
        cur = OpaquePointer(UnsafeRawPointer(cur).advanced(by: Int(curSegCommand.pointee.cmdsize)))
        
        if curSegCommand.pointee.cmd == LC_SEGMENT_64 {
            if UInt8(curSegCommand.pointee.segname.0) == linkeditCmdName[0],
                UInt8(curSegCommand.pointee.segname.1) == linkeditCmdName[1],
                UInt8(curSegCommand.pointee.segname.2) == linkeditCmdName[2],
                UInt8(curSegCommand.pointee.segname.3) == linkeditCmdName[3],
                UInt8(curSegCommand.pointee.segname.4) == linkeditCmdName[4],
                UInt8(curSegCommand.pointee.segname.5) == linkeditCmdName[5],
                UInt8(curSegCommand.pointee.segname.6) == linkeditCmdName[6],
                UInt8(curSegCommand.pointee.segname.7) == linkeditCmdName[7],
                UInt8(curSegCommand.pointee.segname.8) == linkeditCmdName[8],
                UInt8(curSegCommand.pointee.segname.9) == linkeditCmdName[9]
            {
                linkeditCmd = curSegCommand
            }
        } else if curSegCommand.pointee.cmd == LC_DYLD_INFO_ONLY || curSegCommand.pointee.cmd == LC_DYLD_INFO {
            dyldInfoCmd = UnsafeMutablePointer<dyld_info_command>(OpaquePointer(UnsafeRawPointer(curSegCommand)))
        }
    }
    
    let linkeditBase = UInt64(slide) + linkeditCmd.pointee.vmaddr - linkeditCmd.pointee.fileoff
    let lazyBindOffset = linkeditBase + UInt64(dyldInfoCmd.pointee.lazy_bind_off)
    let bindOffset = linkeditBase + UInt64(dyldInfoCmd.pointee.bind_off)
    
    func resetSymbol(bindOffset: UInt64, size: UInt32) {
        guard let lazyBindOffPointer = UnsafeMutablePointer<UInt8>(bitPattern: Int(bindOffset)) else { return }
        
        var arrBytes = [UInt8]()
        for i in 0..<size {
            let byte = lazyBindOffPointer.advanced(by: Int(i)).pointee
            arrBytes.append(byte)
        }
        
        var index: Int?
        for i in 0..<arrBytes.count {
            if i < (arrBytes.count - symbol.count), arrBytes[i] == UInt8(0x5f) {
                var contains = true
                for j in 0..<symbol.count {
                    if arrBytes[i+j] != symbol[j] {
                        contains = false
                    }
                }
                if contains {
                    index = i
                    break
                }
            }
        }
        
        if index != nil {
            resetSymbolByVoid(symbol: symbol, image: image, imageSlide: slide, offset: index! - 5)
        }
    }
    
    resetSymbol(bindOffset: lazyBindOffset, size: dyldInfoCmd.pointee.lazy_bind_size)
    resetSymbol(bindOffset: bindOffset, size: dyldInfoCmd.pointee.bind_size)
}

private func resetSymbolByVoid(symbol: [UInt8],
                               image: UnsafePointer<mach_header>,
                               imageSlide slide: Int,
                               offset: Int)
{
    var curSegCmd: UnsafeMutablePointer<segment_command_64>!
    var cur = OpaquePointer(UnsafeRawPointer(image).advanced(by: MemoryLayout<mach_header_64>.size))
    
    for _ in 0..<image.pointee.ncmds {
        curSegCmd = UnsafeMutablePointer<segment_command_64>(cur)
        cur = OpaquePointer(UnsafeRawPointer(cur).advanced(by: Int(curSegCmd.pointee.cmdsize)))
        
        if UInt8(curSegCmd.pointee.segname.0) == __text_seg_name.0,
            UInt8(curSegCmd.pointee.segname.1) == __text_seg_name.1,
            UInt8(curSegCmd.pointee.segname.2) == __text_seg_name.2,
            UInt8(curSegCmd.pointee.segname.3) == __text_seg_name.3,
            UInt8(curSegCmd.pointee.segname.4) == __text_seg_name.4,
            UInt8(curSegCmd.pointee.segname.5) == __text_seg_name.5
        {
            break
        }
    }
    
    var curSection: UnsafeMutablePointer<section_64>!
    for i in 0..<curSegCmd.pointee.nsects {
        let cur = UnsafeRawPointer(curSegCmd).advanced(by: MemoryLayout<segment_command_64>.size + MemoryLayout<section_64>.size*Int(i))
        let curSec = UnsafeMutablePointer<section_64>(OpaquePointer(cur))
        
        if UInt8(curSec.pointee.sectname.0) == __stub_helper_name.0,
            UInt8(curSec.pointee.sectname.1) == __stub_helper_name.1,
            UInt8(curSec.pointee.sectname.2) == __stub_helper_name.2,
            UInt8(curSec.pointee.sectname.3) == __stub_helper_name.3,
            UInt8(curSec.pointee.sectname.4) == __stub_helper_name.4,
            UInt8(curSec.pointee.sectname.5) == __stub_helper_name.5,
            UInt8(curSec.pointee.sectname.6) == __stub_helper_name.6,
            UInt8(curSec.pointee.sectname.7) == __stub_helper_name.7,
            UInt8(curSec.pointee.sectname.8) == __stub_helper_name.8,
            UInt8(curSec.pointee.sectname.9) == __stub_helper_name.9,
            UInt8(curSec.pointee.sectname.10) == __stub_helper_name.10,
            UInt8(curSec.pointee.sectname.11) == __stub_helper_name.11,
            UInt8(curSec.pointee.sectname.12) == __stub_helper_name.12
        {
            curSection = curSec
        }
    }
    
    guard let stubHelpSection = curSection,
        let stubHelperCodeAddr = UnsafeMutablePointer<UInt32>.init(bitPattern: slide+Int(stubHelpSection.pointee.addr)) else {
            return
        }
    
    var codeOffset: Int!
    for i in 0..<curSection.pointee.size/4 {
        if stubHelperCodeAddr.advanced(by: Int(i)).pointee == offset {
            codeOffset = Int(i)
        }
    }
    if codeOffset == nil { return }
    
    let pointer = stubHelperCodeAddr.advanced(by: (codeOffset-2))
    let newMethod = UnsafeMutablePointer(pointer)
    var oldMethod: UnsafeMutableRawPointer? = nil
    replaceSymbol(symbol, image: image, imageSlide: slide, newMethod: newMethod, oldMethod: &oldMethod)
}
