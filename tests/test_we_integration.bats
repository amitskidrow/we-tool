#!/usr/bin/env bats
# Integration tests for 'we' development tool
# Tests the critical paths mentioned in NEW_CHANGES.MD

# Setup and teardown
setup() {
    export TEST_DIR="$(mktemp -d)"
    export ORIGINAL_DIR="$(pwd)"
    cd "$TEST_DIR"
    
    # Create a minimal test project
    mkdir -p test-project
    cd test-project
    
    cat > pyproject.toml <<EOF
[project]
name = "test-service"
version = "0.1.0"
dependencies = []

[project.scripts]
test-service = "main:main"
EOF

    cat > main.py <<EOF
#!/usr/bin/env python3
import time
import sys

def main():
    print("Test service starting...")
    try:
        for i in range(3):
            print(f"Test service running... {i+1}")
            time.sleep(0.1)
        print("Test service completed")
    except KeyboardInterrupt:
        print("Test service interrupted")
        sys.exit(0)

if __name__ == "__main__":
    main()
EOF
}

teardown() {
    cd "$ORIGINAL_DIR"
    rm -rf "$TEST_DIR"
}

# Test: we command generates Makefile successfully
@test "we generates Makefile with Python CLI integration" {
    run "$ORIGINAL_DIR/we" . --service test-service --entry main.py --yes
    [ "$status" -eq 0 ]
    [ -f "Makefile" ]
    
    # Check that Makefile contains Python CLI calls
    grep -q "python tools/uuctl.py" Makefile
}

# Test: Generated Makefile validates correctly
@test "generated Makefile passes validation" {
    "$ORIGINAL_DIR/we" . --service test-service --entry main.py --yes
    
    run "$ORIGINAL_DIR/tools/we-validate-makefile.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Makefile looks ok"* ]]
}

# Test: make doctor runs service in foreground (critical path)
@test "make doctor runs service in foreground mode" {
    "$ORIGINAL_DIR/we" . --service test-service --entry main.py --yes
    
    # Check if Makefile uses Python CLI (Phase 2) or shell logic (Phase 1)
    if grep -q "python tools/uuctl.py" Makefile; then
        # Phase 2: Python CLI - need to run from parent directory
        cd "$ORIGINAL_DIR"
        run timeout 5s make -C "$TEST_DIR/test-project" doctor
    else
        # Phase 1: Shell logic - run directly
        run timeout 5s make doctor
    fi
    
    # Doctor mode should run and complete (exit code 0 or 124 for timeout)
    [[ "$status" -eq 0 || "$status" -eq 124 ]]
    [[ "$output" == *"Test service starting"* || "$output" == *"Running test-service in doctor mode"* ]]
}

# Test: make ps reports unit status correctly
@test "make ps reports unit status (unit not found when not running)" {
    "$ORIGINAL_DIR/we" . --service test-service --entry main.py --yes
    
    # Check if Makefile uses Python CLI (Phase 2) or shell logic (Phase 1)
    if grep -q "python tools/uuctl.py" Makefile; then
        # Phase 2: Python CLI - need to run from parent directory
        cd "$ORIGINAL_DIR"
        run make -C "$TEST_DIR/test-project" ps
    else
        # Phase 1: Shell logic - run directly
        run make ps
    fi
    
    # Should succeed and show unit status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Unit not found"* || "$output" == *"we-test-service"* || "$output" == *"inactive"* ]]
}

# Test: Python CLI works standalone
@test "Python CLI shows help and subcommands" {
    cd "$ORIGINAL_DIR"
    
    run uv run -- python tools/uuctl.py --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Development service controller"* ]]
    [[ "$output" == *"up"* ]]
    [[ "$output" == *"down"* ]]
    [[ "$output" == *"doctor"* ]]
}

# Test: Environment variable passing works
@test "environment variables pass from Make to Python CLI" {
    "$ORIGINAL_DIR/we" . --service test-service --entry main.py --yes
    
    # Check that the generated Makefile passes required environment variables
    grep -q 'SERVICE="$(SERVICE)"' Makefile
    grep -q 'PROJECT="$(PROJECT)"' Makefile
    grep -q 'ENTRY="$(ENTRY)"' Makefile
}

# Test: Generated README contains expected content
@test "we generates README with development instructions" {
    run "$ORIGINAL_DIR/we" . --service test-service --entry main.py --yes
    [ "$status" -eq 0 ]
    [ -f "README.md" ]
    
    # Check README contains key instructions
    grep -q "make up" README.md
    grep -q "make follow" README.md
    grep -q "make down" README.md
    grep -q "RELOAD=1" README.md
}

# Test: Makefile contains all expected targets
@test "generated Makefile contains all required targets" {
    "$ORIGINAL_DIR/we" . --service test-service --entry main.py --yes
    
    # Check for all 9 main targets
    for target in up down ps logs follow restart doctor unit journal; do
        grep -q "^${target}:" Makefile || grep -q "^${target}\..*:" Makefile
    done
}

# Test: .gitignore is properly managed
@test "we ensures .gitignore contains .we/ directory" {
    "$ORIGINAL_DIR/we" . --service test-service --entry main.py --yes
    
    [ -f ".gitignore" ]
    grep -q "^\.we/" .gitignore
}