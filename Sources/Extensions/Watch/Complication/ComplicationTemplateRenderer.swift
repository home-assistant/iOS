import ClockKit
import Foundation
import HAKit
import Shared

// MARK: - Protocol

/// Protocol for rendering complication templates with real-time data from Home Assistant
///
/// This protocol defines the contract for services that can render Jinja2 templates
/// stored in complication models by calling the Home Assistant API.
///
/// ## Purpose
/// Separates the concerns of template rendering from complication data source logic,
/// making the code more testable, maintainable, and focused.
///
/// ## Implementation Requirements
/// Implementers must:
/// 1. Sync network information before rendering
/// 2. Call Home Assistant's template API endpoint
/// 3. Parse and update the database with rendered values
/// 4. Handle timeouts and errors gracefully
/// 5. Always call the completion handler (even on failure)
///
/// ## Example Usage
/// ```swift
/// let renderer: ComplicationTemplateRendering = ComplicationTemplateRenderer()
///
/// renderer.renderAndProvideEntry(
///     for: complication,
///     model: watchComplication,
///     date: Date()
/// ) { entry in
///     handler(entry)
/// }
/// ```
protocol ComplicationTemplateRendering {
    /// Renders templates for a complication and provides a timeline entry
    ///
    /// This method orchestrates the entire template rendering flow:
    /// 1. Validates preconditions (server identifier exists)
    /// 2. Syncs network information for accurate URL selection
    /// 3. Fetches server and API connection
    /// 4. Renders templates via Home Assistant API
    /// 5. Updates database with rendered values
    /// 6. Generates final ClockKit template
    ///
    /// - Parameters:
    ///   - complication: The ClockKit complication to render
    ///   - model: The complication model containing templates to render
    ///   - date: The date to use for the timeline entry
    ///   - completion: Handler called with the timeline entry (never nil, uses fallback on error)
    ///
    /// - Note: Always calls completion, even if rendering fails (uses cached values as fallback)
    /// - Important: Completion may be called on a background queue
    func renderAndProvideEntry(
        for complication: CLKComplication,
        model: AppWatchComplication,
        date: Date,
        completion: @escaping (CLKComplicationTimelineEntry) -> Void
    )
}

// MARK: - Implementation

/// Default implementation of template rendering for watch complications
///
/// This class handles the complete lifecycle of rendering Jinja2 templates
/// from Home Assistant and converting them into ClockKit complication templates.
///
/// ## Architecture
/// The renderer breaks down the rendering process into focused, single-responsibility methods:
/// - `syncNetwork`: Ensures network information is current
/// - `validateServer`: Confirms server and API are available
/// - `renderTemplates`: Calls Home Assistant API with combined template string
/// - `parseResponse`: Extracts rendered values from API response
/// - `updateDatabase`: Persists rendered values for caching
/// - `generateTemplate`: Creates ClockKit template from model
///
/// ## Timeout Handling
/// A 5-second timeout is enforced to prevent blocking the complication system.
/// If rendering takes too long, the cached values are used instead.
///
/// ## Error Handling
/// All errors result in graceful fallback to cached values. The complication
/// is never left in a broken state.
///
/// - SeeAlso: `ComplicationTemplateRendering` for protocol contract
final class ComplicationTemplateRenderer: ComplicationTemplateRendering {
    // MARK: - Properties

    /// Timeout duration for template rendering requests
    private let timeoutSeconds: TimeInterval = 5

    /// Fallback template provider for generating templates when data isn't available
    private let templateProvider: ComplicationTemplateProvider

    // MARK: - Initialization

    /// Creates a new template renderer
    ///
    /// - Parameter templateProvider: Provider for generating fallback templates
    init(templateProvider: ComplicationTemplateProvider = DefaultComplicationTemplateProvider()) {
        self.templateProvider = templateProvider
    }

    // MARK: - ComplicationTemplateRendering

    func renderAndProvideEntry(
        for complication: CLKComplication,
        model: AppWatchComplication,
        date: Date,
        completion: @escaping (CLKComplicationTimelineEntry) -> Void
    ) {
        // Validate server identifier exists
        guard let serverIdentifier = model.serverIdentifier else {
            Current.Log.warning("No server identifier for complication, using cached values")
            provideFallbackEntry(for: complication, date: date, completion: completion)
            return
        }

        Current.Log.info("Starting template rendering for complication \(complication.identifier)")

        // Step 1: Sync network information to ensure accurate URL selection
        syncNetworkInformation { [weak self] in
            guard let self else { return }

            // Step 2: Validate server and API connection are available
            guard let (server, connection) = validateServerAndConnection(
                serverIdentifier: serverIdentifier,
                complication: complication,
                date: date,
                completion: completion
            ) else {
                return // Validation failed, fallback already provided
            }

            // Step 3: Render templates via Home Assistant API
            renderTemplates(
                for: complication,
                model: model,
                server: server,
                connection: connection,
                date: date,
                completion: completion
            )
        }
    }

