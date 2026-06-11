import subprocess
import time
import os

sources = ["RotatedBrowserApp.swift", "ContentView.swift", "WebView.swift", "PDFViewWrapper.swift", "Analytics.swift"]

configs = {
    "Debug (Unoptimized)": ["swiftc"] + sources + ["-o", "net.j4dy.RotatedBrowserApp.debug"],
    "Release (Speed -O)": ["swiftc", "-O"] + sources + ["-o", "net.j4dy.RotatedBrowserApp.release"],
    "Release (Size -Osize)": ["swiftc", "-Osize"] + sources + ["-o", "net.j4dy.RotatedBrowserApp.size"]
}

results = []

print("Starting Swift compilation benchmarks...")
for name, cmd in configs.items():
    print(f"Benchmarking {name}...")
    start_time = time.time()
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    duration = time.time() - start_time
    
    if result.returncode == 0:
        out_file = cmd[-1]
        size_bytes = os.path.getsize(out_file)
        size_mb = size_bytes / (1024 * 1024)
        results.append({
            "config": name,
            "status": "Success",
            "time": f"{duration:.2f}s",
            "size": f"{size_mb:.2f} MB ({size_bytes:,} bytes)"
        })
        # Clean up binary
        if os.path.exists(out_file):
            os.remove(out_file)
    else:
        results.append({
            "config": name,
            "status": "Failed",
            "time": f"{duration:.2f}s",
            "size": "N/A"
        })

print("\nBenchmark Results:")
print(f"{'Configuration':<25} | {'Status':<8} | {'Compile Time':<12} | {'Binary Size'}")
print("-" * 70)
for r in results:
    print(f"{r['config']:<25} | {r['status']:<8} | {r['time']:<12} | {r['size']}")
