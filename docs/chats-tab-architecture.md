# Chats Tab Architecture

This document provides a comprehensive reference for AI agents working with the chats tab implementation in this Telegram iOS fork.

## Overview

The chats tab displays the user's conversations using a reactive, async-rendering architecture built on:
- **SwiftSignal**: Reactive data binding and state management
- **AsyncDisplayKit**: Async UI rendering for smooth scrolling
- **Postbox**: Local database layer for chat data

## Architecture Diagram

```
TelegramRootController
    │
    ▼
TabBarControllerImpl ─────────────────────────────────┐
    │                                                 │
    ▼                                                 │
ChatListControllerImpl ◄── ChatListController.swift   │
    │                                                 │
    ▼                                                 │
ChatListControllerNode ◄── ChatListControllerNode.swift
    │
    ▼
ChatListContainerNode (manages filter tabs)
    │
    ▼
ChatListContainerItemNode (per-filter wrapper)
    │
    ▼
ChatListNode ◄── ChatListNode.swift (core list)
    │
    ├──► Postbox/ViewTracker (data fetching)
    │
    └──► ChatListItem (individual row rendering)
```

## Key Files

| Component | Path | Purpose |
|-----------|------|---------|
| Root Controller | `submodules/TelegramUI/Sources/TelegramRootController.swift` | Tab bar setup & initialization |
| Tab Bar | `submodules/TabBarUI/Sources/TabBarController.swift` | Tab switching & management |
| Chat List Controller | `submodules/ChatListUI/Sources/ChatListController.swift` | Primary controller logic |
| Controller Node | `submodules/ChatListUI/Sources/ChatListControllerNode.swift` | Layout & presentation |
| Container Item | `submodules/ChatListUI/Sources/ChatListContainerItemNode.swift` | Filter-specific container |
| List Node | `submodules/ChatListUI/Sources/Node/ChatListNode.swift` | Core list rendering |
| Entries | `submodules/ChatListUI/Sources/Node/ChatListNodeEntries.swift` | Entry types & conversion |
| Chat Item | `submodules/ChatListUI/Sources/Node/ChatListItem.swift` | Individual row rendering |
| Data Location | `submodules/ChatListUI/Sources/Node/ChatListNodeLocation.swift` | Data fetching & filtering |
| Postbox View | `submodules/Postbox/Sources/ChatListView.swift` | Database data structures |

## Component Details

### 1. TelegramRootController

**File**: `submodules/TelegramUI/Sources/TelegramRootController.swift`

The root navigation controller that hosts the tab bar. Key setup in `addRootControllers()`:

```swift
// Creates tab bar controller
let tabBarController = TabBarControllerImpl(...)

// Creates chat list controller via shared context
let chatListController = context.sharedContext.makeChatListController(...)

// Sets up tabs array: [Chats, Calls (optional), Settings]
tabBarController.setControllers(controllers, selectedIndex: 0)
```

**Key Properties**:
- `rootTabController: TabBarController?` - Reference to tab bar
- `chatListController: ChatListController?` - Reference to chat list

### 2. ChatListControllerImpl

**File**: `submodules/ChatListUI/Sources/ChatListController.swift`

Primary view controller for the chats tab. Manages state, filters, and user interactions.

**Key Properties**:
```swift
let context: AccountContext           // App context
let location: ChatListControllerLocation  // Main list, forum, etc.
var primaryContext: ChatListLocationContext?  // Main data context
var secondaryContext: ChatListLocationContext? // Filter context
var tabContainerData: ([ChatListFilterTabEntry], Bool, Int32?)? // Folder tabs
```

**State Management**:
```swift
let stateDisposable: MetaDisposable    // Chat list state updates
let filterDisposable: MetaDisposable   // Filter updates
let badgeDisposable: Disposable?       // Unread badge updates
```

### 3. ChatListControllerNode

**File**: `submodules/ChatListUI/Sources/ChatListControllerNode.swift`

ASDisplayNode managing the layout. Contains a `ChatListContainerNode` for multi-filter support.

**Key Responsibilities**:
- Managing item nodes (filtered chat lists)
- Handling filter switching animations
- Layout and keyboard management

### 4. ChatListContainerItemNode

**File**: `submodules/ChatListUI/Sources/ChatListContainerItemNode.swift`

Wraps individual filter/folder displays.

**Key Components**:
```swift
let listNode: ChatListNode              // Actual chat list
var emptyNode: ChatListEmptyNode?       // Empty state
var emptyShimmerEffectNode: ChatListShimmerNode? // Loading state
```

**Initialization**:
```swift
self.listNode = ChatListNode(
    context: context,
    location: location,
    chatListFilter: filter,
    previewing: previewing,
    fillPreloadItems: controlsHistoryPreload,
    mode: chatListMode,
    ...
)
```

### 5. ChatListNode

**File**: `submodules/ChatListUI/Sources/Node/ChatListNode.swift`

The core async display node for list rendering. This is where most of the complexity lives.

**State Structure**:
```swift
public struct ChatListNodeState: Equatable {
    public var presentationData: ChatListPresentationData
    public var editing: Bool
    public var peerIdWithRevealedOptions: ItemId?
    public var selectedPeerIds: Set<EnginePeer.Id>
    public var pendingRemovalItemIds: Set<ItemId>
    public var peerInputActivities: ChatListNodePeerInputActivities?
    public var selectedThreadIds: Set<Int64>
    public var archiveStoryState: StoryState?
}
```

**Key Properties**:
- `chatListView: ChatListNodeView?` - Current view of chat data
- `listContainerNode: ListNode?` - AsyncDisplayKit list
- `itemNodes: [ChatListNodeEntryId: ChatListItemNode]` - Cached nodes

### 6. ChatListNodeInteraction

