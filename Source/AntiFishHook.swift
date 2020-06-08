//
//  FishHookProtection.swift
//  FishHookProtect
//
//  Created by jintao on 2019/3/25.
//  Copyright © 2019 jintao. All rights reserved.
//

import Foundation
import MachO

#if arch(arm64)
@inline(__always)
private func readUleb128(p: inout UnsafePointer<UInt8>, end: UnsafePointer<UInt8>) -> UInt64 {
    var result: UInt64 = 0
    var bit = 0
    var readNext = true
    
    repeat {
        if p == end {
            assert(false, "malformed uleb128")
        }
        let slice = UInt64(p.pointee & 0x7f)
        if bit > 63 {
            assert(false, "uleb128 too big for uint64")
        } else {
            result |= (slice << bit)
            bit += 7
        }
        readNext = ((p.pointee & 0x80) >> 7) == 1
        p += 1
    } while (readNext)
    return result
}

@inline(__always)
@_cdecl("resetSymbol")  // support Swift, OC
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
                         imageSlide slide: Int)
{
    // Linked cmd
    let linkeditCmdName = SEG_LINKEDIT.data(using: String.Encoding.utf8)!.map({ $0 })
    var linkeditCmd: UnsafeMutablePointer<segment_command_64>!
    var dyldInfoCmd: UnsafeMutablePointer<dyld_info_command>!
    
    // Text cmd
    let textCmdName = SEG_TEXT.data(using: String.Encoding.utf8)!.map({ Int8($0) })
    var textCmd: UnsafeMutablePointer<segment_command_64>!
    
    guard var curCmd = UnsafeMutablePointer<segment_command_64>(bitPattern: UInt(bitPattern: image)+UInt(MemoryLayout<mach_header_64>.size)) else { return }
    
    for _ in 0..<image.pointee.ncmds {
        curCmd = UnsafeMutableRawPointer(curCmd).advanced(by: Int(curCmd.pointee.cmdsize)).assumingMemoryBound(to: segment_command_64.self)
        
        if curCmd.pointee.cmd == LC_SEGMENT_64 {
            if (curCmd.pointee.segname.0 == linkeditCmdName[0] &&
                curCmd.pointee.segname.1 == linkeditCmdName[1] &&
                curCmd.pointee.segname.2 == linkeditCmdName[2] &&
                curCmd.pointee.segname.3 == linkeditCmdName[3] &&
                curCmd.pointee.segname.4 == linkeditCmdName[4] &&
                curCmd.pointee.segname.5 == linkeditCmdName[5] &&
                curCmd.pointee.segname.6 == linkeditCmdName[6] &&
                curCmd.pointee.segname.7 == linkeditCmdName[7] &&
                curCmd.pointee.segname.8 == linkeditCmdName[8] &&
                curCmd.pointee.segname.9 == linkeditCmdName[9]) {
                
                linkeditCmd = curCmd
            }
            if (curCmd.pointee.segname.0 == textCmdName[0] &&
                curCmd.pointee.segname.1 == textCmdName[1] &&
                curCmd.pointee.segname.2 == textCmdName[2] &&
                curCmd.pointee.segname.3 == textCmdName[3] &&
                curCmd.pointee.segname.4 == textCmdName[4] &&
                curCmd.pointee.segname.5 == textCmdName[5]) {
                
                textCmd = curCmd
            }
        } else if curCmd.pointee.cmd == LC_DYLD_INFO_ONLY || curCmd.pointee.cmd == LC_DYLD_INFO {
            dyldInfoCmd = UnsafeMutablePointer<dyld_info_command>(OpaquePointer(UnsafeRawPointer(curCmd)))
        }
    }
    
    if linkeditCmd == nil || dyldInfoCmd == nil || textCmd == nil { return }
    
    let linkeditBase = UInt64(slide) + linkeditCmd.pointee.vmaddr - linkeditCmd.pointee.fileoff
    let lazyBindInfoCmd = linkeditBase + UInt64(dyldInfoCmd.pointee.lazy_bind_off)
    
    rebindLazySymbol(symbol: symbol, image: image, imageSlide: slide, textCmd: textCmd, lazyBindInfoCmd: UnsafePointer<UInt8>(bitPattern: UInt(lazyBindInfoCmd)), lazyBindInfoSize: Int(dyldInfoCmd.pointee.lazy_bind_size))
        
    // TODO: rebindNonLazySymbol
}

