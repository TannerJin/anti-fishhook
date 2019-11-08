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
fileprivate let __stub_helper_section: (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8) = (0x5f, 0x5f, 0x73, 0x74, 0x75, 0x62, 0x5f, 0x68, 0x65, 0x6c, 0x70, 0x65, 0x72, 0x00, 0x00, 0x00)

#if arch(arm)
typealias _mach_header = mach_header
typealias _segment_command = segment_command
typealias _section = section
let _LC_SEGMENT = LC_SEGMENT
typealias _nlist = nlist
#elseif arch(arm64)
// arm64
typealias _mach_header = mach_header_64
typealias _segment_command = segment_command_64
typealias _section = section_64
let _LC_SEGMENT = LC_SEGMENT_64
typealias _nlist = nlist_64
#endif

@inline(__always)
@_cdecl("resetSymbol")  // support Swift, C, Objc...
public func resetSymbol(_ symbol: String) {
    for i in 0..<_dyld_image_count() {
        if let image = _dyld_get_image_header(i) {
            resetSymbol(symbol, image: image, imageSlide: _dyld_get_image_vmaddr_slide(i))
        }
    }
}

@inline(__always)
public func resetSymbol(_ symbol: String,
                         image: UnsafePointer<mach_header>,
                         imageSlide slide: Int) {
    // Linked CMD
    let linkeditCmdName = SEG_LINKEDIT.data(using: String.Encoding.utf8)!.map({ $0 })
    var linkeditCmd: UnsafeMutablePointer<_segment_command>!
    var dyldInfoCmd: UnsafeMutablePointer<dyld_info_command>!
    
    // Text CMD
    let textCmdName = SEG_TEXT.data(using: String.Encoding.utf8)!.map({ Int8($0) })
    var textCmd: UnsafeMutablePointer<_segment_command>!
    
    var curSegCmd: UnsafeMutablePointer<_segment_command>!
    var cur_cmd_pointer = UnsafeMutableRawPointer(mutating: image).advanced(by: MemoryLayout<_mach_header>.size)
    
    for _ in 0..<image.pointee.ncmds {
        curSegCmd = UnsafeMutablePointer<_segment_command>(OpaquePointer(cur_cmd_pointer))
        cur_cmd_pointer = cur_cmd_pointer.advanced(by: Int(curSegCmd.pointee.cmdsize))
        
        if curSegCmd.pointee.cmd == _LC_SEGMENT {
            if (curSegCmd.pointee.segname.0 == linkeditCmdName[0] &&
                curSegCmd.pointee.segname.1 == linkeditCmdName[1] &&
                curSegCmd.pointee.segname.2 == linkeditCmdName[2] &&
                curSegCmd.pointee.segname.3 == linkeditCmdName[3] &&
                curSegCmd.pointee.segname.4 == linkeditCmdName[4] &&
                curSegCmd.pointee.segname.5 == linkeditCmdName[5] &&
                curSegCmd.pointee.segname.6 == linkeditCmdName[6] &&
                curSegCmd.pointee.segname.7 == linkeditCmdName[7] &&
                curSegCmd.pointee.segname.8 == linkeditCmdName[8] &&
                curSegCmd.pointee.segname.9 == linkeditCmdName[9]) {
                
                linkeditCmd = curSegCmd
            }
            if (curSegCmd.pointee.segname.0 == textCmdName[0] &&
                curSegCmd.pointee.segname.1 == textCmdName[1] &&
                curSegCmd.pointee.segname.2 == textCmdName[2] &&
                curSegCmd.pointee.segname.3 == textCmdName[3] &&
                curSegCmd.pointee.segname.4 == textCmdName[4] &&
                curSegCmd.pointee.segname.5 == textCmdName[5]) {
                
                textCmd = curSegCmd
            }
        } else if curSegCmd.pointee.cmd == LC_DYLD_INFO_ONLY || curSegCmd.pointee.cmd == LC_DYLD_INFO {
            dyldInfoCmd = UnsafeMutablePointer<dyld_info_command>(OpaquePointer(UnsafeRawPointer(curSegCmd)))
        }
    }
    
    if linkeditCmd == nil || dyldInfoCmd == nil || textCmd == nil { return }
    
    let linkeditBase = UInt(slide) + UInt(linkeditCmd.pointee.vmaddr) - UInt(linkeditCmd.pointee.fileoff)
    let lazyBindInfoCmd = linkeditBase + UInt(dyldInfoCmd.pointee.lazy_bind_off)
    let bindInfoCmd = linkeditBase + UInt(dyldInfoCmd.pointee.bind_off)
    
    // ImageLoaderMachO::getLazyBindingInfo
    if !findCodeVMAddr(symbol: symbol, image: image, imageSlide: slide, text_cmd: textCmd, bindInfoCmd: UnsafePointer<UInt8>(bitPattern: UInt(lazyBindInfoCmd)), bindInfoSize: Int(dyldInfoCmd.pointee.lazy_bind_size)) {
        
        findCodeVMAddr(symbol: symbol, image: image, imageSlide: slide, text_cmd: textCmd, bindInfoCmd: UnsafePointer<UInt8>(bitPattern: UInt(bindInfoCmd)), bindInfoSize: Int(dyldInfoCmd.pointee.bind_size))
    }
}

