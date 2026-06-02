#!/bin/bash

# Compile the app
swiftc RotatedBrowserApp.swift ContentView.swift WebView.swift PDFViewWrapper.swift Analytics.swift -o net.j4dy.RotatedBrowserApp

# Check if compilation was successful
if [ $? -eq 0 ]; then
    echo "Compilation successful. Running app..."
    ./net.j4dy.RotatedBrowserApp
else
    echo "Compilation failed."
fi