// MARK: - LazySymbol (wait to do)

// if symbol is LazySymbol
// dyld_stub_binder => fastBindLazySymbol => doBindFastLazySymbol => ImageLoaderMachO::getLazyBindingInfo
@inline(__always)
private func rebindLazySymbol(symbol: String,
                               image: UnsafePointer<mach_header>,
                               imageSlide slide: Int,
                               textCmd: UnsafeMutablePointer<segment_command_64>,
                               lazyBindInfoCmd: UnsafePointer<UInt8>!,
                               lazyBindInfoSize: Int) {
    if lazyBindInfoCmd == nil {
        return
    }
    
    var stubHelperSection: UnsafeMutablePointer<section_64>!
    let stubHelperSectionName: (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8) = (0x5f, 0x5f, 0x73, 0x74, 0x75, 0x62, 0x5f, 0x68, 0x65, 0x6c, 0x70, 0x65, 0x72, 0x00, 0x00, 0x00)
    
    for i in 0..<textCmd.pointee.nsects {
        let curSectionPointer = UnsafeRawPointer(textCmd).advanced(by: MemoryLayout<segment_command_64>.size + MemoryLayout<section_64>.size*Int(i))
        let curSection = UnsafeMutablePointer<section_64>(OpaquePointer(curSectionPointer))
        
        if curSection.pointee.sectname.0 == stubHelperSectionName.0 &&
            curSection.pointee.sectname.1 == stubHelperSectionName.1 &&
            curSection.pointee.sectname.2 == stubHelperSectionName.2 &&
            curSection.pointee.sectname.3 == stubHelperSectionName.3 &&
            curSection.pointee.sectname.4 == stubHelperSectionName.4 &&
            curSection.pointee.sectname.5 == stubHelperSectionName.5 &&
            curSection.pointee.sectname.6 == stubHelperSectionName.6 &&
            curSection.pointee.sectname.7 == stubHelperSectionName.7 &&
            curSection.pointee.sectname.8 == stubHelperSectionName.8 &&
            curSection.pointee.sectname.9 == stubHelperSectionName.9 &&
            curSection.pointee.sectname.10 == stubHelperSectionName.10 &&
            curSection.pointee.sectname.11 == stubHelperSectionName.11 &&
            curSection.pointee.sectname.12 == stubHelperSectionName.12 {
            
            stubHelperSection = curSection
            break
        }
    }
    
    // look for code of symbol_binder_code
    guard stubHelperSection != nil,
        let stubHelperVmAddr = UnsafeMutablePointer<UInt32>(bitPattern: slide+Int(stubHelperSection.pointee.addr)) else {
            return
        }
    
    // from begin of stub_helper to symbol_binder_code
    var codeOffset: Int!
    
    // 6 instructions: code of `br dyld_stub_binder`
    if stubHelperSection.pointee.size/4 <= 5 {
        return
    }
    let lazyBindingInfoStart = lazyBindInfoCmd!
    let lazyBindingInfoEnd = lazyBindInfoCmd! + lazyBindInfoSize
    
    for i in 5..<stubHelperSection.pointee.size/4 {
        /*  at C4.4.5 and C6.2.84 of ARM® Architecture Reference Manual
            ldr w16, #8 (.byte)
            b stub(br_dyld_stub_binder)
            .byte: symbol_bindInfo_offset
         */
        let instruction = stubHelperVmAddr.advanced(by: Int(i)).pointee
        // ldr wt
        let ldr = (instruction & (255 << 24)) >> 24
        let wt = instruction & (31 << 0)
        // #imm `00` sign = false
        let imm19 = (instruction & ((1 << 19 - 1) << 5)) >> 5
        
        // ldr w16, #8
        if ldr == 0b00011000 && wt == 16 && (imm19 << 2) == 8 {
            let bindingInfoOffset = stubHelperVmAddr.advanced(by: Int(i+2)).pointee  // .byte
            var p = lazyBindingInfoStart.advanced(by: Int(bindingInfoOffset))
            
            Label: while p <= lazyBindingInfoEnd  {
                let opcode = Int32(p.pointee) & BIND_OPCODE_MASK
                
                switch opcode {
                case BIND_OPCODE_DONE, BIND_OPCODE_SET_DYLIB_ORDINAL_IMM:
                    p += 1
                    continue Label
                case BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB, BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB:
                    p += 1
                    _ = readUleb128(p: &p, end: lazyBindingInfoEnd)
                    continue Label
                case BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM:
                    p += 1
                    // _symbol
                    if String(cString: p + 1) == symbol {
                        codeOffset = Int(i)
                        break
                    }
                    while p.pointee != 0 {  // '\0'
                        p += 1
                    }
                    continue Label
                case BIND_OPCODE_DO_BIND:
                    break Label
                default:
                    p += 1
                    continue Label
                }
            }
        }
    }
    
    if codeOffset == nil {
        return
    }
    
    let pointer = stubHelperVmAddr.advanced(by: (codeOffset))  // ldr w16 .byte
    let newMethod = UnsafeMutablePointer(pointer)
    var oldMethod: UnsafeMutableRawPointer? = nil
    replaceSymbol(symbol, at: image, imageSlide: slide, newMethod: newMethod, oldMethod: &oldMethod)
}

