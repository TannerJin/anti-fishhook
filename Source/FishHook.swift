//
//  FishHook.swift
//  FishHookProtect
//
//  Created by jintao on 2019/3/28.
//  Copyright © 2019 jintao. All rights reserved.
//

import Foundation
import MachO

@inline(__always)  // just for Swift
public func replaceSymbol(_ symbol: String,
                          newMethod: UnsafeMutableRawPointer,
                          oldMethod: inout UnsafeMutableRawPointer?)
{
    for i in 0..<_dyld_image_count() {
        if let image = _dyld_get_image_header(i) {
            replaceSymbol(symbol, image: image, imageSlide: _dyld_get_image_vmaddr_slide(i), newMethod: newMethod, oldMethod: &oldMethod)
        }
    }
}

@inline(__always)
public func replaceSymbol(_ symbol: String,
                          image: UnsafePointer<mach_header>,
                          imageSlide slide: Int,
                          newMethod: UnsafeMutableRawPointer,
                          oldMethod: inout UnsafeMutableRawPointer?)
{
    rebindSymbolForImage(image, imageSlide: slide, symbol: symbol, newMethod: newMethod, oldMethod: &oldMethod)
}

@inline(__always)
private func rebindSymbolForImage(_ image: UnsafePointer<mach_header>,
                                 imageSlide slide: Int,
                                 symbol: String,
                                 newMethod: UnsafeMutableRawPointer,
                                 oldMethod: inout UnsafeMutableRawPointer?)
{
    // __Linkedit seg cmd
    let linkeditName = SEG_LINKEDIT.data(using: String.Encoding.utf8)!.map({ $0 })
    
    var linkeditCmd: UnsafeMutablePointer<segment_command_64>!
    var symtabCmd: UnsafeMutablePointer<symtab_command>!
    var dynamicSymtabCmd: UnsafeMutablePointer<dysymtab_command>!
    
    var curSegCmd: UnsafeMutablePointer<segment_command_64>!
    var cur_cmd_pointer = UnsafeMutableRawPointer(mutating: image).advanced(by: MemoryLayout<mach_header_64>.size)
    
    for _ in 0..<image.pointee.ncmds {
        curSegCmd = UnsafeMutablePointer<segment_command_64>(OpaquePointer(cur_cmd_pointer))
        cur_cmd_pointer = cur_cmd_pointer.advanced(by: Int(curSegCmd.pointee.cmdsize))
        
        if curSegCmd.pointee.cmd == LC_SEGMENT_64 {
            if UInt8(curSegCmd.pointee.segname.0) == linkeditName[0],
                UInt8(curSegCmd.pointee.segname.1) == linkeditName[1],
                UInt8(curSegCmd.pointee.segname.2) == linkeditName[2],
                UInt8(curSegCmd.pointee.segname.3) == linkeditName[3],
                UInt8(curSegCmd.pointee.segname.4) == linkeditName[4],
                UInt8(curSegCmd.pointee.segname.5) == linkeditName[5],
                UInt8(curSegCmd.pointee.segname.6) == linkeditName[6],
                UInt8(curSegCmd.pointee.segname.7) == linkeditName[7],
                UInt8(curSegCmd.pointee.segname.8) == linkeditName[8],
                UInt8(curSegCmd.pointee.segname.9) == linkeditName[9]
            {
                linkeditCmd = curSegCmd
            }
        } else if curSegCmd.pointee.cmd == LC_SYMTAB {
            symtabCmd = UnsafeMutablePointer<symtab_command>(OpaquePointer(curSegCmd))
        }  else if curSegCmd.pointee.cmd == LC_DYSYMTAB {
            dynamicSymtabCmd = UnsafeMutablePointer<dysymtab_command>(OpaquePointer(curSegCmd))
        }
    }
    
    if linkeditCmd == nil || symtabCmd == nil || dynamicSymtabCmd == nil {
        return
    }
    
    let linkedBase = slide + Int(linkeditCmd.pointee.vmaddr) - Int(linkeditCmd.pointee.fileoff)
    let symtab = UnsafeMutablePointer<nlist_64>(bitPattern: linkedBase + Int(symtabCmd.pointee.symoff))
    let strtab =  UnsafeMutablePointer<UInt8>(bitPattern: linkedBase + Int(symtabCmd.pointee.stroff))
    let indirectsym = UnsafeMutablePointer<UInt32>(bitPattern: linkedBase + Int(dynamicSymtabCmd.pointee.indirectsymoff))
    
    if symtab == nil || strtab == nil || indirectsym == nil {
        return
    }
    
    // __Data sections
    cur_cmd_pointer = UnsafeMutableRawPointer(mutating: image).advanced(by: MemoryLayout<mach_header_64>.size)
    let seg_data = SEG_DATA.data(using: String.Encoding.utf8)!.map({ Int8($0) })
    
    for _ in 0..<image.pointee.ncmds {
        let curSegCmd = UnsafeMutablePointer<segment_command_64>(OpaquePointer(cur_cmd_pointer))
        cur_cmd_pointer = cur_cmd_pointer.advanced(by: Int(curSegCmd.pointee.cmdsize))
        
        if curSegCmd.pointee.segname.0 == seg_data[0],
            curSegCmd.pointee.segname.1 == seg_data[1],
            curSegCmd.pointee.segname.2 == seg_data[2],
            curSegCmd.pointee.segname.3 == seg_data[3],
            curSegCmd.pointee.segname.4 == seg_data[4],
            curSegCmd.pointee.segname.5 == seg_data[5]
        {
            for j in 0..<curSegCmd.pointee.nsects {
                let cur_section_pointer = UnsafeRawPointer(curSegCmd).advanced(by: MemoryLayout<segment_command_64>.size + MemoryLayout<section_64>.size*Int(j))
                let curSection = UnsafeMutablePointer<section_64>(OpaquePointer(cur_section_pointer))
                
                // symbol_pointers sections
                if curSection.pointee.flags == S_LAZY_SYMBOL_POINTERS {
                    rebindSymbolPointerWithSection(curSection, symtab: symtab!, strtab: strtab!, indirectsym: indirectsym!, slide: slide, symbolName: symbol, newMethod: newMethod, oldMethod: &oldMethod)
                }
                if curSection.pointee.flags == S_NON_LAZY_SYMBOL_POINTERS {
                    rebindSymbolPointerWithSection(curSection, symtab: symtab!, strtab: strtab!, indirectsym: indirectsym!, slide: slide, symbolName: symbol, newMethod: newMethod, oldMethod: &oldMethod)
                }
            }
        }
    }
}

