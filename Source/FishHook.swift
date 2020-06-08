//
//  FishHook.swift
//  FishHookProtect
//
//  Created by jintao on 2019/3/28.
//  Copyright © 2019 jintao. All rights reserved.
//

import Foundation
import MachO

#if arch(arm64)
@inline(__always)  // just for Swift
public func replaceSymbol(_ symbol: String,
                          newMethod: UnsafeMutableRawPointer,
                          oldMethod: inout UnsafeMutableRawPointer?)
{
    for i in 0..<_dyld_image_count() {
        if let image = _dyld_get_image_header(i) {
            replaceSymbol(symbol, at: image, imageSlide: _dyld_get_image_vmaddr_slide(i), newMethod: newMethod, oldMethod: &oldMethod)
        }
    }
}

@inline(__always)
public func replaceSymbol(_ symbol: String,
                          at image: UnsafePointer<mach_header>,
                          imageSlide slide: Int,
                          newMethod: UnsafeMutableRawPointer,
                          oldMethod: inout UnsafeMutableRawPointer?)
{
    replaceSymbolAtImage(image, imageSlide: slide, symbol: symbol, newMethod: newMethod, oldMethod: &oldMethod)
}

@inline(__always)
private func replaceSymbolAtImage(_ image: UnsafePointer<mach_header>,
                                 imageSlide slide: Int,
                                 symbol: String,
                                 newMethod: UnsafeMutableRawPointer,
                                 oldMethod: inout UnsafeMutableRawPointer?)
{
    // __Linkedit cmd
    var linkeditCmd: UnsafeMutablePointer<segment_command_64>!
    let linkeditName = SEG_LINKEDIT.data(using: String.Encoding.utf8)!.map({ $0 })
    
    // Symbol cmd
    var symtabCmd: UnsafeMutablePointer<symtab_command>!
    var dynamicSymtabCmd: UnsafeMutablePointer<dysymtab_command>!
    
    // __Data cmd
    var dataCmd: UnsafeMutablePointer<segment_command_64>!
    let segData = SEG_DATA.data(using: String.Encoding.utf8)!.map({ Int8($0) })
    
    
    guard var curCmd = UnsafeMutablePointer<segment_command_64>(bitPattern: UInt(bitPattern: image)+UInt(MemoryLayout<mach_header_64>.size)) else { return }
    
    for _ in 0..<image.pointee.ncmds {
        curCmd = UnsafeMutableRawPointer(curCmd).advanced(by: Int(curCmd.pointee.cmdsize)).assumingMemoryBound(to: segment_command_64.self)
        
        if curCmd.pointee.cmd == LC_SEGMENT_64 {
            if UInt8(curCmd.pointee.segname.0) == linkeditName[0] &&
                UInt8(curCmd.pointee.segname.1) == linkeditName[1] &&
                UInt8(curCmd.pointee.segname.2) == linkeditName[2] &&
                UInt8(curCmd.pointee.segname.3) == linkeditName[3] &&
                UInt8(curCmd.pointee.segname.4) == linkeditName[4] &&
                UInt8(curCmd.pointee.segname.5) == linkeditName[5] &&
                UInt8(curCmd.pointee.segname.6) == linkeditName[6] &&
                UInt8(curCmd.pointee.segname.7) == linkeditName[7] &&
                UInt8(curCmd.pointee.segname.8) == linkeditName[8] &&
                UInt8(curCmd.pointee.segname.9) == linkeditName[9] {
                
                linkeditCmd = curCmd
            }
            if curCmd.pointee.segname.0 == segData[0] &&
                curCmd.pointee.segname.1 == segData[1] &&
                curCmd.pointee.segname.2 == segData[2] &&
                curCmd.pointee.segname.3 == segData[3] &&
                curCmd.pointee.segname.4 == segData[4] &&
                curCmd.pointee.segname.5 == segData[5] {
                
                dataCmd = curCmd
            }
            
        } else if curCmd.pointee.cmd == LC_SYMTAB {
            symtabCmd = UnsafeMutablePointer<symtab_command>(OpaquePointer(curCmd))
        }  else if curCmd.pointee.cmd == LC_DYSYMTAB {
            dynamicSymtabCmd = UnsafeMutablePointer<dysymtab_command>(OpaquePointer(curCmd))
        }
    }
    
    if linkeditCmd == nil || symtabCmd == nil || dynamicSymtabCmd == nil || dataCmd == nil {
        return
    }
    
    let linkedBase = slide + Int(linkeditCmd.pointee.vmaddr) - Int(linkeditCmd.pointee.fileoff)
    let symtab = UnsafeMutablePointer<nlist_64>(bitPattern: linkedBase + Int(symtabCmd.pointee.symoff))
    let strtab =  UnsafeMutablePointer<UInt8>(bitPattern: linkedBase + Int(symtabCmd.pointee.stroff))
    let indirectsym = UnsafeMutablePointer<UInt32>(bitPattern: linkedBase + Int(dynamicSymtabCmd.pointee.indirectsymoff))
    
    if symtab == nil || strtab == nil || indirectsym == nil {
        return
    }
    
    for j in 0..<dataCmd.pointee.nsects {
        let curSection = UnsafeMutableRawPointer(dataCmd).advanced(by: MemoryLayout<segment_command_64>.size + MemoryLayout<section_64>.size*Int(j)).assumingMemoryBound(to: section_64.self)
        
        // symbol_pointers sections
        if curSection.pointee.flags == S_LAZY_SYMBOL_POINTERS {
            replaceSymbolPointerAtSection(curSection, symtab: symtab!, strtab: strtab!, indirectsym: indirectsym!, slide: slide, symbolName: symbol, newMethod: newMethod, oldMethod: &oldMethod)
        }
        if curSection.pointee.flags == S_NON_LAZY_SYMBOL_POINTERS {
            replaceSymbolPointerAtSection(curSection, symtab: symtab!, strtab: strtab!, indirectsym: indirectsym!, slide: slide, symbolName: symbol, newMethod: newMethod, oldMethod: &oldMethod)
        }
    }
}

