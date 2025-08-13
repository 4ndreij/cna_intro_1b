#!/bin/bash

# Test Runner Script for Cloud-Native Microservices
# This script provides various testing options for the solution

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Cloud-Native Microservices Test Runner${NC}"
echo -e "${BLUE}=========================================${NC}"

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  all              Run all tests (default)"
    echo "  unit             Run only unit tests"
    echo "  integration      Run only integration tests"
    echo "  coverage         Run tests with code coverage"
    echo "  watch            Run tests in watch mode"
    echo "  product          Run ProductService tests only"
    echo "  order            Run OrderService tests only"
    echo "  shared           Run Shared library tests only"
    echo "  clean            Clean all test outputs"
    echo "  --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./scripts/run-tests.sh                # Run all tests"
    echo "  ./scripts/run-tests.sh coverage       # Run with coverage report"
    echo "  ./scripts/run-tests.sh watch product  # Watch ProductService tests"
}

# Function to run all tests
run_all_tests() {
    echo -e "${YELLOW}🚀 Running all tests...${NC}"
    dotnet test --verbosity normal --logger "console;verbosity=normal"
}

# Function to run unit tests only
run_unit_tests() {
    echo -e "${YELLOW}🔬 Running unit tests...${NC}"
    dotnet test --filter "TestCategory!=Integration" --verbosity normal
}

# Function to run integration tests only
run_integration_tests() {
    echo -e "${YELLOW}🔗 Running integration tests...${NC}"
    dotnet test --filter "TestCategory=Integration" --verbosity normal
}

# Function to run tests with coverage
run_coverage_tests() {
    echo -e "${YELLOW}📊 Running tests with code coverage...${NC}"
    dotnet test --collect:"XPlat Code Coverage" --results-directory:"./TestResults" --verbosity normal
    
    if command -v reportgenerator &> /dev/null; then
        echo -e "${YELLOW}📋 Generating coverage report...${NC}"
        reportgenerator \
            -reports:"./TestResults/**/coverage.cobertura.xml" \
            -targetdir:"./TestResults/CoverageReport" \
            -reporttypes:Html
        
        echo -e "${GREEN}✅ Coverage report generated in ./TestResults/CoverageReport/index.html${NC}"
    else
        echo -e "${YELLOW}⚠️  Install reportgenerator for HTML coverage reports:${NC}"
        echo -e "${YELLOW}   dotnet tool install -g dotnet-reportgenerator-globaltool${NC}"
    fi
}

# Function to run tests in watch mode
run_watch_tests() {
    local project=${1:-"all"}
    
    case $project in
        "product")
            echo -e "${YELLOW}👀 Watching ProductService tests...${NC}"
            dotnet watch test src/Tests/ProductService.Tests/
            ;;
        "order")
            echo -e "${YELLOW}👀 Watching OrderService tests...${NC}"
            dotnet watch test src/Tests/OrderService.Tests/
            ;;
        "shared")
            echo -e "${YELLOW}👀 Watching Shared tests...${NC}"
            dotnet watch test src/Tests/Shared.Tests/
            ;;
        "all"|*)
            echo -e "${YELLOW}👀 Watching all tests...${NC}"
            dotnet watch test
            ;;
    esac
}

# Function to run specific project tests
run_project_tests() {
    local project=$1
    
    case $project in
        "product")
            echo -e "${YELLOW}🛍️  Running ProductService tests...${NC}"
            dotnet test src/Tests/ProductService.Tests/ --verbosity normal
            ;;
        "order")
            echo -e "${YELLOW}📦 Running OrderService tests...${NC}"
            dotnet test src/Tests/OrderService.Tests/ --verbosity normal
            ;;
        "shared")
            echo -e "${YELLOW}📚 Running Shared library tests...${NC}"
            dotnet test src/Tests/Shared.Tests/ --verbosity normal
            ;;
        *)
            echo -e "${RED}❌ Unknown project: $project${NC}"
            echo -e "${YELLOW}Available projects: product, order, shared${NC}"
            exit 1
            ;;
    esac
}

# Function to clean test outputs
clean_tests() {
    echo -e "${YELLOW}🧹 Cleaning test outputs...${NC}"
    
    # Clean bin and obj directories
    find . -name "bin" -type d -path "*/Tests/*" -exec rm -rf {} + 2>/dev/null || true
    find . -name "obj" -type d -path "*/Tests/*" -exec rm -rf {} + 2>/dev/null || true
    
    # Clean test results
    rm -rf ./TestResults 2>/dev/null || true
    
    echo -e "${GREEN}✅ Test outputs cleaned${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    if ! command -v dotnet &> /dev/null; then
        echo -e "${RED}❌ .NET SDK is not installed or not in PATH${NC}"
        exit 1
    fi
    
    # Check .NET version
    local dotnet_version=$(dotnet --version | cut -d'.' -f1)
    if [[ $dotnet_version -lt 8 ]]; then
        echo -e "${YELLOW}⚠️  .NET 8 or later is recommended (current: $(dotnet --version))${NC}"
    fi
}

# Function to show test summary
show_test_summary() {
    echo ""
    echo -e "${GREEN}🎉 Test execution completed!${NC}"
    echo -e "${GREEN}============================${NC}"
    echo ""
    echo -e "${BLUE}📊 Quick Stats:${NC}"
    echo -e "  Test Projects: 3 (ProductService.Tests, OrderService.Tests, Shared.Tests)"
    echo -e "  Framework: .NET 8"
    echo -e "  Test Runner: xUnit"
    echo -e "  Mocking: Moq"
    echo -e "  Assertions: FluentAssertions"
    echo ""
    echo -e "${BLUE}🔗 Useful Commands:${NC}"
    echo -e "  View detailed results: dotnet test --logger trx"
    echo -e "  Run specific test: dotnet test --filter \"TestName\""
    echo -e "  Debug tests: dotnet test --logger \"console;verbosity=diagnostic\""
}

# Main script logic
main() {
    check_prerequisites
    
    # Default to running all tests if no argument provided
    local action=${1:-"all"}
    
    case $action in
        "--help"|"-h"|"help")
            show_usage
            exit 0
            ;;
        "all")
            run_all_tests
            show_test_summary
            ;;
        "unit")
            run_unit_tests
            show_test_summary
            ;;
        "integration")
            run_integration_tests
            show_test_summary
            ;;
        "coverage")
            run_coverage_tests
            show_test_summary
            ;;
        "watch")
            run_watch_tests ${2:-"all"}
            ;;
        "product"|"order"|"shared")
            run_project_tests $action
            show_test_summary
            ;;
        "clean")
            clean_tests
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $action${NC}"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
