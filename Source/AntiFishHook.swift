//
//  FishHookProtection.swift
//  FishHookProtect
//
//  Created by jintao on 2019/3/25.
//  Copyright © 2019 jintao. All rights reserved.
//

import Foundation
import MachO

// __stub_helper
fileprivate let __stub_helper_section: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0x5f, 0x5f, 0x73, 0x74, 0x75, 0x62, 0x5f, 0x68, 0x65, 0x6c, 0x70, 0x65, 0x72, 0x00, 0x00, 0x00)


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
    
    var curSegCmd: UnsafeMutablePointer<segment_command_64>!
    var cur_cmd_pointer = UnsafeMutableRawPointer(mutating: image).advanced(by: MemoryLayout<mach_header_64>.size)
    
    for _ in 0..<image.pointee.ncmds {
        curSegCmd = UnsafeMutablePointer<segment_command_64>(OpaquePointer(cur_cmd_pointer))
        cur_cmd_pointer = cur_cmd_pointer.advanced(by: Int(curSegCmd.pointee.cmdsize))
        
        if curSegCmd.pointee.cmd == LC_SEGMENT_64 {
            if UInt8(curSegCmd.pointee.segname.0) == linkeditCmdName[0],
                UInt8(curSegCmd.pointee.segname.1) == linkeditCmdName[1],
                UInt8(curSegCmd.pointee.segname.2) == linkeditCmdName[2],
                UInt8(curSegCmd.pointee.segname.3) == linkeditCmdName[3],
                UInt8(curSegCmd.pointee.segname.4) == linkeditCmdName[4],
                UInt8(curSegCmd.pointee.segname.5) == linkeditCmdName[5],
                UInt8(curSegCmd.pointee.segname.6) == linkeditCmdName[6],
                UInt8(curSegCmd.pointee.segname.7) == linkeditCmdName[7],
                UInt8(curSegCmd.pointee.segname.8) == linkeditCmdName[8],
                UInt8(curSegCmd.pointee.segname.9) == linkeditCmdName[9]
            {
                linkeditCmd = curSegCmd
            }
        } else if curSegCmd.pointee.cmd == LC_DYLD_INFO_ONLY || curSegCmd.pointee.cmd == LC_DYLD_INFO {
            dyldInfoCmd = UnsafeMutablePointer<dyld_info_command>(OpaquePointer(UnsafeRawPointer(curSegCmd)))
        }
    }
    
    if linkeditCmd == nil || dyldInfoCmd == nil { return }
    
    let linkeditBase = UInt64(slide) + linkeditCmd.pointee.vmaddr - linkeditCmd.pointee.fileoff
    let lazyBindInfoCmd = linkeditBase + UInt64(dyldInfoCmd.pointee.lazy_bind_off)
    let bindInfoCmd = linkeditBase + UInt64(dyldInfoCmd.pointee.bind_off)
    
    func findSymbolAt(bindInfo_vm_addr: UInt64, section_size: UInt32) {
        guard let section_pointer = UnsafeMutablePointer<UInt8>(bitPattern: Int(bindInfo_vm_addr)) else { return }
        
        var index: Int?
        let _symbol = [0x5f] + symbol    // _symbol(Name Mangling), support Swift(notice Swift Name Mangling)
        let size = Int(section_size)
        for i in 0..<size {
            var contains = true
     Label: for j in 0..<_symbol.count {
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
            findCodeVMAddr(symbol: symbol, image: image, imageSlide: slide, symbol_bindInfo_offset: offset - 5)
        }
    }
    
    findSymbolAt(bindInfo_vm_addr: lazyBindInfoCmd, section_size: dyldInfoCmd.pointee.lazy_bind_size)
    findSymbolAt(bindInfo_vm_addr: bindInfoCmd, section_size: dyldInfoCmd.pointee.bind_size)
}

