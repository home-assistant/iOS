# Complication Template Rendering Architecture

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         ClockKit System                          │
│  (Requests complication updates from ComplicationController)    │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                   ComplicationController                         │
│  - CLKComplicationDataSource implementation                     │
│  - Manages complication descriptors and timeline                │
│  - Delegates rendering to ComplicationTemplateRenderer          │
│                                                                   │
│  Properties:                                                     │
│  • templateRenderer: ComplicationTemplateRendering               │
│                                                                   │
│  Methods (simplified):                                           │
│  • getCurrentTimelineEntry(...) - Main ClockKit callback        │
│  • renderTemplatesAndProvideEntry(...) - Delegates to renderer  │
│  • template(for:) - Generates templates                         │
└────────────────────────────┬────────────────────────────────────┘
                             │ delegates to
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│        <<protocol>> ComplicationTemplateRendering               │
│  • renderAndProvideEntry(for:model:date:completion:)            │
└────────────────────────────┬────────────────────────────────────┘
                             │ implemented by
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              ComplicationTemplateRenderer                        │
│  Handles complete template rendering lifecycle                  │
│                                                                   │
│  Orchestration:                                                  │
│  • renderAndProvideEntry(...) - Main entry point                │
│  • syncNetworkInformation(...) - Network sync                   │
│  • validateServerAndConnection(...) - Validation                │
│  • renderTemplates(...) - Rendering coordinator                 │
│                                                                   │
│  Template Processing:                                            │
│  • createCombinedTemplateString(...) - Batch preparation        │
│  • sendRenderRequest(...) - API communication                   │
│  • setupTimeout(...) - Timeout handling                         │
│                                                                   │
│  Response Handling:                                              │
│  • handleRenderResponse(...) - Response router                  │
│  • handleSuccessResponse(...) - Success processor               │
│  • parseRenderedTemplates(...) - Parse response                 │
│                                                                   │
│  Database & Generation:                                          │
│  • updateDatabaseAndProvideEntry(...) - DB update               │
│  • provideEntry(...) - Generate timeline entry                  │
│  • provideFallbackEntry(...) - Fallback on error                │
└────────────────────────────┬────────────────────────────────────┘
                             │ uses
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│        <<protocol>> ComplicationTemplateProvider                │
│  • template(for: CLKComplication) -> CLKComplicationTemplate    │
└────────────────────────────┬────────────────────────────────────┘
                             │ implemented by
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│          DefaultComplicationTemplateProvider                     │
│  Generates ClockKit templates from complication models          │
│                                                                   │
│  Methods:                                                        │
│  • template(for:) - Main template generation                    │
│  • fetchComplicationModel(for:) - Database fetch                │
│                                                                   │
│  Fallback Chain:                                                 │
│  1. Model from database → clkComplicationTemplate               │
│  2. Assist default → AssistDefaultComplication.createTemplate   │
│  3. Placeholder → ComplicationGroupMember.fallbackTemplate      │
└─────────────────────────────────────────────────────────────────┘
```

## Sequence Diagram: Template Rendering Flow

```
ClockKit  Controller  Renderer   Network  HAConnection  Database
   │          │          │          │          │           │
   │ getCurrentTimelineEntry        │          │           │
   ├─────────>│          │          │          │           │
   │          │          │          │          │           │
   │          │ renderAndProvideEntry         │           │
   │          ├─────────>│          │          │           │
   │          │          │          │          │           │
   │          │          │ Validate server    │           │
   │          │          │  identifier        │           │
   │          │          │────┐     │          │           │
   │          │          │    │     │          │           │
   │          │          │<───┘     │          │           │
   │          │          │          │          │           │
   │          │          │ syncNetworkInformation          │
   │          │          ├─────────>│          │           │
   │          │          │          │          │           │
   │          │          │<─────────┤          │           │
   │          │          │  (complete)         │           │
   │          │          │          │          │           │
   │          │          │ Validate server    │           │
   │          │          │  & connection      │           │
   │          │          │────┐     │          │           │
   │          │          │    │     │          │           │
   │          │          │<───┘     │          │           │
   │          │          │          │          │           │
   │          │          │ Combine templates  │           │
   │          │          │────┐     │          │           │
   │          │          │    │     │          │           │
   │          │          │<───┘     │          │           │
   │          │          │          │          │           │
   │          │          │ send(template API) │           │
   │          │          ├─────────────────────>          │
   │          │          │          │          │           │
   │          │          │ (5s timeout running)           │
   │          │          │          │          │           │
   │          │          │<─────────────────────┤          │
   │          │          │  (response)          │           │
   │          │          │          │          │           │
   │          │          │ Parse response      │           │
   │          │          │────┐     │          │           │
   │          │          │    │     │          │           │
   │          │          │<───┘     │          │           │
   │          │          │          │          │           │
   │          │          │ Update database     │           │
   │          │          ├─────────────────────────────────>
   │          │          │          │          │           │
   │          │          │<─────────────────────────────────┤
   │          │          │  (saved)            │           │
   │          │          │          │          │           │
   │          │          │ Generate template   │           │
   │          │          │────┐     │          │           │
   │          │          │    │     │          │           │
   │          │          │<───┘     │          │           │
   │          │          │          │          │           │
   │          │<─────────┤          │          │           │
   │          │  (entry) │          │          │           │
   │          │          │          │          │           │
   │<─────────┤          │          │          │           │
   │ (entry)  │          │          │          │           │
   │          │          │          │          │           │
