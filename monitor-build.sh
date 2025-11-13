#!/bin/bash
# Monitor LLVM build progress

while true; do
    if pgrep -x ninja > /dev/null; then
        echo "$(date '+%H:%M:%S') - LLVM build running..."
        tail -1 /tmp/llvm-ninja.log | grep -oE '\[[0-9]+/[0-9]+\]' || echo "  (checking...)"
        sleep 30
    else
        echo "$(date '+%H:%M:%S') - LLVM build completed or stopped"
        
        if [ -f /home/syco/linux-wasm/workspace/install/llvm/bin/clang ]; then
            echo "✅ SUCCESS: clang installed"
            /home/syco/linux-wasm/workspace/install/llvm/bin/clang --version | head -1
        else
            echo "❌ FAILED: clang not found"
            tail -50 /tmp/llvm-ninja.log
        fi
        break
    fi
done
