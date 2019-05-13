# AntiFishhook

__AntiFishhook__ is an AntiHook library for [`fishhook`][fishhook] at runtime.

[fishhook]: https://github.com/facebook/fishhook

## Usage

```swift
  import antiFishhook

  resetSymbol("NSLog")
  NSLog("Hello World")
```

### Note

 Run or test in your phone instend of simulator   
 Not support arm64e architecture(Text hasn't stub_helper section and auth_stubs section as a replacement) 

### Suggestion

Use by dragging source file to your project instend of pod