    // MARK: - Private Methods - Orchestration

    /// Syncs network information before proceeding with rendering
    ///
    /// Network sync is critical for accurate URL selection (internal vs external).
    /// It updates SSID information and connectivity state.
    ///
    /// - Parameter completion: Called when sync completes
    private func syncNetworkInformation(completion: @escaping () -> Void) {
        Current.Log.info("Syncing network information before rendering templates")

        Current.connectivity.syncNetworkInformation {
            Current.Log.info("Network information sync completed")
            completion()
        }
    }

    /// Validates that server and API connection are available
    ///
    /// This method checks that:
    /// 1. Server exists for the given identifier
    /// 2. API instance is available for the server
    /// 3. API has an active connection
    ///
    /// If validation fails, it logs an error and provides a fallback entry.
    ///
    /// - Parameters:
    ///   - serverIdentifier: The server identifier from the complication model
    ///   - complication: The complication being rendered
    ///   - date: Date for the timeline entry
    ///   - completion: Completion handler to call with fallback if validation fails
    /// - Returns: Tuple of (Server, HAConnection) if valid, nil if validation fails
    private func validateServerAndConnection(
        serverIdentifier: String,
        complication: CLKComplication,
        date: Date,
        completion: @escaping (CLKComplicationTimelineEntry) -> Void
    ) -> (Server, HAConnection)? {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverIdentifier }),
              let api = Current.api(for: server) else {
            Current.Log.error("No API available for server \(serverIdentifier), using cached values")
            provideFallbackEntry(for: complication, date: date, completion: completion)
            return nil
        }

        return (server, api.connection)
    }

    /// Renders templates by calling the Home Assistant API
    ///
    /// This method:
    /// 1. Extracts raw templates from the model
    /// 2. Combines them into a single API request
    /// 3. Sends the request with timeout handling
    /// 4. Processes the response and updates the database
    /// 5. Generates the final ClockKit template
    ///
    /// ## Template Format
    /// Templates are combined using special separators:
    /// - `:::` separates key from template
    /// - `|||` separates different templates
    ///
    /// Example: `"key1:::{{template1}}|||key2:::{{template2}}"`
    ///
    /// - Parameters:
    ///   - complication: The complication being rendered
    ///   - model: The complication model with templates
    ///   - server: The Home Assistant server
    ///   - connection: The HAKit connection to use
    ///   - date: Date for the timeline entry
    ///   - completion: Called with the final entry
    private func renderTemplates(
        for complication: CLKComplication,
        model: AppWatchComplication,
        server: Server,
        connection: HAConnection,
        date: Date,
        completion: @escaping (CLKComplicationTimelineEntry) -> Void
    ) {
        let rawTemplates = model.rawRendered()

        // Use a class wrapper to share state between closures
        let completionState = CompletionState()

        // Set up timeout fallback
        setupTimeout(
            for: complication,
            date: date,
            completionState: completionState,
            completion: completion
        )

        Current.Log.info("Rendering templates directly from watch API for complication \(complication.identifier)")

        // Combine templates into single request string
        let combinedTemplate = createCombinedTemplateString(from: rawTemplates)

        // Send API request
        sendRenderRequest(
            combinedTemplate: combinedTemplate,
            connection: connection,
            onComplete: { [weak self] result in
                guard let self else { return }
                guard !completionState.hasCompleted else { return }
                completionState.hasCompleted = true

                handleRenderResponse(
                    result: result,
                    rawTemplates: rawTemplates,
                    model: model,
                    complication: complication,
                    date: date,
                    completion: completion
                )
            }
        )
    }

    // MARK: - Private Methods - Template Processing

    /// Creates a combined template string for batch rendering
    ///
    /// Combines multiple templates into a single string that can be sent
    /// in one API request, improving performance.
    ///
    /// - Parameter templates: Dictionary of template keys to template strings
    /// - Returns: Combined template string with separators
    ///
    /// ## Format
    /// ```
    /// key1:::{{template1}}|||key2:::{{template2}}|||key3:::{{template3}}
    /// ```
    private func createCombinedTemplateString(from templates: [String: String]) -> String {
        templates
            .map { key, template in "\(key):::\(template)" }
            .joined(separator: "|||")
    }

    /// Sends the template render request to Home Assistant
    ///
    /// - Parameters:
    ///   - combinedTemplate: The combined template string
    ///   - connection: HAKit connection to use
    ///   - onComplete: Handler called with the result
    private func sendRenderRequest(
        combinedTemplate: String,
        connection: HAConnection,
        onComplete: @escaping (Result<HAData, HAError>) -> Void
    ) {
        connection.send(.init(
            type: .rest(.post, "template"),
            data: ["template": combinedTemplate],
            shouldRetry: true
        ), completion: onComplete)
    }

    /// Sets up a timeout fallback for template rendering
    ///
    /// If rendering takes longer than `timeoutSeconds`, the completion
    /// is called with a fallback template using cached values.
    ///
    /// - Parameters:
    ///   - complication: The complication being rendered
    ///   - date: Date for the timeline entry
    ///   - completionState: Wrapper object to track completion status
    ///   - completion: Handler to call on timeout
    private func setupTimeout(
        for complication: CLKComplication,
        date: Date,
        completionState: CompletionState,
        completion: @escaping (CLKComplicationTimelineEntry) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds) { [weak self] in
            guard let self else { return }
            if !completionState.hasCompleted {
                completionState.hasCompleted = true
                Current.Log.warning("Template rendering timed out after \(timeoutSeconds)s, using cached values")
                provideFallbackEntry(for: complication, date: date, completion: completion)
            }
        }
    }

    /// Helper class to track completion state across multiple closures
    private final class CompletionState {
        var hasCompleted = false
    }

    // MARK: - Private Methods - Response Handling

    /// Handles the response from the template render API
    ///
    /// - Parameters:
    ///   - result: The result from HAKit
    ///   - rawTemplates: Original template dictionary for validation
    ///   - model: Complication model to update
    ///   - complication: The complication being rendered
    ///   - date: Date for the timeline entry
    ///   - completion: Handler to call with final entry
    private func handleRenderResponse(
        result: Result<HAData, HAError>,
        rawTemplates: [String: String],
        model: AppWatchComplication,
        complication: CLKComplication,
        date: Date,
        completion: @escaping (CLKComplicationTimelineEntry) -> Void
    ) {
        switch result {
        case let .success(data):
            handleSuccessResponse(
                data: data,
                rawTemplates: rawTemplates,
                model: model,
                complication: complication,
                date: date,
                completion: completion
            )

        case let .failure(error):
            Current.Log.error("Failed to render templates: \(error), using cached values")
            provideFallbackEntry(for: complication, date: date, completion: completion)
        }
    }

    /// Handles successful API response
    ///
    /// - Parameters:
    ///   - data: The HAData from the API
    ///   - rawTemplates: Original templates for validation
    ///   - model: Model to update with rendered values
    ///   - complication: The complication being rendered
    ///   - date: Date for the timeline entry
    ///   - completion: Handler to call with final entry
    private func handleSuccessResponse(
        data: HAData,
        rawTemplates: [String: String],
        model: AppWatchComplication,
        complication: CLKComplication,
        date: Date,
        completion: @escaping (CLKComplicationTimelineEntry) -> Void
    ) {
        guard case let .primitive(response) = data,
              let renderedString = response as? String else {
            Current.Log.error("Template rendering returned non-string response, using cached values")
            provideFallbackEntry(for: complication, date: date, completion: completion)
            return
        }

        let renderedResults = parseRenderedTemplates(from: renderedString)

        guard renderedResults.count == rawTemplates.count else {
            Current.Log.error(
                "Rendered count mismatch: expected \(rawTemplates.count), got \(renderedResults.count), using cached values"
            )
            provideFallbackEntry(for: complication, date: date, completion: completion)
            return
        }

        Current.Log.info("Successfully rendered \(renderedResults.count) templates")

        updateDatabaseAndProvideEntry(
            renderedResults: renderedResults,
            model: model,
            complication: complication,
            date: date,
            completion: completion
        )
    }

    /// Parses rendered templates from the API response string
    ///
    /// Splits the combined response back into individual key-value pairs.
    ///
    /// - Parameter renderedString: The combined response from Home Assistant
    /// - Returns: Dictionary of template keys to rendered values
    ///
    /// ## Expected Format
    /// ```
    /// key1:::rendered_value1|||key2:::rendered_value2
    /// ```
    private func parseRenderedTemplates(from renderedString: String) -> [String: Any] {
        var renderedResults: [String: Any] = [:]

        let parts = renderedString.components(separatedBy: "|||")

        for part in parts {
            let keyValue = part.components(separatedBy: ":::")
            if keyValue.count == 2 {
                let key = keyValue[0]
                let value = keyValue[1]
                renderedResults[key] = value
            }
        }

        return renderedResults
    }

    // MARK: - Private Methods - Database & Template Generation

    /// Updates the database with rendered values and provides the entry
    ///
    /// - Parameters:
    ///   - renderedResults: Rendered template values
    ///   - model: Model to update
    ///   - complication: The complication being rendered
    ///   - date: Date for the timeline entry
    ///   - completion: Handler to call with final entry
    private func updateDatabaseAndProvideEntry(
        renderedResults: [String: Any],
        model: AppWatchComplication,
        complication: CLKComplication,
        date: Date,
        completion: @escaping (CLKComplicationTimelineEntry) -> Void
    ) {
        do {
            try Current.database().write { db in
                var updatedModel = model
                updatedModel.updateRenderedValues(from: renderedResults)
                try updatedModel.update(db)
            }

            provideEntry(for: complication, date: date, completion: completion)
        } catch {
            Current.Log.error("Failed to update complication with rendered values: \(error)")
            provideFallbackEntry(for: complication, date: date, completion: completion)
        }
    }

    /// Provides a timeline entry with the current template
    ///
    /// - Parameters:
    ///   - complication: The complication to generate a template for
    ///   - date: Date for the timeline entry
    ///   - completion: Handler to call with the entry
    private func provideEntry(
        for complication: CLKComplication,
        date: Date,
        completion: @escaping (CLKComplicationTimelineEntry) -> Void
    ) {
        let template = templateProvider.template(for: complication)
        let entry = CLKComplicationTimelineEntry(date: date, complicationTemplate: template)
        completion(entry)
    }

    /// Provides a fallback timeline entry using cached values
    ///
    /// This is called when rendering fails or times out.
    ///
    /// - Parameters:
    ///   - complication: The complication to generate a template for
    ///   - date: Date for the timeline entry
    ///   - completion: Handler to call with the entry
    private func provideFallbackEntry(
        for complication: CLKComplication,
        date: Date,
        completion: @escaping (CLKComplicationTimelineEntry) -> Void
    ) {
        let template = templateProvider.template(for: complication)
        let entry = CLKComplicationTimelineEntry(date: date, complicationTemplate: template)
        completion(entry)
    }
}

