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
private func readUleb128(ptr: inout UnsafeMutablePointer<UInt8>, end: UnsafeMutablePointer<UInt8>) -> UInt64 {
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
private func readSleb128(ptr: inout UnsafeMutablePointer<UInt8>, end: UnsafeMutablePointer<UInt8>) -> Int64 {
    var result: Int64 = 0
    var bit: Int = 0
    var byte: UInt8
    
    repeat {
        if (ptr == end) {
            assert(false, "malformed sleb128")
        }
        byte = ptr.pointee
        result |= (((Int64)(byte & 0x7f)) << bit)
        bit += 7
        ptr += 1
    } while (byte & 0x80) == 1
    
    // sign extend negative numbers
    if ( (byte & 0x40) != 0 ) {
        result |= -1 << bit
    }
    return result
}

public class FishHookChecker {
    @inline(__always)
    static public func denyFishHook(_ symbol: String) {
        var symbolAddress: UnsafeMutableRawPointer?
        
        for imgIndex in 0..<_dyld_image_count() {
            if let image = _dyld_get_image_header(imgIndex) {
                if symbolAddress == nil {
                    _ = SymbolFound.lookSymbol(symbol, at: image, imageSlide: _dyld_get_image_vmaddr_slide(imgIndex), symbolAddress: &symbolAddress)
                }
                if let symbolPointer = symbolAddress {
                    var oldMethod: UnsafeMutableRawPointer?
                    FishHook.replaceSymbol(symbol, at: image, imageSlide: _dyld_get_image_vmaddr_slide(imgIndex), newMethod: symbolPointer, oldMethod: &oldMethod)
                }
            }
        }
    }
    
    @inline(__always)
    static public func denyFishHook(_ symbol: String, at image: UnsafePointer<mach_header>, imageSlide slide: Int) {
        var symbolAddress: UnsafeMutableRawPointer?
        
        if SymbolFound.lookSymbol(symbol, at: image, imageSlide: slide, symbolAddress: &symbolAddress), let symbolPointer = symbolAddress {
            var oldMethod: UnsafeMutableRawPointer?
            FishHook.replaceSymbol(symbol, at: image, imageSlide: slide, newMethod: symbolPointer, oldMethod: &oldMethod)
        }
    }
}

// MARK: - SymbolFound
internal class SymbolFound {
    static private let BindTypeThreadedRebase = 102

    @inline(__always)
    static func lookSymbol(_ symbol: String, at image: UnsafePointer<mach_header>, imageSlide slide: Int, symbolAddress: inout UnsafeMutableRawPointer?) -> Bool {
        // target cmd
        var linkeditCmd: UnsafeMutablePointer<segment_command_64>!
        var dyldInfoCmd: UnsafeMutablePointer<dyld_info_command>!
        var allLoadDylds = [String]()

        guard var curCmdPointer = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: image)+UInt(MemoryLayout<mach_header_64>.size)) else {
            return false
        }
        // all cmd
        for _ in 0..<image.pointee.ncmds {
            let curCmd = curCmdPointer.assumingMemoryBound(to: segment_command_64.self)
            
            switch UInt32(curCmd.pointee.cmd) {
            case UInt32(LC_SEGMENT_64):
                let offset = MemoryLayout.size(ofValue: curCmd.pointee.cmd) + MemoryLayout.size(ofValue: curCmd.pointee.cmdsize)
                let curCmdName = String(cString: curCmdPointer.advanced(by: offset).assumingMemoryBound(to: Int8.self))
                if (curCmdName == SEG_LINKEDIT) {
                    linkeditCmd = curCmd
                }
            case LC_DYLD_INFO_ONLY, UInt32(LC_DYLD_INFO):
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
            
            curCmdPointer += Int(curCmd.pointee.cmdsize)
        }

        if linkeditCmd == nil || dyldInfoCmd == nil { return false }
        let linkeditBase = UInt64(slide + Int(linkeditCmd.pointee.vmaddr) - Int(linkeditCmd.pointee.fileoff))
        
        // look by LazyBindInfo
        let lazyBindSize = Int(dyldInfoCmd.pointee.lazy_bind_size)
        if (lazyBindSize > 0) {
            if let lazyBindInfoCmd = UnsafeMutablePointer<UInt8>(bitPattern: UInt(linkeditBase + UInt64(dyldInfoCmd.pointee.lazy_bind_off))),
               lookLazyBindSymbol(symbol, symbolAddr: &symbolAddress, lazyBindInfoCmd: lazyBindInfoCmd, lazyBindInfoSize: lazyBindSize, allLoadDylds: allLoadDylds) {
                return true
            }
        }
        
        // look by NonLazyBindInfo
        let bindSize = Int(dyldInfoCmd.pointee.bind_size)
        if (bindSize > 0) {
            if let bindCmd = UnsafeMutablePointer<UInt8>(bitPattern: UInt(linkeditBase + UInt64(dyldInfoCmd.pointee.bind_off))),
               lookBindSymbol(symbol, symbolAddr: &symbolAddress, bindInfoCmd: bindCmd, bindInfoSize: bindSize, allLoadDylds: allLoadDylds) {
                return true
            }
        }
        
        return false
    }
    
    // LazySymbolBindInfo
    @inline(__always)
    private static func lookLazyBindSymbol(_ symbol: String, symbolAddr: inout UnsafeMutableRawPointer?, lazyBindInfoCmd: UnsafeMutablePointer<UInt8>, lazyBindInfoSize: Int, allLoadDylds: [String]) -> Bool {
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
        
        assert(ordinal <= allLoadDylds.count)

        if (foundSymbol && ordinal >= 0 && allLoadDylds.count > 0), ordinal <= allLoadDylds.count, type != BindTypeThreadedRebase {
            let imageName = allLoadDylds[ordinal-1]
            var tmpSymbolAddress: UnsafeMutableRawPointer?
            if lookExportedSymbol(symbol, exportImageName: imageName, symbolAddress: &tmpSymbolAddress), let symbolPointer = tmpSymbolAddress {
                symbolAddr = symbolPointer + addend
                return true
            }
        }
        
        return false
    }
    
    // NonLazySymbolBindInfo
    @inline(__always)
    private static func lookBindSymbol(_ symbol: String, symbolAddr: inout UnsafeMutableRawPointer?, bindInfoCmd: UnsafeMutablePointer<UInt8>, bindInfoSize: Int, allLoadDylds: [String]) -> Bool {
        var ptr = bindInfoCmd
        let bindingInfoEnd = bindInfoCmd.advanced(by: Int(bindInfoSize))
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

        assert(ordinal <= allLoadDylds.count)
        if (foundSymbol && ordinal >= 0 && allLoadDylds.count > 0), ordinal <= allLoadDylds.count, type != BindTypeThreadedRebase {
            let imageName = allLoadDylds[ordinal-1]
            var tmpSymbolAddress: UnsafeMutableRawPointer?
            if lookExportedSymbol(symbol, exportImageName: imageName, symbolAddress: &tmpSymbolAddress), let symbolPointer = tmpSymbolAddress {
                symbolAddr = symbolPointer + addend
                return true
            }
        }
        
        return false
    }
    
    // ExportSymbol
    @inline(__always)
    private static func lookExportedSymbol(_ symbol: String, exportImageName: String, symbolAddress: inout UnsafeMutableRawPointer?) -> Bool {
        var rpathImage: String?
        // @rpath
        if (exportImageName.contains("@rpath")) {
            rpathImage = exportImageName.components(separatedBy: "/").last
        }
        
        for index in 0..<_dyld_image_count() {
            // imageName
            let currentImageName = String(cString: _dyld_get_image_name(index))
            if let tmpRpathImage = rpathImage {
                if (!currentImageName.contains(tmpRpathImage)) {
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
                // not found, look at ReExport dylibs
                var allReExportDylibs = [String]()
                
                if let currentImage = _dyld_get_image_header(index),
                   var curCmdPointer = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: currentImage)+UInt(MemoryLayout<mach_header_64>.size)) {
                    
                    for _ in 0..<currentImage.pointee.ncmds {
                        let curCmd = curCmdPointer.assumingMemoryBound(to: segment_command_64.self)
                        if (curCmd.pointee.cmd == LC_REEXPORT_DYLIB) {
                            let reExportDyldCmd = curCmdPointer.assumingMemoryBound(to: dylib_command.self)
                            let nameOffset = Int(reExportDyldCmd.pointee.dylib.name.offset)
                            let namePointer = curCmdPointer.advanced(by: nameOffset).assumingMemoryBound(to: Int8.self)
                            let reExportDyldName = String(cString: namePointer)
                            allReExportDylibs.append(reExportDyldName)
                        }
                        curCmdPointer += Int(curCmd.pointee.cmdsize)
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
    
    // look export symbol by export trie
    @inline(__always)
    static private func _lookExportedSymbol(_ symbol: String, image: UnsafePointer<mach_header>, imageSlide slide: Int) -> UnsafeMutableRawPointer? {
        // target cmd
        var linkeditCmd: UnsafeMutablePointer<segment_command_64>!
        var dyldInfoCmd: UnsafeMutablePointer<dyld_info_command>!
        var exportCmd: UnsafeMutablePointer<linkedit_data_command>!

        guard var curCmdPointer = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: image)+UInt(MemoryLayout<mach_header_64>.size)) else {
            return nil
        }
        // cmd
        for _ in 0..<image.pointee.ncmds {
            let curCmd = curCmdPointer.assumingMemoryBound(to: segment_command_64.self)
            
            switch UInt32(curCmd.pointee.cmd) {
            case UInt32(LC_SEGMENT_64):
                let offset = MemoryLayout.size(ofValue: curCmd.pointee.cmd) + MemoryLayout.size(ofValue: curCmd.pointee.cmdsize)
                let curCmdName = String(cString: curCmdPointer.advanced(by: offset).assumingMemoryBound(to: Int8.self))
                if (curCmdName == SEG_LINKEDIT) {
                    linkeditCmd = curCmd
                }
            case LC_DYLD_INFO_ONLY, UInt32(LC_DYLD_INFO):
                dyldInfoCmd = curCmdPointer.assumingMemoryBound(to: dyld_info_command.self)
            case LC_DYLD_EXPORTS_TRIE:
                exportCmd = curCmdPointer.assumingMemoryBound(to: linkedit_data_command.self)
            default:
                break
            }
            
            curCmdPointer += Int(curCmd.pointee.cmdsize)
        }

        // export trie info
        let hasDyldInfo = dyldInfoCmd != nil && dyldInfoCmd.pointee.export_size != 0
        let hasExportTrie = exportCmd != nil && exportCmd.pointee.datasize != 0
        if linkeditCmd == nil || (!hasDyldInfo && !hasExportTrie) {
            return nil
        }
        
        let linkeditBase = Int(slide + Int(linkeditCmd.pointee.vmaddr) - Int(linkeditCmd.pointee.fileoff))
        let exportOff = hasExportTrie ? exportCmd.pointee.dataoff : dyldInfoCmd.pointee.export_off
        let exportSize = hasExportTrie ? exportCmd.pointee.datasize : dyldInfoCmd.pointee.export_size
        
        guard let exportedInfo = UnsafeMutableRawPointer(bitPattern: linkeditBase + Int(exportOff))?.assumingMemoryBound(to: UInt8.self) else { return nil }
        
        let start = exportedInfo
        let end = exportedInfo + Int(exportSize)
             
        // export symbol location
        if var symbolLocation = lookExportedSymbolByTrieWalk(targetSymbol: symbol, start: start, end: end, currentLocation: start, currentSymbol: "") {
            let flags = readUleb128(ptr: &symbolLocation, end: end)

            let returnSymbolAddress = { () -> UnsafeMutableRawPointer in
                let machO = image.withMemoryRebound(to: Int8.self, capacity: 1, { $0 })
                let symbolAddress = machO.advanced(by: Int(readUleb128(ptr: &symbolLocation, end: end)))
                return UnsafeMutableRawPointer(mutating: symbolAddress)
            }
            
            switch flags & UInt64(EXPORT_SYMBOL_FLAGS_KIND_MASK) {
            case UInt64(EXPORT_SYMBOL_FLAGS_KIND_REGULAR):
                // runResolver is false by bind or lazyBind
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
    
    // ExportSymbol
    @inline(__always)
    static private func lookExportedSymbolByTrieWalk(targetSymbol: String, start: UnsafeMutablePointer<UInt8>, end: UnsafeMutablePointer<UInt8>, currentLocation location: UnsafeMutablePointer<UInt8>, currentSymbol: String) -> UnsafeMutablePointer<UInt8>? {
        var ptr = location
        
        while ptr <= end {
            // terminalSize
            var terminalSize = UInt64(ptr.pointee)
            ptr += 1
            if terminalSize > 127 {
                ptr -= 1
                terminalSize = readUleb128(ptr: &ptr, end: end)
            }
            if terminalSize != 0 {
                return currentSymbol == targetSymbol ? ptr : nil
            }
            
            // children
            let children = ptr.advanced(by: Int(terminalSize))
            if children >= end {
                // end
                return nil
            }
            let childrenCount = children.pointee
            ptr = children + 1
            
            // nodes
            for _ in 0..<childrenCount {
                let nodeLabel = ptr.withMemoryRebound(to: CChar.self, capacity: 1, { $0 })
                
                // node offset
                while ptr.pointee != 0 {
                    ptr += 1
                }
                ptr += 1  // = "00"
                let nodeOffset = Int(readUleb128(ptr: &ptr, end: end))
                
                // node
                if let nodeSymbol = String(cString: nodeLabel, encoding: .utf8) {
                    let tmpCurrentSymbol = currentSymbol + nodeSymbol
                    if !targetSymbol.contains(tmpCurrentSymbol) {
                        continue
                    }
                    if nodeOffset != 0 && (start + nodeOffset <= end) {
                        let location = start.advanced(by: nodeOffset)
                        if let symbolLocation = lookExportedSymbolByTrieWalk(targetSymbol: targetSymbol, start: start, end: end, currentLocation: location, currentSymbol: tmpCurrentSymbol) {
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
