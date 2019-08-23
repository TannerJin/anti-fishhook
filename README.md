# AntiFishhook

__AntiFishhook__ is an AntiHook library for [`fishhook`][fishhook] at runtime.

[fishhook]: https://github.com/facebook/fishhook
[Swift Name Mangling]: https://www.mikeash.com/pyblog/friday-qa-2014-08-15-swift-name-mangling.html

## Usage

### fishhook

```swift
typealias NewSwiftNSLog = @convention(thin) (_ format: String, _ args: CVarArg...) -> Void

func newNSLog(_ format: String, _ args: CVarArg...) {
    print("Hello fishHook")
}

let _nslog: NewSwiftNSLog  = newNSLog
let _nslog_pointer = unsafeBitCast(_nslog, to: UnsafeMutableRawPointer.self)
var old_nslog_pointer: UnsafeMutableRawPointer?

replaceSymbol("$s10Foundation5NSLogyySS_s7CVarArg_pdtF", newMethod: _nslog_pointer, oldMethod: &old_nslog_pointer)

NSLog("Hello World")
// print Hello fishHook

```

### antiFishhook

```swift
resetSymbol("$s10Foundation5NSLogyySS_s7CVarArg_pdtF")  // Foudation.NSLog
  
NSLog("Hello AntiFishHook")
// print Hello AntiFishHook

```

### Note

 Run or test in your phone instend of simulator   
 [`Swift Function name mangling`][Swift Name Mangling]

### Suggestion

Use by dragging source file to your project instend of pod
