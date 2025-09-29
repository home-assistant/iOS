# Fastlane Modular Structure

This project has been refactored to use a modular Fastfile structure for better maintainability and organization. The main `Fastfile` now imports smaller, purpose-specific files from the `lanes/` directory.

## File Structure

```
fastlane/
├── Fastfile                    # Main orchestration file
└── lanes/
    ├── setup.rb               # Environment setup and CI configuration
    ├── quality.rb             # Code linting and formatting
    ├── provisioning.rb        # Provisioning profile management
    ├── assets.rb              # Icon generation and asset management
    ├── localization.rb        # String localization (Lokalise integration)
    ├── version.rb             # Version and build number management
    ├── testing.rb             # Test execution and debugging utilities
    ├── build_utils.rb         # Build and deployment utility functions
    ├── ios.rb                 # iOS-specific build lanes
    └── macos.rb               # macOS-specific build lanes
```

## Module Descriptions

### setup.rb
- Environment variable configuration
- Apple ID and team setup
- CI/CD keychain and certificate management
- `before_all` hook and setup lane

### quality.rb
- Swift code formatting and linting
- RuboCop Ruby linting
- Auto-correction capabilities

### provisioning.rb
- Provisioning profile download and management
- Profile installation and repair
- Profile specifier resolution for builds

### assets.rb
- App icon generation for different build configurations
- SwiftGen configuration updates
- Asset processing utilities

### localization.rb
- Lokalise integration for downloading translations
- String file upload and management
- Unused string detection
- App Store Connect metadata localization

### version.rb
- Version number management
- Build number handling
- Xcode configuration file updates

### testing.rb
- Unit test execution
- Test case updates from external repositories
- dSYM management and download

### build_utils.rb
- Binary upload utilities
- Common build helper functions
- Error handling and retry logic

### ios.rb
- iOS app building and archiving
- iOS-specific deployment logic
- App Store Connect upload for iOS

### macos.rb
- macOS app building and packaging
- Code signing and notarization
- Developer ID and App Store builds
- macOS-specific deployment logic

## Benefits of This Structure

1. **Maintainability**: Each file focuses on a specific aspect of the build process
2. **Readability**: Easier to find and understand specific functionality
3. **Collaboration**: Team members can work on different aspects without conflicts
4. **Reusability**: Individual modules can be shared between projects
5. **Testing**: Each module can be tested independently
6. **Documentation**: Each file can have focused documentation

## Usage

All existing lane commands continue to work exactly as before:

```bash
fastlane lint
fastlane test
fastlane ios build
fastlane mac build
fastlane update_strings
# ... etc
```

The modular structure is transparent to users - all functionality remains the same while providing better organization for developers.

## Adding New Lanes

When adding new lanes:

1. Determine which module the lane belongs to based on its purpose
2. Add the lane to the appropriate file in `lanes/`
3. If creating a new category, create a new file and import it in the main `Fastfile`
4. Update this README to document the new functionality

## Migration Notes

- All existing lanes and functionality have been preserved
- No changes needed to CI/CD configurations
- Import statements in the main `Fastfile` ensure all modules are loaded
- Private lanes are properly scoped within their respective modules