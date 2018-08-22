# Package

version       = "0.1.0"
author        = "Ryanc_signiq"
description   = "An implementation of the observer pattern"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 0.18.0"

task test, "Run the tests":
    exec("mkdir -p tests/bin")
    exec("nim c -r --threads:on --gc:boehm --out:tests/bin/nimobserver_tests tests/nimobserver_tests")