```

## Error Handling Flow

```
┌──────────────────────────┐
│  Start Rendering         │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐     ┌─────────────────────┐
│ Check Server Identifier  │────>│ Missing Identifier  │
└────────────┬─────────────┘     └──────────┬──────────┘
             │ ✓                            │
             ▼                              ▼
┌──────────────────────────┐         ┌──────────────┐
│ Sync Network Info        │         │   Fallback   │
└────────────┬─────────────┘         │    Entry     │
             │                        └──────────────┘
             ▼                              ▲
┌──────────────────────────┐     ┌─────────┴──────────┐
│ Validate Server & API    │────>│ Server/API Missing │
└────────────┬─────────────┘     └────────────────────┘
             │ ✓                            │
             ▼                              │
┌──────────────────────────┐     ┌─────────┴──────────┐
│ Send API Request         │────>│   Timeout (5s)     │
└────────────┬─────────────┘     └────────────────────┘
             │ ✓                            │
             ▼                              │
┌──────────────────────────┐     ┌─────────┴──────────┐
│ Parse Response           │────>│   Parse Error      │
└────────────┬─────────────┘     └────────────────────┘
             │ ✓                            │
             ▼                              │
┌──────────────────────────┐     ┌─────────┴──────────┐
│ Update Database          │────>│   DB Error         │
└────────────┬─────────────┘     └────────────────────┘
             │ ✓                            │
             ▼                              │
┌──────────────────────────┐               │
│ Generate Template        │               │
└────────────┬─────────────┘               │
             │                              │
             ▼                              │
┌──────────────────────────┐               │
│  Provide Entry           │<──────────────┘
└──────────────────────────┘
```

## Dependency Graph

```
ComplicationController
    │
    ├─► ComplicationTemplateRendering (protocol)
    │       └─► ComplicationTemplateRenderer (implementation)
    │               │
    │               ├─► Current.connectivity (network sync)
    │               ├─► Current.servers (server management)
    │               ├─► Current.api(for:) (API access)
    │               ├─► HAConnection (Home Assistant API)
    │               ├─► Current.database() (GRDB database)
    │               └─► ComplicationTemplateProvider (protocol)
    │                       └─► DefaultComplicationTemplateProvider
    │                               │
    │                               ├─► AppWatchComplication (model)
    │                               ├─► MaterialDesignIcons (icons)
    │                               ├─► AssistDefaultComplication (special)
    │                               └─► ComplicationGroupMember (fallback)
    │
    └─► Direct Dependencies:
            ├─► Current.database() (model fetching)
            ├─► AppWatchComplication (data model)
            ├─► CLKComplicationDataSource (protocol)
            └─► ComplicationGroupMember (helpers)
```

## Key Responsibilities

### ComplicationController
- **Primary Role**: CLKComplicationDataSource implementation
- **Responsibilities**:
  - Respond to ClockKit callbacks
  - Fetch complication models from database
  - Provide complication descriptors
  - Manage privacy settings
  - Delegate rendering to renderer

### ComplicationTemplateRenderer
- **Primary Role**: Template rendering orchestration
- **Responsibilities**:
  - Sync network information
  - Validate server availability
  - Call Home Assistant API
  - Parse and cache rendered values
  - Handle timeouts and errors
  - Generate final templates

### ComplicationTemplateProvider
- **Primary Role**: Template generation abstraction
- **Responsibilities**:
  - Fetch models from database
  - Generate ClockKit templates
  - Provide fallback templates
  - Handle special cases (Assist, placeholders)

## Benefits Visualization

```
Before:
┌───────────────────────────────────────┐
│     ComplicationController            │
│                                        │
│  ┌──────────────────────────────────┐ │
│  │  renderTemplatesAndProvideEntry  │ │
│  │                                   │ │
│  │  • Network sync                  │ │
│  │  • Server validation             │ │
│  │  • Template combining            │ │
│  │  • API communication             │ │
│  │  • Response parsing              │ │
│  │  • Database updates              │ │
│  │  • Template generation           │ │
│  │  • Error handling                │ │
│  │  • Timeout management            │ │
│  │                                   │ │
│  │  (~150 lines, mixed concerns)   │ │
│  └──────────────────────────────────┘ │
└───────────────────────────────────────┘

After:
┌──────────────────────┐    ┌────────────────────────────┐
│ ComplicationController│───>│ ComplicationTemplateRenderer│
│                       │    │                             │
│ • ClockKit callbacks │    │ ┌────────────────────────┐ │
│ • Model fetching     │    │ │ Network Sync           │ │
│ • Descriptors        │    │ └────────────────────────┘ │
│ • Privacy settings   │    │ ┌────────────────────────┐ │
│                       │    │ │ Server Validation      │ │
│ (~20 lines rendering)│    │ └────────────────────────┘ │
└──────────────────────┘    │ ┌────────────────────────┐ │
                             │ │ Template Processing    │ │
                             │ └────────────────────────┘ │
                             │ ┌────────────────────────┐ │
                             │ │ API Communication      │ │
                             │ └────────────────────────┘ │
                             │ ┌────────────────────────┐ │
                             │ │ Response Parsing       │ │
                             │ └────────────────────────┘ │
                             │ ┌────────────────────────┐ │
                             │ │ Database Updates       │ │
                             │ └────────────────────────┘ │
                             │                             │
                             │ (13 focused methods)       │
                             └────────────────────────────┘
```