// MARK: - NoLazySymbol

/*  TODO:
 
// if symbol is non_lazy_symbol
// ImageLoader::recursiveBind => doBind => eachBind => bindAt => findByExportedSymbol
@inline(__always)
private func rebindNonLazySymbol(_ symbol: String,
                                    image: UnsafePointer<mach_header>,
                                    imageSlide slide: Int,
                                    bindInfoCmd: UnsafePointer<UInt8>!,
                                    bindInfoSize: Int) {
    
    let all_load_dyld = getAllLoadDyld(image: image)
    var libraryOrdinal: Int?
    
    // wait to do for opcode
    for i in 0..<bindInfoSize {
        let opcode = Int32(bindInfoCmd.pointee) & BIND_OPCODE_MASK
        let immediate = Int32(bindInfoCmd.pointee) & BIND_IMMEDIATE_MASK
        
    }
}
 
*/


/* Release: Some symbols maybe strip at SymbolTable in this way
   
 */
// if symbol is non_lazy_symbol
// ImageLoader::recursiveBind => doBind => eachBind => bindAt => findByExportedSymbol
@inline(__always)
private func rebindNonLazySymbol2(_ symbol: String,
                                    image: UnsafePointer<mach_header>,
                                    imageSlide slide: Int) {
    // 1. dlopen
    // 2. dlsym
    // 3. replace

    // 0. which dyld is the symbol at
    let all_load_dyld = getAllLoadDyld(image: image)
    
    // __Linkedit cmd
    var linkeditCmd: UnsafeMutablePointer<segment_command_64>!
    let linkeditName = SEG_LINKEDIT.data(using: String.Encoding.utf8)!.map({ $0 })
    
    // Symbol cmd
    var symtabCmd: UnsafeMutablePointer<symtab_command>!
    var dynamicSymtabCmd: UnsafeMutablePointer<dysymtab_command>!
    
    guard var cur_cmd = UnsafeMutablePointer<segment_command_64>(bitPattern: UInt(bitPattern: image)+UInt(MemoryLayout<mach_header_64>.size)) else { return }
    
    for _ in 0..<image.pointee.ncmds {
        cur_cmd = UnsafeMutableRawPointer(cur_cmd).advanced(by: Int(cur_cmd.pointee.cmdsize)).assumingMemoryBound(to: segment_command_64.self)
        
        if cur_cmd.pointee.cmd == LC_SEGMENT_64 {
            if UInt8(cur_cmd.pointee.segname.0) == linkeditName[0] &&
                UInt8(cur_cmd.pointee.segname.1) == linkeditName[1] &&
                UInt8(cur_cmd.pointee.segname.2) == linkeditName[2] &&
                UInt8(cur_cmd.pointee.segname.3) == linkeditName[3] &&
                UInt8(cur_cmd.pointee.segname.4) == linkeditName[4] &&
                UInt8(cur_cmd.pointee.segname.5) == linkeditName[5] &&
                UInt8(cur_cmd.pointee.segname.6) == linkeditName[6] &&
                UInt8(cur_cmd.pointee.segname.7) == linkeditName[7] &&
                UInt8(cur_cmd.pointee.segname.8) == linkeditName[8] &&
                UInt8(cur_cmd.pointee.segname.9) == linkeditName[9] {
                
                linkeditCmd = cur_cmd
            }
        } else if cur_cmd.pointee.cmd == LC_SYMTAB {
            symtabCmd = UnsafeMutablePointer<symtab_command>(OpaquePointer(cur_cmd))
        }  else if cur_cmd.pointee.cmd == LC_DYSYMTAB {
            dynamicSymtabCmd = UnsafeMutablePointer<dysymtab_command>(OpaquePointer(cur_cmd))
        }
    }
    
    if linkeditCmd == nil || symtabCmd == nil || dynamicSymtabCmd == nil || all_load_dyld.count == 0 {
        return
    }
    
    let linkedBase = slide + Int(linkeditCmd.pointee.vmaddr) - Int(linkeditCmd.pointee.fileoff)
    let symtab = UnsafeMutablePointer<nlist_64>(bitPattern: linkedBase + Int(symtabCmd.pointee.symoff))
    let strtab =  UnsafeMutablePointer<UInt8>(bitPattern: linkedBase + Int(symtabCmd.pointee.stroff))
    let indirectsym = UnsafeMutablePointer<UInt32>(bitPattern: linkedBase + Int(dynamicSymtabCmd.pointee.indirectsymoff))
    
    if symtab == nil || strtab == nil || indirectsym == nil {
        return
    }
    
    var dyldName: String!
    
    for i in 0..<dynamicSymtabCmd.pointee.nindirectsyms {
        let offset = indirectsym!.advanced(by: Int(i)).pointee
        let _symbol = symtab!.advanced(by: Int(offset))
        
        let strOff = _symbol.pointee.n_un.n_strx
        let symbolName = strtab!.advanced(by: Int(strOff))
        let _symbolName = strtab!.advanced(by: Int(strOff+1))
    
        if String(cString: symbolName) == symbol || String(cString: _symbolName) == symbol {
            if let load_dyld_offset = get_library_ordinal(_symbol.pointee.n_desc),
                load_dyld_offset <= all_load_dyld.count {
                dyldName = all_load_dyld[Int(load_dyld_offset-1)]
            }
            break
        }
    }
    
    if dyldName == nil { return }
    
    // 1.
    let handle = dlopen(dyldName, RTLD_NOW)
    
    // 2. Exported Symbol
    if let symPointer = dlsym(handle, symbol) {
        var oldMethod: UnsafeMutableRawPointer? = nil
        // 3. replace
        replaceSymbol(symbol, at: image, imageSlide: slide, newMethod: symPointer, oldMethod: &oldMethod)
    }
}

