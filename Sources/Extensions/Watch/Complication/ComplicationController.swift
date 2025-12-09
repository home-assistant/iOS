import ClockKit
import Communicator
import Shared

/// Controller responsible for providing complication data to ClockKit
///
/// This class serves as the data source for all complications displayed on watch faces.
/// It fetches complication data from GRDB, converts it to ClockKit templates, and handles
/// privacy settings and complication descriptors.
///
/// ## Architecture
/// - **Data Source**: GRDB database containing `AppWatchComplication` records
/// - **ClockKit Integration**: Implements `CLKComplicationDataSource` protocol
/// - **Fallbacks**: Provides placeholder templates when no data is available
///
/// ## Key Responsibilities
/// 1. Fetch complications from GRDB by identifier or family
/// 2. Generate ClockKit templates for rendering on watch faces
/// 3. Manage privacy behavior (show/hide on lock screen)
/// 4. Provide complication descriptors for the watch face editor
///
/// ## Data Flow
/// ```
/// ClockKit Request
///     ↓
/// complicationModel(for:) → Fetch from GRDB
///     ↓
/// AppWatchComplication.clkComplicationTemplate()
///     ↓
/// CLKComplicationTemplate → Display on watch face
/// ```
///
/// - Note: This controller is called frequently by ClockKit. Ensure database queries are optimized.
/// - Important: Always provide fallback templates to prevent blank complications.
///
/// ## Related Types
/// - `AppWatchComplication`: GRDB data model for complications
/// - `WatchComplication`: Realm model with template generation logic (used internally)
/// - `ComplicationGroupMember`: Family groupings for complications
/// - `AssistDefaultComplication`: Special complication for launching Assist
class ComplicationController: NSObject, CLKComplicationDataSource {
    // Helpful resources
    // https://github.com/LoopKit/Loop/issues/816
    // https://crunchybagel.com/detecting-which-complication-was-tapped/

    // MARK: - Private Helper Methods

    /// Fetches the complication model from GRDB database
    ///
    /// This method handles two identifier strategies:
    /// 1. **Modern approach (watchOS 7+)**: Uses `complication.identifier` to fetch by unique ID
    /// 2. **Legacy approach (watchOS 6)**: Uses complication family as the identifier
    ///
    /// The legacy approach is necessary because:
    /// - Pre-watchOS 7 complications don't have unique identifiers
    /// - We store them using the family rawValue as the primary key
    /// - This maintains backward compatibility with older watch faces
    ///
    /// - Parameter complication: The `CLKComplication` to fetch data for
    /// - Returns: `AppWatchComplication` if found in database, `nil` otherwise
    ///
    /// ## Example Usage
    /// ```swift
    /// if let model = complicationModel(for: complication) {
    ///     let template = model.clkComplicationTemplate(family: complication.family)
    /// }
    /// ```
    ///
    /// - Note: Database errors are logged but don't crash - returns `nil` on failure
    /// - Important: This is called frequently by ClockKit, so performance matters
    private func complicationModel(for complication: CLKComplication) -> AppWatchComplication? {
        // Helper function to get a complication using the correct ID depending on watchOS version

        let model: AppWatchComplication?

        do {
            if complication.identifier != CLKDefaultComplicationIdentifier {
                // existing complications that were configured pre-7 have no identifier set
                // so we can only access the value if it's a valid one. otherwise, fall back to old matching behavior.

                // Fetch from GRDB
                model = try Current.database().read { db in
                    try AppWatchComplication.fetch(identifier: complication.identifier, from: db)
                }
            } else {
                // we migrate pre-existing complications, and when still using watchOS 6 create new ones,
                // with the family as the identifier, so we can rely on this code path for older OS and older
                // complications
                let matchedFamily = ComplicationGroupMember(family: complication.family)

                // Fetch from GRDB using family rawValue
                model = try Current.database().read { db in
                    try AppWatchComplication.fetch(identifier: matchedFamily.rawValue, from: db)
                }
            }
        } catch {
            Current.Log.error("Failed to fetch complication from GRDB: \(error.localizedDescription)")
            model = nil
        }

        return model
    }

