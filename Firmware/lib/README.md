# Library Directory

This directory is for project-specific private libraries.

Libraries placed here are only available to this PlatformIO project and will not be shared with other projects.

## Usage

Each library should have its own subdirectory:
```
lib/
├── MyLibrary/
│   ├── MyLibrary.h
│   └── MyLibrary.cpp
└── AnotherLibrary/
    ├── AnotherLibrary.h
    └── AnotherLibrary.cpp
```

## External Libraries

For external libraries from the PlatformIO Library Registry, use the `lib_deps` option in `platformio.ini` instead of placing them here.

Current external dependencies are listed in `platformio.ini`:
- MPU6050_tockn - IMU sensor library
