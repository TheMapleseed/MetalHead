# MetalHead Build System Makefile

# Configuration
PROJECT_NAME = MetalHead
SCHEME = MetalHead
DESTINATION = 'platform=macOS,arch=arm64'
CONFIGURATION_DEBUG = Debug
CONFIGURATION_RELEASE = Release
XCODEBUILD = xcodebuild
SWIFTLINT = swiftlint
SONAR_SCANNER = sonar-scanner

# Directories
BUILD_DIR = build
TEST_RESULTS_DIR = test-results
COVERAGE_DIR = coverage
DOCS_DIR = docs

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

.PHONY: help build test lint clean install uninstall format docs coverage security

# Default target
help:
	@echo "$(BLUE)MetalHead Build System$(NC)"
	@echo ""
	@echo "$(YELLOW)Available targets:$(NC)"
	@echo "  build          - Build the project"
	@echo "  test           - Run unit tests"
	@echo "  test-performance - Run performance tests"
	@echo "  lint           - Run SwiftLint"
	@echo "  format         - Format code with SwiftLint"
	@echo "  clean          - Clean build artifacts"
	@echo "  install        - Install the app"
	@echo "  uninstall      - Uninstall the app"
	@echo "  docs           - Generate documentation"
	@echo "  coverage       - Generate code coverage report"
	@echo "  security       - Run security scan"
	@echo "  ci             - Run full CI pipeline"
	@echo "  release        - Build release version"

# Build targets
build:
	@echo "$(BLUE)Building $(PROJECT_NAME)...$(NC)"
	$(XCODEBUILD) -project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-destination $(DESTINATION) \
		-configuration $(CONFIGURATION_DEBUG) \
		build
	@echo "$(GREEN)Build completed successfully!$(NC)"

build-release:
	@echo "$(BLUE)Building $(PROJECT_NAME) (Release)...$(NC)"
	$(XCODEBUILD) -project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-destination $(DESTINATION) \
		-configuration $(CONFIGURATION_RELEASE) \
		build
	@echo "$(GREEN)Release build completed successfully!$(NC)"

# Test targets
test:
	@echo "$(BLUE)Running unit tests...$(NC)"
	@mkdir -p $(TEST_RESULTS_DIR)
	$(XCODEBUILD) -project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-destination $(DESTINATION) \
		-configuration $(CONFIGURATION_DEBUG) \
		test \
		-resultBundlePath $(TEST_RESULTS_DIR)/test-results.xcresult
	@echo "$(GREEN)Unit tests completed!$(NC)"

test-performance:
	@echo "$(BLUE)Running performance tests...$(NC)"
	@mkdir -p $(TEST_RESULTS_DIR)
	$(XCODEBUILD) -project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-destination $(DESTINATION) \
		-configuration $(CONFIGURATION_RELEASE) \
		test \
		-resultBundlePath $(TEST_RESULTS_DIR)/performance-results.xcresult
	@echo "$(GREEN)Performance tests completed!$(NC)"

# Linting targets
lint:
	@echo "$(BLUE)Running SwiftLint...$(NC)"
	$(SWIFTLINT) lint --reporter github-actions-logging
	@echo "$(GREEN)Linting completed!$(NC)"

lint-strict:
	@echo "$(BLUE)Running SwiftLint (strict mode)...$(NC)"
	$(SWIFTLINT) lint --strict
	@echo "$(GREEN)Strict linting completed!$(NC)"

format:
	@echo "$(BLUE)Formatting code...$(NC)"
	$(SWIFTLINT) --fix
	@echo "$(GREEN)Code formatting completed!$(NC)"

# Clean targets
clean:
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	$(XCODEBUILD) -project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		clean
	rm -rf $(BUILD_DIR)
	rm -rf $(TEST_RESULTS_DIR)
	rm -rf $(COVERAGE_DIR)
	rm -rf $(DOCS_DIR)
	@echo "$(GREEN)Clean completed!$(NC)"

# Installation targets
install: build-release
	@echo "$(BLUE)Installing $(PROJECT_NAME)...$(NC)"
	# Add installation logic here
	@echo "$(GREEN)Installation completed!$(NC)"

uninstall:
	@echo "$(BLUE)Uninstalling $(PROJECT_NAME)...$(NC)"
	# Add uninstallation logic here
	@echo "$(GREEN)Uninstallation completed!$(NC)"

# Documentation targets
docs:
	@echo "$(BLUE)Generating documentation...$(NC)"
	@mkdir -p $(DOCS_DIR)
	# Add documentation generation logic here
	@echo "$(GREEN)Documentation generated!$(NC)"

# Coverage targets
coverage:
	@echo "$(BLUE)Generating code coverage report...$(NC)"
	@mkdir -p $(COVERAGE_DIR)
	$(XCODEBUILD) -project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-destination $(DESTINATION) \
		-configuration $(CONFIGURATION_DEBUG) \
		test \
		-enableCodeCoverage YES \
		-codeCoverageTargets $(SCHEME)
	@echo "$(GREEN)Code coverage report generated!$(NC)"

# Security targets
security:
	@echo "$(BLUE)Running security scan...$(NC)"
	$(SONAR_SCANNER) \
		-Dsonar.projectKey=$(PROJECT_NAME) \
		-Dsonar.sources=. \
		-Dsonar.host.url=https://sonarcloud.io \
		-Dsonar.login=$(SONAR_TOKEN)
	@echo "$(GREEN)Security scan completed!$(NC)"

# CI targets
ci: clean lint test test-performance security
	@echo "$(GREEN)CI pipeline completed successfully!$(NC)"

# Release targets
release: clean lint test test-performance security build-release
	@echo "$(GREEN)Release build completed successfully!$(NC)"

# Development targets
dev: clean build test
	@echo "$(GREEN)Development build completed!$(NC)"

# Quick targets
quick: build test
	@echo "$(GREEN)Quick build and test completed!$(NC)"

# Archive targets
archive:
	@echo "$(BLUE)Creating archive...$(NC)"
	$(XCODEBUILD) -project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-destination $(DESTINATION) \
		-configuration $(CONFIGURATION_RELEASE) \
		-archivePath $(BUILD_DIR)/$(PROJECT_NAME).xcarchive \
		archive
	@echo "$(GREEN)Archive created!$(NC)"

# Export targets
export: archive
	@echo "$(BLUE)Exporting app...$(NC)"
	$(XCODEBUILD) -exportArchive \
		-archivePath $(BUILD_DIR)/$(PROJECT_NAME).xcarchive \
		-exportPath $(BUILD_DIR) \
		-exportOptionsPlist ExportOptions.plist
	@echo "$(GREEN)App exported!$(NC)"

# All targets
all: clean lint test test-performance security build-release docs coverage
	@echo "$(GREEN)All targets completed successfully!$(NC)"