// https://developer.apple.com/documentation/kernel/nlist_64/1583957-n_desc?language=objc
private func get_library_ordinal(_ value: UInt16) -> Int? {
//  REFERENCE_FLAG_UNDEFINED_NON_LAZY = 0x0
    if value & 0x00ff == 0x0 {
        return Int((value >> 8) & 0xff)
    }
    return nil
}

private func getAllLoadDyld(image: UnsafePointer<mach_header>) -> [String] {
    var all_load_dyld = [String]()
    
    guard var cur_cmd = UnsafeMutablePointer<segment_command_64>(bitPattern: UInt(bitPattern: image)+UInt(MemoryLayout<mach_header_64>.size)) else { return all_load_dyld }
       
    for _ in 0..<image.pointee.ncmds {
        cur_cmd = UnsafeMutableRawPointer(cur_cmd).advanced(by: Int(cur_cmd.pointee.cmdsize)).assumingMemoryBound(to: segment_command_64.self)
        
        if cur_cmd.pointee.cmd == LC_LOAD_DYLIB ||
            cur_cmd.pointee.cmd == LC_LOAD_WEAK_DYLIB ||
            cur_cmd.pointee.cmd == LC_REEXPORT_DYLIB {
        
            if let dyld_cmd = UnsafeMutablePointer<dylib_command>(bitPattern: UInt(bitPattern: cur_cmd)) {
                let str_off = dyld_cmd.pointee.dylib.name.offset
                let dyld_c_name = UnsafeMutableRawPointer(dyld_cmd).advanced(by: Int(str_off)).assumingMemoryBound(to: UInt8.self)
                all_load_dyld.append(String(cString: dyld_c_name))
            }
        }
    }
    
    return all_load_dyld
}
#endif