    /// Generates a ClockKit template for displaying a complication
    ///
    /// This method follows a priority-based fallback strategy:
    /// 1. **Primary**: Try to generate template from database model
    /// 2. **Assist**: Check if it's the default Assist complication
    /// 3. **Fallback**: Provide a placeholder template
    ///
    /// The fallback ensures complications never appear blank, which would be a poor user experience.
    ///
    /// - Parameter complication: The `CLKComplication` to generate a template for
    /// - Returns: A `CLKComplicationTemplate` ready for ClockKit to render
    ///
    /// ## Template Sources
    /// - **Database Model**: Custom user-configured complications from Home Assistant
    /// - **Assist Default**: Special complication for launching Assist with one tap
    /// - **Placeholder**: Generic fallback showing the complication family name
    ///
    /// ## Example
    /// ```swift
    /// let template = template(for: complication)
    /// // Always returns a valid template, never nil
    /// ```
    ///
    /// - Important: MaterialDesignIcons must be registered before generating templates
    /// - Note: This method is called every time the watch face updates
    private func template(for complication: CLKComplication) -> CLKComplicationTemplate {
        MaterialDesignIcons.register()

        let template: CLKComplicationTemplate

        if let model = complicationModel(for: complication),
           let generated = model.clkComplicationTemplate(family: complication.family) {
            template = generated
        } else if complication.identifier == AssistDefaultComplication.defaultComplicationId {
            template = AssistDefaultComplication.createAssistTemplate(for: complication.family)
        } else {
            Current.Log.info {
                "no configured template for \(complication.identifier), providing placeholder"
            }

            template = ComplicationGroupMember(family: complication.family)
                .fallbackTemplate(for: complication.identifier)
        }

        return template
    }

    // MARK: - Timeline Configuration

    /// Determines whether a complication should be visible on the lock screen
    ///
    /// This ClockKit delegate method is called to determine privacy behavior for each complication.
    /// It allows users to hide sensitive information when their watch is locked.
    ///
    /// ## Privacy Modes
    /// - `.showOnLockScreen`: Complication is visible even when locked (default)
    /// - `.hideOnLockScreen`: Complication is hidden until watch is unlocked
    ///
    /// - Parameters:
    ///   - complication: The complication to check
    ///   - handler: Completion handler to call with the privacy behavior
    ///
    /// ## Current Implementation
    /// - If model has `isPublic = false`: Hide on lock screen
    /// - If model has `isPublic = true` or missing: Show on lock screen
    /// - If no model found: Default to showing (fail-safe)
    ///
    /// - Note: Currently `isPublic` defaults to `true` for all complications
    /// - Todo: Add UI to let users configure privacy per-complication
    func getPrivacyBehavior(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void
    ) {
        if let model = complicationModel(for: complication) {
            if model.isPublic == false {
                handler(.hideOnLockScreen)
            } else {
                handler(.showOnLockScreen)
            }
        } else {
            // Default to showing on lock screen if no model found
            handler(.showOnLockScreen)
        }
    }

    // MARK: - Timeline Population

    /// Provides the current timeline entry for a complication
    ///
    /// This is the primary method ClockKit calls to get complication content.
    /// It's called frequently (every time the watch face updates), so performance is critical.
    ///
    /// ## Real-Time Template Rendering
    /// This method now supports real-time template rendering for complications with Jinja2 templates.
    /// It will:
    /// 1. Check if the complication has templates that need rendering
    /// 2. Attempt to render them via the Home Assistant API
    /// 3. Update the stored complication with rendered values
    /// 4. Generate the template with fresh data
    ///
    /// If rendering fails or times out, it falls back to the last cached rendered values.
    ///
    /// ## Timeline Entry Components
    /// - **Date**: When this entry should be displayed (encoded with family info for tracking)
    /// - **Template**: The visual representation of the complication
    ///
    /// - Parameters:
    ///   - complication: The complication requesting an entry
    ///   - handler: Completion handler to call with the timeline entry
    ///
    /// ## Date Encoding
    /// The date is encoded with the complication family for debugging purposes:
    /// ```swift
    /// // Helps identify which family triggered a tap in logs
    /// let date = Date().encodedForComplication(family: complication.family)
    /// ```
    ///
    /// - Important: This method MUST call the handler, or the complication won't update
    /// - Note: Currently only provides current entry; could be extended for future/past entries
    /// - SeeAlso: `template(for:)` which generates the actual visual content
    func getCurrentTimelineEntry(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void
    ) {
        Current.Log.verbose {
            "Providing template for \(complication.identifier) family \(complication.family.description)"
        }

        let date = Date().encodedForComplication(family: complication.family) ?? Date()

        // Try to render templates in real-time if needed
        if let model = complicationModel(for: complication),
           !model.rawRendered().isEmpty {
            // This complication has templates that need rendering
            Current.Log.info("Rendering templates in real-time for complication \(complication.identifier)")

            renderTemplatesAndProvideEntry(
                for: complication,
                model: model,
                date: date,
                handler: handler
            )
        } else {
            // No templates to render, use existing data
            handler(.init(date: date, complicationTemplate: template(for: complication)))
        }
    }