@inline(__always)
private func rebindSymbolPointerWithSection(_ section: UnsafeMutablePointer<section_64>,
                                           symtab: UnsafeMutablePointer<nlist_64>,
                                           strtab: UnsafeMutablePointer<UInt8>,
                                           indirectsym: UnsafeMutablePointer<UInt32>,
                                           slide: Int,
                                           symbolName: String,
                                           newMethod: UnsafeMutableRawPointer,
                                           oldMethod: inout UnsafeMutableRawPointer?)
{
    let indirectSym_vm_addr = indirectsym.advanced(by: Int(section.pointee.reserved1))
    let section_vm_addr = UnsafeMutablePointer<UnsafeMutableRawPointer>(bitPattern: slide+Int(section.pointee.addr))
    
    if section_vm_addr == nil {
        return
    }
    
Label: for i in 0..<Int(section.pointee.size)/MemoryLayout<UnsafeMutableRawPointer>.size {
        let curIndirectSym = indirectSym_vm_addr.advanced(by: i)
        if (curIndirectSym.pointee == INDIRECT_SYMBOL_ABS || curIndirectSym.pointee == INDIRECT_SYMBOL_LOCAL) {
            continue
        }
        let curStrTabOff = symtab.advanced(by: Int(curIndirectSym.pointee)).pointee.n_un.n_strx
        let curSymbolName = strtab.advanced(by: Int(curStrTabOff+1))
    
        if String(cString: curSymbolName) == symbolName {
            oldMethod = section_vm_addr!.advanced(by: i).pointee
            section_vm_addr!.advanced(by: i).initialize(to: newMethod)
            break
        }
    }
}
