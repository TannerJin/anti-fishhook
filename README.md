# AntiFishhook

__AntiFishhook__ is an AntiHook library for [`fishhook`][fishhook] at runtime.

[fishhook]: https://github.com/facebook/fishhook
[Swift Name Mangling]: https://www.mikeash.com/pyblog/friday-qa-2014-08-15-swift-name-mangling.html

## Usage

```swift
  import antiFishhook

  resetSymbol("printf")
  
  // swift
  resetSymbol("$s10Foundation5NSLogyySS_s7CVarArg_pdtF")  // Foudation.NSLog
```

### Note

 Run or test in your phone instend of simulator   
 [`Swift Function name mangling`][Swift Name Mangling]

### Suggestion

Use by dragging source file to your project instend of pod
