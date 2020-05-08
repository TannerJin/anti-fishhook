# AntiFishhook

__AntiFishhook__ is an AntiHook library for [`fishhook`][fishhook] at runtime (make fishhook doesn't work) .  
include `fishhook` and `anti-fishhook`

[fishhook]: https://github.com/facebook/fishhook
[Swift Name Mangling]: https://www.mikeash.com/pyblog/friday-qa-2014-08-15-swift-name-mangling.html


### Note

 Run or test in your phone(arm64) instend of simulator   
 [`Swift Function name mangling`][Swift Name Mangling]

## Usage

### antiFishhook(Swift)

```swift
import antiFishhook

resetSymbol("$s10Foundation5NSLogyySS_s7CVarArg_pdtF")  // Swift's Foudation.NSLog  
NSLog("Hello AntiFishHook")

resetSymbol("printf")                                  // printf
printf("Hello AntiFishHook")
```

### antiFishhook(C/Objc)

```Objective-C
#include "antiFishhook-Swift.h"

+ (void)antiFishhook {
    resetSymbol(@"$s10Foundation5NSLogyySS_s7CVarArg_pdtF");  // Swift's Foudation.NSLog
    resetSymbol(@"printf");                                 // printf
}
```

### fishhook(just for Swift)

```swift
typealias MyNSLog = @convention(thin) (_ format: String, _ args: CVarArg...) -> Void

func my_NSLog(_ format: String, _ args: CVarArg...) {
    print("Hello fishHook")
}

let my_nslog: MyNSLog  = my_NSLog
let my_nslog_pointer = unsafeBitCast(my_nslog, to: UnsafeMutableRawPointer.self)
var orig_nslog_pointer: UnsafeMutableRawPointer?

replaceSymbol("$s10Foundation5NSLogyySS_s7CVarArg_pdtF", newMethod: my_nslog_pointer, oldMethod: &orig_nslog_pointer)

NSLog("Hello World")
// print Hello fishHook

```

### Suggestion

Use by adding source file to your project instend of pod