    /// Renders templates in real-time and provides the complication entry
    ///
    /// This method:
    /// 1. Extracts templates from the complication that need rendering
    /// 2. Sends them to iPhone for rendering via send/reply message
    /// 3. Updates the database with rendered values
    /// 4. Generates and returns the updated template
    ///
    /// If rendering fails, it falls back to cached values.
    ///
    /// - Parameters:
    ///   - complication: The complication to render
    ///   - model: The complication model from database
    ///   - date: The date for the timeline entry
    ///   - handler: Completion handler to call with the entry
    private func renderTemplatesAndProvideEntry(
        for complication: CLKComplication,
        model: AppWatchComplication,
        date: Date,
        handler: @escaping (CLKComplicationTimelineEntry?) -> Void
    ) {
        guard let serverIdentifier = model.serverIdentifier else {
            Current.Log.warning("No server identifier for complication, using cached values")
            handler(.init(date: date, complicationTemplate: template(for: complication)))
            return
        }

        // Check if iPhone is reachable
        guard Communicator.shared.currentReachability != .notReachable else {
            Current.Log.warning("iPhone not reachable, using cached template values")
            handler(.init(date: date, complicationTemplate: template(for: complication)))
            return
        }

        let rawTemplates = model.rawRendered()

        #if DEBUG
        let timeoutSeconds: TimeInterval = 32.0
        #else
        let timeoutSeconds: TimeInterval = 2.0
        #endif

        var hasCompleted = false

        // Set a timeout fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds) { [weak self] in
            guard let self else { return }
            if !hasCompleted {
                hasCompleted = true
                Current.Log.warning("Template rendering timed out after \(timeoutSeconds)s, using cached values")
                handler(.init(date: date, complicationTemplate: template(for: complication)))
            }
        }

        Current.Log.info("Requesting template rendering from iPhone for complication \(complication.identifier)")

        // Send render request to iPhone via Communicator
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.renderTemplates.rawValue,
            content: [
                "templates": rawTemplates,
                "serverIdentifier": serverIdentifier,
            ],
            reply: { [weak self] replyMessage in
                guard let self else { return }
                guard !hasCompleted else { return }
                hasCompleted = true

                // Check for error
                if let error = replyMessage.content["error"] as? String {
                    Current.Log.error("Template rendering failed: \(error), using cached values")
                    handler(.init(date: date, complicationTemplate: template(for: complication)))
                    return
                }

                // Extract rendered values
                guard let renderedValues = replyMessage.content["rendered"] as? [String: Any] else {
                    Current.Log.error("No rendered values in response, using cached values")
                    handler(.init(date: date, complicationTemplate: template(for: complication)))
                    return
                }

                Current.Log.info("Successfully received \(renderedValues.count) rendered templates from iPhone")

                // Update the database with rendered values
                do {
                    try Current.database().write { db in
                        var updatedModel = model
                        updatedModel.updateRenderedValues(from: renderedValues)
                        try updatedModel.update(db)
                    }

                    // Generate template with fresh rendered values
                    handler(.init(date: date, complicationTemplate: template(for: complication)))
                } catch {
                    Current.Log.error("Failed to update complication with rendered values: \(error)")
                    // Still try to provide the template with cached values
                    handler(.init(date: date, complicationTemplate: template(for: complication)))
                }
            }
        ), errorHandler: { error in
            guard !hasCompleted else { return }
            hasCompleted = true
            Current.Log.error("Failed to send render request to iPhone: \(error), using cached values")
            handler(.init(date: date, complicationTemplate: self.template(for: complication)))
        })
    }

    // MARK: - Placeholder Templates

    /// Provides a sample template for the complication editor
    ///
    /// This ClockKit delegate method is called when:
    /// - User is customizing their watch face
    /// - Browsing available complications in the editor
    /// - Previewing what the complication will look like
    ///
    /// ## Purpose
    /// Shows a representative example of what the complication will display,
    /// helping users decide if they want to add it to their watch face.
    ///
    /// - Parameters:
    ///   - complication: The complication to provide a sample for
    ///   - handler: Completion handler to call with the sample template
    ///
    /// ## Implementation
    /// Currently returns the same template as `getCurrentTimelineEntry`,
    /// showing real data rather than a static placeholder.
    ///
    /// - Note: This could be customized to show a specific sample/demo template
    /// - SeeAlso: `template(for:)` for the actual template generation
    func getLocalizableSampleTemplate(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationTemplate?) -> Void
    ) {
        handler(template(for: complication))
    }

    // MARK: - Complication Descriptors

    /// Provides the list of all available complications for the watch face editor
    ///
    /// This ClockKit delegate method is called when:
    /// - Watch face editor is opened
    /// - User wants to add/change a complication
    /// - System needs to update the available complication list
    ///
    /// ## Descriptor Categories
    /// 1. **Configured**: User-created complications from Home Assistant (from GRDB)
    /// 2. **Placeholders**: Generic placeholders for each family type
    /// 3. **Assist Default**: Special complication for launching Assist
    ///
    /// - Parameter handler: Completion handler to call with the descriptor array
    ///
    /// ## Data Flow
    /// ```
    /// Fetch all AppWatchComplications from GRDB
    ///     ↓
    /// Map to CLKComplicationDescriptors
    ///     ↓
    /// Add placeholders + Assist default
    ///     ↓
    /// Return combined list to ClockKit
    /// ```
    ///
    /// ## Descriptor Properties
    /// Each descriptor contains:
    /// - `identifier`: Unique ID for the complication
    /// - `displayName`: Human-readable name shown in editor
    /// - `supportedFamilies`: Which watch face slots it can fill
    ///
    /// - Important: This determines what users see in the watch face editor
    /// - Note: Errors result in empty configured list, but placeholders are still shown
    /// - SeeAlso: `AppWatchComplication.complicationDescriptor` for descriptor creation
    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        // Fetch complications from GRDB
        let configured: [CLKComplicationDescriptor]
        do {
            let appComplications = try Current.database().read { db in
                try AppWatchComplication.fetchAll(from: db)
            }

            // Map directly to descriptors - no conversion needed!
            configured = appComplications.map(\.complicationDescriptor)
        } catch {
            Current.Log.error("Failed to fetch complications from GRDB: \(error.localizedDescription)")
            configured = []
        }

        let placeholders = ComplicationGroupMember.allCases
            .map(\.placeholderComplicationDescriptor)

        let assistDefaultComplicationDescriptor = [AssistDefaultComplication.descriptor]

        handler(configured + placeholders + assistDefaultComplicationDescriptor)
    }
}