@inline(__always)
private func replaceSymbolPointerAtSection(_ section: UnsafeMutablePointer<section_64>,
                                           symtab: UnsafeMutablePointer<nlist_64>,
                                           strtab: UnsafeMutablePointer<UInt8>,
                                           indirectsym: UnsafeMutablePointer<UInt32>,
                                           slide: Int,
                                           symbolName: String,
                                           newMethod: UnsafeMutableRawPointer,
                                           oldMethod: inout UnsafeMutableRawPointer?)
{
    let indirectSymVmAddr = indirectsym.advanced(by: Int(section.pointee.reserved1))
    let sectionVmAddr = UnsafeMutablePointer<UnsafeMutableRawPointer>(bitPattern: slide+Int(section.pointee.addr))
    
    if sectionVmAddr == nil {
        return
    }
    
    for i in 0..<Int(section.pointee.size)/MemoryLayout<UnsafeMutableRawPointer>.size {
        let curIndirectSym = indirectSymVmAddr.advanced(by: i)
        if (curIndirectSym.pointee == INDIRECT_SYMBOL_ABS || curIndirectSym.pointee == INDIRECT_SYMBOL_LOCAL) {
            continue
        }
        let curStrTabOff = symtab.advanced(by: Int(curIndirectSym.pointee)).pointee.n_un.n_strx
        let curSymbolName = strtab.advanced(by: Int(curStrTabOff+1))
    
        if String(cString: curSymbolName) == symbolName {
            oldMethod = sectionVmAddr!.advanced(by: i).pointee
            sectionVmAddr!.advanced(by: i).initialize(to: newMethod)
            break
        }
    }
}
#endif