// MARK: - Template Provider Protocol

/// Protocol for generating ClockKit templates from complication models
///
/// This abstraction allows the renderer to generate templates without
/// needing to know about the ComplicationController's implementation details.
protocol ComplicationTemplateProvider {
    /// Generates a ClockKit template for a complication
    ///
    /// - Parameter complication: The complication to generate a template for
    /// - Returns: A valid ClockKit template (never nil)
    func template(for complication: CLKComplication) -> CLKComplicationTemplate
}

// MARK: - Default Template Provider

/// Default implementation that uses the ComplicationController's template generation
final class DefaultComplicationTemplateProvider: ComplicationTemplateProvider {
    func template(for complication: CLKComplication) -> CLKComplicationTemplate {
        // Register icons before generating templates
        MaterialDesignIcons.register()

        // Try to fetch model and generate template
        if let model = fetchComplicationModel(for: complication),
           let generated = model.clkComplicationTemplate(family: complication.family) {
            return generated
        }

        // Check for Assist default complication
        if complication.identifier == AssistDefaultComplication.defaultComplicationId {
            return AssistDefaultComplication.createAssistTemplate(for: complication.family)
        }

        // Fallback to placeholder
        Current.Log.info {
            "no configured template for \(complication.identifier), providing placeholder"
        }

        return ComplicationGroupMember(family: complication.family)
            .fallbackTemplate(for: complication.identifier)
    }

    /// Fetches the complication model from database
    ///
    /// - Parameter complication: The complication to fetch
    /// - Returns: The model if found, nil otherwise
    private func fetchComplicationModel(for complication: CLKComplication) -> AppWatchComplication? {
        do {
            if complication.identifier != CLKDefaultComplicationIdentifier {
                return try Current.database().read { db in
                    try AppWatchComplication.fetch(identifier: complication.identifier, from: db)
                }
            } else {
                let matchedFamily = ComplicationGroupMember(family: complication.family)
                return try Current.database().read { db in
                    try AppWatchComplication.fetch(identifier: matchedFamily.rawValue, from: db)
                }
            }
        } catch {
            Current.Log.error("Failed to fetch complication from GRDB: \(error.localizedDescription)")
            return nil
        }
    }
}