@inline(__always)
@discardableResult
private func findCodeVMAddr(symbol: String,
                               image: UnsafePointer<mach_header>,
                               imageSlide slide: Int,
                               text_cmd: UnsafeMutablePointer<_segment_command>,
                               bindInfoCmd: UnsafePointer<UInt8>!,
                               bindInfoSize: Int) -> Bool {
    if bindInfoCmd == nil { return false }
    var stub_helper_section: UnsafeMutablePointer<_section>!
    
    for i in 0..<text_cmd.pointee.nsects {
        let cur_section_pointer = UnsafeRawPointer(text_cmd).advanced(by: MemoryLayout<_segment_command>.size + MemoryLayout<_section>.size*Int(i))
        let curSection = UnsafeMutablePointer<_section>(OpaquePointer(cur_section_pointer))
        
        if curSection.pointee.sectname.0 == __stub_helper_section.0 &&
            curSection.pointee.sectname.1 == __stub_helper_section.1 &&
            curSection.pointee.sectname.2 == __stub_helper_section.2 &&
            curSection.pointee.sectname.3 == __stub_helper_section.3 &&
            curSection.pointee.sectname.4 == __stub_helper_section.4 &&
            curSection.pointee.sectname.5 == __stub_helper_section.5 &&
            curSection.pointee.sectname.6 == __stub_helper_section.6 &&
            curSection.pointee.sectname.7 == __stub_helper_section.7 &&
            curSection.pointee.sectname.8 == __stub_helper_section.8 &&
            curSection.pointee.sectname.9 == __stub_helper_section.9 &&
            curSection.pointee.sectname.10 == __stub_helper_section.10 &&
            curSection.pointee.sectname.11 == __stub_helper_section.11 &&
            curSection.pointee.sectname.12 == __stub_helper_section.12
        {
            stub_helper_section = curSection
            break
        }
    }
    
    // find code vm addr
    guard stub_helper_section != nil,
        let stubHelper_vm_addr = UnsafeMutablePointer<UInt32>(bitPattern: slide+Int(stub_helper_section.pointee.addr)) else {
            return false
        }
    
    var codeOffset: Int!
    // 5 instructions: code of dyld_stub_binder
    for i in 5..<stub_helper_section.pointee.size/4 {
        /*
            ldr w16 .long
            b: stub(dyld_stub_binder)
            .long: symbol_bindInfo_offset
         */
        
        /*   ldr w16, #8  ARM Architecture Reference Manual

             0x18000050 is feature at IDA, so decompile instruction
         
             31  28 27 25
             +-----------------------------------------------------------------------+
             |cond | 100 | P | U | S | W | L | Rn |         register list            |
             +-----------------------------------------------------------------------+
         
             If R15 is specified as register Rn, the value used is the address of the instruction plus eight.
         */
        
        let instruction = stubHelper_vm_addr.advanced(by: Int(i)).pointee
        var condition = false
        
        #if arch(arm)
        condition = instruction == 0xE59FC000   // LDR IP, [PC]
        #elseif arch(arm64)
        let ldr = (instruction & (7 << 25)) >> 25
        let r16 = instruction & (31 << 0)
        condition = ldr == 4 && r16 == 16       // 100 && r16
        #endif
        
        if condition {
            let bindingInfoOffset = stubHelper_vm_addr.advanced(by: Int(i+2)).pointee
            var p = bindingInfoOffset
            
            Label: while p < bindInfoSize  {
                if bindInfoCmd.advanced(by: Int(p)).pointee == BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB {
                    p += 3 // pass uleb128
                    continue Label
                }
                if bindInfoCmd.advanced(by: Int(p)).pointee == BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM {
                    // _symbol
                    if String(cString: bindInfoCmd.advanced(by: Int(p)+1 + 1)) == symbol {
                        codeOffset = Int(i)
                        break
                    }
                    break Label
                }
                p += 1
                continue Label
            }
        }
        
    }
    
    if codeOffset == nil { return false }
    
    let pointer = stubHelper_vm_addr.advanced(by: (codeOffset))  // ldr w16 .long
    let newMethod = UnsafeMutablePointer(pointer)
    var oldMethod: UnsafeMutableRawPointer? = nil
    replaceSymbol(symbol, image: image, imageSlide: slide, newMethod: newMethod, oldMethod: &oldMethod)
    
    return true
}