**File**: `submodules/ChatListUI/Sources/Node/ChatListNode.swift` (lines 70-228)

Callback handler for all chat list interactions:

```swift
public final class ChatListNodeInteraction {
    let peerSelected: (EnginePeer, EnginePeer?, Int64?, ...) -> Void
    let deletePeer: (EnginePeer.Id, Bool) -> Void
    let setPeerMuted: (EnginePeer.Id, Bool) -> Void
    let setItemPinned: (EngineChatList.PinnedItem.Id, Bool) -> Void
    let togglePeerMarkedUnread: (EnginePeer.Id, Bool) -> Void
    let openStories: (ChatListNode.OpenStoriesSubject, ASDisplayNode?) -> Void
    // 30+ more callbacks for various actions
}
```

## Data Flow

### Loading Chats

**File**: `submodules/ChatListUI/Sources/Node/ChatListNodeLocation.swift`

```swift
public func chatListViewForLocation(
    chatListLocation: ChatListControllerLocation,
    location: ChatListNodeLocation,
    account: Account,
    shouldLoadCanMessagePeer: Bool
) -> Signal<ChatListNodeViewUpdate, NoError>
```

**Fetching Strategy**:
1. **Initial Load**: `account.viewTracker.tailChatListView()` fetches first 100 chats
2. **Pagination**: `aroundChatListView()` for scroll-based loading
3. **Filtering**: `ChatListFilterPredicate` applied for folders

### Entry Types

**File**: `submodules/ChatListUI/Sources/Node/ChatListNodeEntries.swift`

```swift
enum ChatListNodeEntry: Comparable {
    case PeerEntry(PeerEntryData)        // Individual chat
    case GroupReferenceEntry(...)        // Archived chats group
    case HoleEntry(...)                  // Pagination placeholder
    case AdditionalCategory(...)         // Categories like contacts
}
```

**PeerEntryData Fields**:
```swift
struct PeerEntryData {
    let index: EngineChatList.Item.Index   // Sort position
    let presentationData: ChatListPresentationData
    let messages: [EngineMessage]          // Recent messages
    let readState: EnginePeerReadCounters? // Unread state
    let peer: EngineRenderedPeer           // Peer info
    let inputActivities: [(EnginePeer, PeerInputActivity)]? // Typing
    let forumTopicData: EngineChatList.ForumTopicData?
    let storyState: ChatListNodeState.StoryState?
}
```

### Entry Conversion

Entries are converted to list view items via:
- `mappedInsertEntries()` - Converts Postbox entries to items
- `mappedUpdateEntries()` - Handles updates to existing entries

## Postbox Data Layer

**File**: `submodules/Postbox/Sources/ChatListView.swift`

The Postbox database provides `ChatListView` structures:

```swift
struct ChatListEntry {
    let index: ChatListIndex           // Sort position
    let messages: [Message]            // Recent messages
    let renderedPeer: RenderedPeer     // Peer data
    let readState: ChatListViewReadState?
    let presence: PeerPresence?        // Online status
    let forumTopicData: ChatListForumTopicData?
    let storyStats: PeerStoryStats?
}
```

## Chat Item Rendering

**File**: `submodules/ChatListUI/Sources/Node/ChatListItem.swift`

Individual chat rows display:
- Avatar with online indicator
- Peer name with emoji status
- Message preview text
- Timestamp
- Unread badge / mention badge
- Muted / pinned indicators
- Typing animation
- Story ring

**Content Types**:
```swift
public enum ChatListItemContent {
    case loading
    case peer(PeerData)              // Regular chat
    case groupReference(GroupReferenceData)  // Archived group
}
```

## Filters (Folders)

Chat folders are implemented via:
1. `ChatListFilterTabEntry` - Tab bar entry for each folder
2. `ChatListFilterPredicate` - Filtering logic
3. `ChatListContainerItemNode` - Per-filter list container

**Filter Predicate** (`ChatListNodeLocation.swift` lines 38-120):
```swift
public func chatListFilterPredicate(
    filter: ChatListFilterData,
    accountPeerId: EnginePeer.Id
) -> ChatListFilterPredicate
```

Filters by:
- Include/exclude specific peers
- Read state (unread only)
- Muted status
- Categories (contacts, bots, groups, channels)

## Key Patterns

### Reactive Data Binding
All data flows through `Signal<T, NoError>` from SwiftSignal. Updates propagate automatically.

### AsyncDisplayKit Rendering
UI nodes extend `ASDisplayNode` for async layout and rendering off the main thread.

### MergeLists Diffing
Efficient list updates via `mergeListsStableWithUpdates()` that computes minimal diffs.

### Disposables
Resource cleanup via `MetaDisposable` and `DisposableSet` patterns.

### ViewTracker
`account.viewTracker` efficiently tracks database views and emits updates.

## Common Modifications

### Adding a new chat list action

1. Add callback to `ChatListNodeInteraction` in `ChatListNode.swift`
2. Wire up in `ChatListControllerImpl` where interaction is created
3. Implement action handler in controller

### Modifying chat item appearance

1. Edit `ChatListItem.swift` for layout changes
2. Modify `PeerData` in `ChatListItemContent` for new data
3. Update `ChatListNodeEntries.swift` if new entry data needed

### Adding a new filter type

1. Add filter case to `ChatListFilterData`
2. Implement predicate logic in `chatListFilterPredicate()`
3. Add tab entry in `ChatListFilterTabEntry`

## Performance Considerations

- Chat list can contain thousands of items
- AsyncDisplayKit enables 60fps scrolling
- Node caching in `itemNodes` dictionary
- Incremental updates via MergeLists
- ViewTracker minimizes database queries
- Preloading controlled by `fillPreloadItems`
