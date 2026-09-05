#!/bin/sh
# Offline build: no SwiftPM manifest, no dependencies, no network.
# Compiled in Swift 5 language mode (swiftc's default) because the book's
# `linear blending` global is a mutable global, which Swift 6 mode rejects.
set -e
cd "$(dirname "$0")"
swiftc -O -o run Sources/Renderer.swift Sources/Tests.swift Sources/main.swift
echo "built ./run   -- './run' runs the scenarios, './run render' writes out/"