@inline(__always)
private func findCodeVMAddr(symbol: [UInt8],
                               image: UnsafePointer<mach_header>,
                               imageSlide slide: Int,
                               symbol_bindInfo_offset: Int)
{
    var curSegCmd: UnsafeMutablePointer<segment_command_64>!
    var cur_cmd_pointer = UnsafeMutableRawPointer(mutating: image).advanced(by: MemoryLayout<mach_header_64>.size)
    
    // __Text sections
    let seg_text = SEG_TEXT.data(using: String.Encoding.utf8)!.map({ Int8($0) })
    var seg_text_cmd: UnsafeMutablePointer<segment_command_64>!
    
    for _ in 0..<image.pointee.ncmds {
        curSegCmd = UnsafeMutablePointer<segment_command_64>(OpaquePointer(cur_cmd_pointer))
        cur_cmd_pointer = cur_cmd_pointer.advanced(by: Int(curSegCmd.pointee.cmdsize))
        
        if seg_text.count > 5,
            UInt8(curSegCmd.pointee.segname.0) == seg_text[0],
            UInt8(curSegCmd.pointee.segname.1) == seg_text[1],
            UInt8(curSegCmd.pointee.segname.2) == seg_text[2],
            UInt8(curSegCmd.pointee.segname.3) == seg_text[3],
            UInt8(curSegCmd.pointee.segname.4) == seg_text[4],
            UInt8(curSegCmd.pointee.segname.5) == seg_text[5]
        {
            seg_text_cmd = curSegCmd
            break
        }
    }
    
    // __stub_helper section
    if seg_text_cmd == nil { return }
    var stub_helper_section: UnsafeMutablePointer<section_64>!
    
    for i in 0..<seg_text_cmd.pointee.nsects {
        let cur_section_pointer = UnsafeRawPointer(seg_text_cmd).advanced(by: MemoryLayout<segment_command_64>.size + MemoryLayout<section_64>.size*Int(i))
        let curSection = UnsafeMutablePointer<section_64>(OpaquePointer(cur_section_pointer))
        
        if UInt8(curSection.pointee.sectname.0) == __stub_helper_section.0,
            UInt8(curSection.pointee.sectname.1) == __stub_helper_section.1,
            UInt8(curSection.pointee.sectname.2) == __stub_helper_section.2,
            UInt8(curSection.pointee.sectname.3) == __stub_helper_section.3,
            UInt8(curSection.pointee.sectname.4) == __stub_helper_section.4,
            UInt8(curSection.pointee.sectname.5) == __stub_helper_section.5,
            UInt8(curSection.pointee.sectname.6) == __stub_helper_section.6,
            UInt8(curSection.pointee.sectname.7) == __stub_helper_section.7,
            UInt8(curSection.pointee.sectname.8) == __stub_helper_section.8,
            UInt8(curSection.pointee.sectname.9) == __stub_helper_section.9,
            UInt8(curSection.pointee.sectname.10) == __stub_helper_section.10,
            UInt8(curSection.pointee.sectname.11) == __stub_helper_section.11,
            UInt8(curSection.pointee.sectname.12) == __stub_helper_section.12
        {
            stub_helper_section = curSection
            break
        }
    }
    
    // find code vm addr
    guard stub_helper_section != nil,
        let stubHelper_vm_addr = UnsafeMutablePointer<UInt32>(bitPattern: slide+Int(stub_helper_section.pointee.addr)) else {
            return
        }
    
    var codeOffset: Int!
    for i in 0..<stub_helper_section.pointee.size/4 {
        /*
            ldr w16 .long
            b: stub(dyld_stub_binder)
            .long: symbol_bindInfo_offset
         */
        if stubHelper_vm_addr.advanced(by: Int(i)).pointee == symbol_bindInfo_offset {
            codeOffset = Int(i)
            break
        }
    }
    if codeOffset == nil { return }
    
    let pointer = stubHelper_vm_addr.advanced(by: (codeOffset-2))  // ldr w16 .long
    let newMethod = UnsafeMutablePointer(pointer)
    var oldMethod: UnsafeMutableRawPointer? = nil
    replaceSymbol(symbol, image: image, imageSlide: slide, newMethod: newMethod, oldMethod: &oldMethod)
}
