# Include Directory

This directory is for project header files (`.h` or `.hpp` files).

Header files placed here will be available to all source files in the `src` directory.

## Usage

Place your custom header files here:
```
include/
├── myHeader.h
└── anotherHeader.h
```

These files can then be included in your source code:
```cpp
#include <myHeader.h>
```
