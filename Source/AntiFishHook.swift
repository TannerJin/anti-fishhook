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
public class FishHookChecker {

    static private let BIND_TYPE_THREADED_REBASE = 102
    
    @inline(__always)
    static private func readUleb128(ptr: inout UnsafeMutablePointer<UInt8>, end: UnsafeMutablePointer<UInt8>) -> UInt64 {
        var result: UInt64 = 0
        var bit = 0
        var readNext = true

        repeat {
            if ptr == end {
                assert(false, "malformed uleb128")
            }
            let slice = UInt64(ptr.pointee & 0x7f)
            if bit > 63 {
                assert(false, "uleb128 too big for uint64")
            } else {
                result |= (slice << bit)
                bit += 7
            }
            readNext = ((ptr.pointee & 0x80) >> 7) == 1
            ptr += 1
        } while (readNext)
        return result
    }
    
    @inline(__always)
    static private func readSleb128(ptr: inout UnsafeMutablePointer<UInt8>, end: UnsafeMutablePointer<UInt8>) -> Int64 {
        var result: Int64 = 0
        var bit: Int = 0
        var byte: UInt8
        
        repeat {
            if (ptr == end) {
                assert(false, "malformed sleb128")
            }
            byte = ptr.pointee
            result |= (((Int64)(byte & 0x7f)) << bit);
            bit += 7
            ptr += 1
        } while (byte & 0x80) == 1;
        
        // sign extend negative numbers
        if ( (byte & 0x40) != 0 ) {
            result |= -1 << bit
        }
        
        return result
    }

    @inline(__always)
    static public func denyFishHook(_ symbol: String) {
        var symbolAddress: UnsafeMutableRawPointer?
        
        for imgIndex in 0..<_dyld_image_count() {
            if let image = _dyld_get_image_header(imgIndex) {
                if symbolAddress == nil {
                    _ = lookSymbol(symbol, at: image, imageSlide: _dyld_get_image_vmaddr_slide(imgIndex), symbolAddress: &symbolAddress)
                }
                if let symbolPointer = symbolAddress {
                    var oldMethod: UnsafeMutableRawPointer?
                    FishHook.replaceSymbol(symbol, at: image, imageSlide: _dyld_get_image_vmaddr_slide(imgIndex), newMethod: symbolPointer, oldMethod: &oldMethod)
                }
            }
        }
    }
    
    @inline(__always)
    static public func denyFishHook(_ symbol: String,
                             at image: UnsafePointer<mach_header>,
                             imageSlide slide: Int) {
        var symbolAddress: UnsafeMutableRawPointer?
        
        if lookSymbol(symbol, at: image, imageSlide: slide, symbolAddress: &symbolAddress), let symbolPointer = symbolAddress {
            var oldMethod: UnsafeMutableRawPointer?
            FishHook.replaceSymbol(symbol, at: image, imageSlide: slide, newMethod: symbolPointer, oldMethod: &oldMethod)
        }
    }

