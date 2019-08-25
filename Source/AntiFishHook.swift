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
fileprivate let __text_seg_name: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0x5f, 0x5f, 0x54, 0x45, 0x58, 0x54, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
// __stub_helper
fileprivate let __stub_helper_name: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0x5f, 0x5f, 0x73, 0x74, 0x75, 0x62, 0x5f, 0x68, 0x65, 0x6c, 0x70, 0x65, 0x72, 0x00, 0x00, 0x00)
// __Linkedit
fileprivate let __linkedit_seg_name: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0x5f, 0x5f, 0x4c, 0x49, 0x4e, 0x4b, 0x45, 0x44, 0x49, 0x54, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)

@inline(__always)
@_cdecl("resetSymbol")  // support Swift, C, Objc...
public func resetSymbol(_ symbol: String)
{
    guard let symbolBytes = symbol.data(using: String.Encoding.utf8)?.map({ $0 }) else { return }
    
    for i in 0..<_dyld_image_count() {
        if let image = _dyld_get_image_header(i) {
            resetSymbol(symbolBytes, image: image, imageSlide: _dyld_get_image_vmaddr_slide(i))
        }
    }
}

@inline(__always)
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
    
    if linkeditCmd == nil || dyldInfoCmd == nil { return }
    
    let linkeditBase = UInt64(slide) + linkeditCmd.pointee.vmaddr - linkeditCmd.pointee.fileoff
    let lazyBindOffsetInfo_vm_addr = linkeditBase + UInt64(dyldInfoCmd.pointee.lazy_bind_off)
    let bindOffsetInfo_vm_addr = linkeditBase + UInt64(dyldInfoCmd.pointee.bind_off)
    
    func findSymbolAt(section_vm_addr: UInt64, section_size: UInt32) {
        guard let section_pointer = UnsafeMutablePointer<UInt8>(bitPattern: Int(section_vm_addr)) else { return }
        
        var index: Int?
        let _symbol = [0x5f] + symbol    // _symbol(Name Mangling), support Swift(notice Swift Name Mangling)
        let size = Int(section_size)
        for i in 0..<size {
            var contains = true
     Label: for j in 0..<symbol.count {
                if section_pointer[i+j] != _symbol[j] {
                    contains = false
                    break Label
                }
            }
            if contains {
                index = i
                break
            }
        }

        if let offset = index, offset >= 5, offset + _symbol.count <= size {
            findCodeVMAddr(symbol: symbol, image: image, imageSlide: slide, symbol_data_offset: offset - 5)
        }
    }
    
    findSymbolAt(section_vm_addr: lazyBindOffsetInfo_vm_addr, section_size: dyldInfoCmd.pointee.lazy_bind_size)
    findSymbolAt(section_vm_addr: bindOffsetInfo_vm_addr, section_size: dyldInfoCmd.pointee.bind_size)
}

@inline(__always)
private func findCodeVMAddr(symbol: [UInt8],
                               image: UnsafePointer<mach_header>,
                               imageSlide slide: Int,
                               symbol_data_offset: Int)
{
    var curSegCommand: UnsafeMutablePointer<segment_command_64>!
    var cur = OpaquePointer(UnsafeRawPointer(image).advanced(by: MemoryLayout<mach_header_64>.size))
    
    for _ in 0..<image.pointee.ncmds {
        curSegCommand = UnsafeMutablePointer<segment_command_64>(cur)
        cur = OpaquePointer(UnsafeRawPointer(cur).advanced(by: Int(curSegCommand.pointee.cmdsize)))
        
        if UInt8(curSegCommand.pointee.segname.0) == __text_seg_name.0,
            UInt8(curSegCommand.pointee.segname.1) == __text_seg_name.1,
            UInt8(curSegCommand.pointee.segname.2) == __text_seg_name.2,
            UInt8(curSegCommand.pointee.segname.3) == __text_seg_name.3,
            UInt8(curSegCommand.pointee.segname.4) == __text_seg_name.4,
            UInt8(curSegCommand.pointee.segname.5) == __text_seg_name.5
        {
            break
        }
    }
    
    var section: UnsafeMutablePointer<section_64>!
    for i in 0..<curSegCommand.pointee.nsects {
        let _cur_section = UnsafeRawPointer(curSegCommand).advanced(by: MemoryLayout<segment_command_64>.size + MemoryLayout<section_64>.size*Int(i))
        let cur_section = UnsafeMutablePointer<section_64>(OpaquePointer(_cur_section))
        
        if UInt8(cur_section.pointee.sectname.0) == __stub_helper_name.0,
            UInt8(cur_section.pointee.sectname.1) == __stub_helper_name.1,
            UInt8(cur_section.pointee.sectname.2) == __stub_helper_name.2,
            UInt8(cur_section.pointee.sectname.3) == __stub_helper_name.3,
            UInt8(cur_section.pointee.sectname.4) == __stub_helper_name.4,
            UInt8(cur_section.pointee.sectname.5) == __stub_helper_name.5,
            UInt8(cur_section.pointee.sectname.6) == __stub_helper_name.6,
            UInt8(cur_section.pointee.sectname.7) == __stub_helper_name.7,
            UInt8(cur_section.pointee.sectname.8) == __stub_helper_name.8,
            UInt8(cur_section.pointee.sectname.9) == __stub_helper_name.9,
            UInt8(cur_section.pointee.sectname.10) == __stub_helper_name.10,
            UInt8(cur_section.pointee.sectname.11) == __stub_helper_name.11,
            UInt8(cur_section.pointee.sectname.12) == __stub_helper_name.12
        {
            section = cur_section
            break
        }
    }
    
    guard let stub_helper_section = section,
        let stubHelperVMAddr = UnsafeMutablePointer<UInt32>.init(bitPattern: slide+Int(stub_helper_section.pointee.addr)) else {
            return
        }
    
    var codeOffset: Int!
    for i in 0..<stub_helper_section.pointee.size/4 {
        if stubHelperVMAddr.advanced(by: Int(i)).pointee == symbol_data_offset {
            codeOffset = Int(i)
            break
        }
    }
    if codeOffset == nil { return }
    
    let pointer = stubHelperVMAddr.advanced(by: (codeOffset-2))
    let newMethod = UnsafeMutablePointer(pointer)
    var oldMethod: UnsafeMutableRawPointer? = nil
    replaceSymbol(symbol, image: image, imageSlide: slide, newMethod: newMethod, oldMethod: &oldMethod)
}
