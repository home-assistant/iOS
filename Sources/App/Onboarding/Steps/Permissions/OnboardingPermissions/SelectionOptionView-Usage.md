# SelectionOptionView Usage Guide

The `SelectionOptionView` is a reusable SwiftUI component that provides customizable radio button or checkbox selection functionality.

## Features

- **Single Selection Mode**: Radio button behavior (only one option can be selected)
- **Multiple Selection Mode**: Checkbox behavior (multiple options can be selected)
- **Customizable Options**: Support for titles, subtitles, and recommended badges
- **Accessible**: Built with SwiftUI accessibility in mind
- **Consistent Styling**: Matches Apple's design guidelines

## Basic Usage

### Single Selection (Radio Buttons)

```swift
struct ExampleView: View {
    @State private var selectedOption: String? = "option1"
    
    private let options = [
        SelectionOption(
            value: "option1",
            title: "First Option",
            subtitle: "Description for first option",
            isRecommended: true
        ),
        SelectionOption(
            value: "option2",
            title: "Second Option",
            subtitle: "Description for second option",
            isRecommended: false
        )
    ]
    
    var body: some View {
        VStack {
            SelectionOptionView(options: options, selection: $selectedOption)
        }
        .padding()
    }
}
```

### Multiple Selection (Checkboxes)

```swift
struct ExampleView: View {
    @State private var selectedOptions: Set<String> = ["option1"]
    
    private let options = [
        SelectionOption(
            value: "option1",
            title: "First Option",
            subtitle: "Description for first option"
        ),
        SelectionOption(
            value: "option2", 
            title: "Second Option",
            subtitle: "Description for second option"
        ),
        SelectionOption(
            value: "option3",
            title: "Third Option"
        )
    ]
    
    var body: some View {
        VStack {
            SelectionOptionView(options: options, multipleSelection: $selectedOptions)
            
            Text("Selected: \(Array(selectedOptions).joined(separator: ", "))")
        }
        .padding()
    }
}
```

## SelectionOption Properties

- **value**: The unique identifier for this option (String)
- **title**: The main text displayed for the option
- **subtitle**: Optional secondary text displayed below the title
- **isRecommended**: Whether this option should be styled as recommended (adds blue background tint when selected)

## Styling Features

- **Recommended Options**: When `isRecommended` is true and the option is selected, it gets a blue background tint
- **Selection Indicators**: 
  - Single selection: Filled circle (radio button style)
  - Multiple selection: Checkmark (checkbox style)
- **Interactive States**: Proper highlighting and selection feedback
- **Spacing**: Consistent spacing using the `DesignSystem.Spaces` system

## Integration Example

Here's how it's used in the `LocalAccessPermissionView`:

```swift
struct LocalAccessPermissionView: View {
    @State private var selection: String? = "secure"
    
    private let locationOptions = [
        SelectionOption(
            value: "secure",
            title: "Most secure: Allow this app to know when you're home",
            subtitle: nil,
            isRecommended: true
        ),
        SelectionOption(
            value: "less_secure",
            title: "Less secure: Do not allow this app to know when you're home",
            subtitle: nil,
            isRecommended: false
        )
    ]
    
    var body: some View {
        // ... other content
        SelectionOptionView(options: locationOptions, selection: $selection)
        // ... other content
    }
}
```

## Best Practices

1. **Use Single Selection** for mutually exclusive choices (like permission levels)
2. **Use Multiple Selection** for independent options (like feature toggles)
3. **Keep titles concise** but descriptive
4. **Use subtitles** for additional context when needed
5. **Mark recommended options** to guide user choice
6. **Provide sensible defaults** by pre-selecting appropriate options