    @inline(__always)
    static func lookSymbol(_ symbol: String,
                             at image: UnsafePointer<mach_header>,
                             imageSlide slide: Int,
                             symbolAddress: inout UnsafeMutableRawPointer?) -> Bool {
        // Linked cmd
        var linkeditCmd: UnsafeMutablePointer<segment_command_64>!
        var dyldInfoCmd: UnsafeMutablePointer<dyld_info_command>!
        var allLoadDylds = [String]()

        guard var curCmdPointer = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: image)+UInt(MemoryLayout<mach_header_64>.size)) else { return false }
        for _ in 0..<image.pointee.ncmds {
            let curCmd = curCmdPointer.assumingMemoryBound(to: segment_command_64.self)
            
            switch UInt32(curCmd.pointee.cmd) {
            case UInt32(LC_SEGMENT_64):
                let offset = MemoryLayout.size(ofValue: curCmd.pointee.cmd) + MemoryLayout.size(ofValue: curCmd.pointee.cmdsize)
                let curCmdName = String(cString: curCmdPointer.advanced(by: offset).assumingMemoryBound(to: Int8.self))
                if (curCmdName == SEG_LINKEDIT) {
                    linkeditCmd = curCmd
                }
            case LC_DYLD_INFO_ONLY:
                dyldInfoCmd = curCmdPointer.assumingMemoryBound(to: dyld_info_command.self)
            case UInt32(LC_LOAD_DYLIB), LC_LOAD_WEAK_DYLIB, LC_LOAD_UPWARD_DYLIB, LC_REEXPORT_DYLIB:
                let loadDyldCmd = curCmdPointer.assumingMemoryBound(to: dylib_command.self)
                let loadDyldNameOffset = Int(loadDyldCmd.pointee.dylib.name.offset)
                let loadDyldNamePointer = curCmdPointer.advanced(by: loadDyldNameOffset).assumingMemoryBound(to: Int8.self)
                let loadDyldName = String(cString: loadDyldNamePointer)
                allLoadDylds.append(loadDyldName)
            default:
                break
            }
            
            curCmdPointer = curCmdPointer + Int(curCmd.pointee.cmdsize)
        }

        if linkeditCmd == nil || dyldInfoCmd == nil { return false }
        let linkeditBase = UInt64(slide + Int(linkeditCmd.pointee.vmaddr) - Int(linkeditCmd.pointee.fileoff))
        
        // look by LazyBindInfo
        let lazyBindSize = dyldInfoCmd.pointee.lazy_bind_size
        if (lazyBindSize > 0) {
            if let lazyBindInfoCmd = UnsafeMutablePointer<UInt8>(bitPattern: UInt(linkeditBase + UInt64(dyldInfoCmd.pointee.lazy_bind_off))),
               lookLazyBindSymbol(symbol, lazyBindInfoCmd: lazyBindInfoCmd, lazyBindInfoSize: Int(lazyBindSize), allDependentDylds: allLoadDylds, symbolAddress: &symbolAddress) {
                return true
            }
        }
        
        // look by NonLazyBindInfo
        let bindSize = dyldInfoCmd.pointee.bind_size
        if (bindSize > 0) {
            if let nonLazyBindInfoCmd = UnsafeMutablePointer<UInt8>(bitPattern: UInt(linkeditBase + UInt64(dyldInfoCmd.pointee.bind_off))),
               lookNonLazyBindSymbol(symbol, nonLazyBindInfoCmd: nonLazyBindInfoCmd, nonLazyBindInfoSize: Int(bindSize), allDependentDylds: allLoadDylds, symbolAddress: &symbolAddress) {
                return true
            }
        }
        
        return false
    }
    
    @inline(__always)
    private static func lookNonLazyBindSymbol(_ symbol: String,
                                         nonLazyBindInfoCmd: UnsafeMutablePointer<UInt8>,
                                         nonLazyBindInfoSize: Int,
                                         allDependentDylds: [String],
                                         symbolAddress: inout UnsafeMutableRawPointer?) -> Bool {
        var ptr = nonLazyBindInfoCmd
        let bindingInfoEnd = nonLazyBindInfoCmd.advanced(by: Int(nonLazyBindInfoSize))
        var ordinal: Int = -1
        var foundSymbol = false
        var addend = 0
        var type: Int32 = 0
        
        Label: while ptr < bindingInfoEnd {
            let immediate = Int32(ptr.pointee) & BIND_IMMEDIATE_MASK
            let opcode = Int32(ptr.pointee) & BIND_OPCODE_MASK
            ptr += 1
            
            switch opcode {
            case BIND_OPCODE_DONE:
                break Label
                // ORDINAL DYLIB
            case BIND_OPCODE_SET_DYLIB_ORDINAL_IMM:
                ordinal = Int(immediate)
            case BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB:
                ordinal = Int(readUleb128(ptr: &ptr, end: bindingInfoEnd))
            case BIND_OPCODE_SET_DYLIB_SPECIAL_IMM:
                if immediate == 0 {
                   ordinal = 0
                } else {
                    ordinal = Int(Int8(BIND_OPCODE_MASK | immediate))
                }
                // symbol
            case BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM:
                let symbolName = String(cString: ptr + 1)
                print(symbolName)
                if (symbolName == symbol) {
                    foundSymbol = true
                }
                while ptr.pointee != 0 {
                    ptr += 1
                }
                ptr += 1 // '00'
            case BIND_OPCODE_SET_TYPE_IMM:
                type = immediate
                continue
                // sleb
            case BIND_OPCODE_SET_ADDEND_SLEB:
                addend = Int(readSleb128(ptr: &ptr, end: bindingInfoEnd))
                // uleb
            case BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB, BIND_OPCODE_ADD_ADDR_ULEB:
                _ = readUleb128(ptr: &ptr, end: bindingInfoEnd)
                // do bind action
            case BIND_OPCODE_DO_BIND, BIND_OPCODE_DO_BIND_ADD_ADDR_IMM_SCALED:
                if (foundSymbol) {
                    break Label
                }
            case BIND_OPCODE_DO_BIND_ADD_ADDR_ULEB:
                if (foundSymbol) {
                    break Label
                } else {
                    _ = readUleb128(ptr: &ptr, end: bindingInfoEnd)
                }
            case BIND_OPCODE_DO_BIND_ULEB_TIMES_SKIPPING_ULEB:
                if (foundSymbol) {
                    break Label
                } else {
                    _ = readUleb128(ptr: &ptr, end: bindingInfoEnd)  // count
                    _ = readUleb128(ptr: &ptr, end: bindingInfoEnd)  // skip
                }
            case BIND_OPCODE_THREADED:
                switch immediate {
                case BIND_SUBOPCODE_THREADED_SET_BIND_ORDINAL_TABLE_SIZE_ULEB:
                    _ = readUleb128(ptr: &ptr, end: bindingInfoEnd)
                case BIND_SUBOPCODE_THREADED_APPLY:
                    if (foundSymbol) {
                        // ImageLoaderMachO::bindLocation case BIND_TYPE_THREADED_REBASE
                        assert(false, "maybe bind_type is BIND_TYPE_THREADED_REBASE, don't handle")
                        return false
                    }
                    continue Label
                default:
                    assert(false, "bad bind subopcode")
                    return false
                }
            default:
                assert(false, "bad bind opcode")
                return false
            }
        }

        assert(ordinal <= allDependentDylds.count)
        if (foundSymbol && ordinal >= 0 && allDependentDylds.count > 0), ordinal <= allDependentDylds.count, type != BIND_TYPE_THREADED_REBASE {
            let imageName = allDependentDylds[ordinal-1]
            var _symbolAddress: UnsafeMutableRawPointer?
            if lookExportedSymbol(symbol, exportImageName: imageName, symbolAddress: &_symbolAddress), let symbolPointer = _symbolAddress {
                symbolAddress = symbolPointer + addend
                return true
            }
        }
        
        return false
    }
    
    @inline(__always)
    private static func lookLazyBindSymbol(_ symbol: String,
                                         lazyBindInfoCmd: UnsafeMutablePointer<UInt8>,
                                         lazyBindInfoSize: Int,
                                         allDependentDylds: [String],
                                         symbolAddress: inout UnsafeMutableRawPointer?) -> Bool {
        var ptr = lazyBindInfoCmd
        let lazyBindingInfoEnd = lazyBindInfoCmd.advanced(by: Int(lazyBindInfoSize))
        var ordinal: Int = -1
        var foundSymbol = false
        var addend = 0
        var type: Int32 = 0
        
        Label: while ptr < lazyBindingInfoEnd {
            let immediate = Int32(ptr.pointee) & BIND_IMMEDIATE_MASK
            let opcode = Int32(ptr.pointee) & BIND_OPCODE_MASK
            ptr += 1
            
            switch opcode {
            case BIND_OPCODE_DONE:
                continue
                // ORDINAL DYLIB
            case BIND_OPCODE_SET_DYLIB_ORDINAL_IMM:
                ordinal = Int(immediate)
            case BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB:
                ordinal = Int(readUleb128(ptr: &ptr, end: lazyBindingInfoEnd))
            case BIND_OPCODE_SET_DYLIB_SPECIAL_IMM:
                if immediate == 0 {
                   ordinal = 0
                } else {
                    ordinal = Int(BIND_OPCODE_MASK | immediate)
                }
                // symbol
            case BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM:
                let symbolName = String(cString: ptr + 1)
//                print(symbolName)
                if (symbolName == symbol) {
                    foundSymbol = true
                }
                while ptr.pointee != 0 {
                    ptr += 1
                }
                ptr += 1 // '00'
            case BIND_OPCODE_SET_TYPE_IMM:
                type = immediate
                continue
                // sleb
            case BIND_OPCODE_SET_ADDEND_SLEB:
                addend = Int(readSleb128(ptr: &ptr, end: lazyBindingInfoEnd))
                // uleb
            case BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB, BIND_OPCODE_ADD_ADDR_ULEB:
                _ = readUleb128(ptr: &ptr, end: lazyBindingInfoEnd)
                // bind action
            case BIND_OPCODE_DO_BIND:
                if (foundSymbol) {
                    break Label
                } else {
                    continue
                }
            default:
                assert(false, "bad lazy bind opcode")
                return false
            }
        }
        
        assert(ordinal <= allDependentDylds.count)

        if (foundSymbol && ordinal >= 0 && allDependentDylds.count > 0), ordinal <= allDependentDylds.count, type != BIND_TYPE_THREADED_REBASE {
            let imageName = allDependentDylds[ordinal-1]
            var _symbolAddress: UnsafeMutableRawPointer?
            if lookExportedSymbol(symbol, exportImageName: imageName, symbolAddress: &_symbolAddress), let symbolPointer = _symbolAddress {
                symbolAddress = symbolPointer + addend
                return true
            }
        }
        
        return false
    }
    
    @inline(__always)
    private static func lookExportedSymbol(_ symbol: String,
                                           exportImageName: String,
                                           symbolAddress: inout UnsafeMutableRawPointer?) -> Bool
    {
        var rpathImage: String?
        // @rpath
        if (exportImageName.contains("@rpath")){
            rpathImage = exportImageName.components(separatedBy: "/").last
        }
        
        for index in 0..<_dyld_image_count() {
            let currentImage = String(cString: _dyld_get_image_name(index))
                    
            if let _rpathImage = rpathImage {
                if (!currentImage.contains(_rpathImage)) {
                    continue
                }
            } else if (String(cString: _dyld_get_image_name(index)) != exportImageName) {
                continue
            }
            
            if let pointer = _lookExportedSymbol(symbol, image: _dyld_get_image_header(index), imageSlide: _dyld_get_image_vmaddr_slide(index)) {
                // found
                symbolAddress = UnsafeMutableRawPointer(mutating: pointer)
                return true
            } else {
                // not found, look at ReExport dylib
                var allReExportDylibs = [String]()
                
                if let currentImage = _dyld_get_image_header(index),
                   var curCmdPointer = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: currentImage)+UInt(MemoryLayout<mach_header_64>.size)) {
                    
                    for _ in 0..<currentImage.pointee.ncmds {
                        let curCmd = curCmdPointer.assumingMemoryBound(to: segment_command_64.self)
                        if (curCmd.pointee.cmd == LC_REEXPORT_DYLIB) {
                            let reExportDyldCmd = curCmdPointer.assumingMemoryBound(to: dylib_command.self)
                            let reExportDyldNameOffset = Int(reExportDyldCmd.pointee.dylib.name.offset)
                            let reExportDyldNamePointer = curCmdPointer.advanced(by: reExportDyldNameOffset).assumingMemoryBound(to: Int8.self)
                            let reExportDyldName = String(cString: reExportDyldNamePointer)
                            allReExportDylibs.append(reExportDyldName)
                        }
                        curCmdPointer = curCmdPointer + Int(curCmd.pointee.cmdsize)
                    }
                }
                
                for reExportDyld in allReExportDylibs {
                    if lookExportedSymbol(symbol, exportImageName: reExportDyld, symbolAddress: &symbolAddress) {
                        return true
                    }
                }
                // not found, stop
                return false
            }
        }
        
        return false
    }
    
    @inline(__always)
    static private func _lookExportedSymbol(_ symbol: String, image: UnsafePointer<mach_header>, imageSlide slide: Int) -> UnsafeMutableRawPointer? {
        var linkeditCmd: UnsafeMutablePointer<segment_command_64>!
        var dyldInfoCmd: UnsafeMutablePointer<dyld_info_command>!

        guard var curCmdPointer = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: image)+UInt(MemoryLayout<mach_header_64>.size)) else {
            return nil
        }
        
        for _ in 0..<image.pointee.ncmds {
            let curCmd = curCmdPointer.assumingMemoryBound(to: segment_command_64.self)
            if curCmd.pointee.cmd == LC_SEGMENT_64 {
                let offset = MemoryLayout.size(ofValue: curCmd.pointee.cmd) + MemoryLayout.size(ofValue: curCmd.pointee.cmdsize)
                let curCmdName = String(cString: curCmdPointer.advanced(by: offset).assumingMemoryBound(to: Int8.self))
                if (curCmdName == SEG_LINKEDIT) {
                    linkeditCmd = curCmd
                }
            } else if curCmd.pointee.cmd == LC_DYLD_INFO_ONLY {
                dyldInfoCmd = curCmdPointer.assumingMemoryBound(to: dyld_info_command.self)
            }
            curCmdPointer = curCmdPointer + Int(curCmd.pointee.cmdsize)
        }

        if linkeditCmd == nil || dyldInfoCmd == nil || dyldInfoCmd.pointee.export_size == 0 { return nil }
        let linkeditBase = Int(slide + Int(linkeditCmd.pointee.vmaddr) - Int(linkeditCmd.pointee.fileoff))
        guard let exportedInfo = UnsafeMutableRawPointer(bitPattern: linkeditBase + Int(dyldInfoCmd.pointee.export_off))?.assumingMemoryBound(to: UInt8.self) else { return nil }
        
        let start = exportedInfo
        let end = exportedInfo + Int(dyldInfoCmd.pointee.export_size)
             
        if var symbolLocation = lookExportedSymbolByTrieWalk(targetSymbol: symbol, start: start, end: end, currentLocation: start, currentSymbol: "") {
            let flags = readUleb128(ptr: &symbolLocation, end: end)

            let returnSymbolAddress = { () -> UnsafeMutableRawPointer in
                let machO = image.withMemoryRebound(to: Int8.self, capacity: 1, { $0 })
                let symbolAddress = machO.advanced(by: Int(readUleb128(ptr: &symbolLocation, end: end)))
                return UnsafeMutableRawPointer(mutating: symbolAddress)
            }
            
            switch flags & UInt64(EXPORT_SYMBOL_FLAGS_KIND_MASK) {
            case UInt64(EXPORT_SYMBOL_FLAGS_KIND_REGULAR):
                return returnSymbolAddress()
            case UInt64(EXPORT_SYMBOL_FLAGS_KIND_THREAD_LOCAL):
                if (flags & UInt64(EXPORT_SYMBOL_FLAGS_STUB_AND_RESOLVER) != 0) {
                    return nil
                }
                return returnSymbolAddress()
            case UInt64(EXPORT_SYMBOL_FLAGS_KIND_ABSOLUTE):
                if (flags & UInt64(EXPORT_SYMBOL_FLAGS_STUB_AND_RESOLVER) != 0) {
                    return nil
                }
                return UnsafeMutableRawPointer(bitPattern: UInt(readUleb128(ptr: &symbolLocation, end: end)))
            default:
                break
            }
        }
        
        return nil
    }
    
    
    @inline(__always)
    static private func lookExportedSymbolByTrieWalk(targetSymbol: String, start: UnsafeMutablePointer<UInt8>, end: UnsafeMutablePointer<UInt8>, currentLocation location: UnsafeMutablePointer<UInt8>, currentSymbol: String) -> UnsafeMutablePointer<UInt8>? {
        var p = location
        
        while p <= end {
            // terminalSize
            var terminalSize = UInt64(p.pointee)
            p += 1
            if terminalSize > 127 {
                p -= 1
                terminalSize = readUleb128(ptr: &p, end: end)
            }
            if terminalSize != 0 {
                return currentSymbol == targetSymbol ? p : nil
            }
            
            // children
            let children = p.advanced(by: Int(terminalSize))
            if children >= end {
                // end
                return nil
            }
            let childrenCount = children.pointee
            p = children + 1
            
            // nodes
            for _ in 0..<childrenCount {
                let nodeLabel = p.withMemoryRebound(to: CChar.self, capacity: 1, { $0 })
                
                // node offset
                while p.pointee != 0 {
                    p += 1
                }
                p += 1  // = "00"
                let nodeOffset = Int(readUleb128(ptr: &p, end: end))
                
                // node
                if let nodeSymbol = String(cString: nodeLabel, encoding: .utf8) {
                    let _currentSymbol = currentSymbol + nodeSymbol
//                   print(_currentSymbol)    // for debug

                    if !targetSymbol.contains(_currentSymbol) {
                        continue
                    }
                    if nodeOffset != 0 && (start + nodeOffset <= end) {
                        if let symbolLocation = lookExportedSymbolByTrieWalk(targetSymbol: targetSymbol, start: start, end: end, currentLocation: start.advanced(by: nodeOffset), currentSymbol: _currentSymbol) {
                            return symbolLocation
                        }
                    }
                }
            }
        }
        return nil
    }
}
#endif