// MARK: - CLKComplicationFamily Extension

/// Extension providing human-readable descriptions for complication families
///
/// This extension helps with logging and debugging by providing clear names
/// for each complication family type instead of raw enum values.
///
/// ## Complication Families
/// ClockKit supports various complication families, each designed for
/// different watch face slots and sizes:
///
/// ### Classic Families (Pre-watchOS 7)
/// - **Circular Small**: Small circular slot
/// - **Modular Small/Large**: Modular watch face slots
/// - **Utilitarian Small/Large**: Utility-focused watch faces
/// - **Extra Large**: Large central complication
///
/// ### Graphic Families (watchOS 7+)
/// - **Graphic Corner**: Corner slot on Infograph faces
/// - **Graphic Circular**: Circular graphic complication
/// - **Graphic Rectangular**: Rectangular graphic complication
/// - **Graphic Bezel**: Bezel around circular complications
///
/// - Note: The `default` case handles future family types Apple may add
/// - SeeAlso: [CLKComplicationFamily
/// Documentation](https://developer.apple.com/documentation/clockkit/clkcomplicationfamily)
extension CLKComplicationFamily {
    /// Human-readable description of the complication family
    ///
    /// Provides clear, user-friendly names for each family type,
    /// useful for logging and debugging.
    ///
    /// - Returns: A string description of the family (e.g., "Graphic Corner")
    ///
    /// ## Example Usage
    /// ```swift
    /// Current.Log.verbose("Providing template for \(complication.family.description)")
    /// // Logs: "Providing template for Graphic Corner"
    /// ```
    var description: String {
        switch self {
        case .circularSmall:
            return "Circular Small"
        case .extraLarge:
            return "Extra Large"
        case .graphicBezel:
            return "Graphic Bezel"
        case .graphicCircular:
            return "Graphic Circular"
        case .graphicCorner:
            return "Graphic Corner"
        case .graphicRectangular:
            return "Graphic Rectangular"
        case .modularLarge:
            return "Modular Large"
        case .modularSmall:
            return "Modular Small"
        case .utilitarianLarge:
            return "Utilitarian Large"
        case .utilitarianSmall:
            return "Utilitarian Small"
        case .utilitarianSmallFlat:
            return "Utilitarian Small Flat"
        default:
            return "unknown"
        }
    }
}
