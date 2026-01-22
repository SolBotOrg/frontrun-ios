import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

// MARK: - Public Types

/// Represents an item in the searchable selection list
public struct SearchableSelectionItem: Equatable {
    public let id: String
    public let title: String
    public let subtitle: String?
    
    public init(id: String, title: String, subtitle: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
    
    public static func == (lhs: SearchableSelectionItem, rhs: SearchableSelectionItem) -> Bool {
        return lhs.id == rhs.id && lhs.title == rhs.title && lhs.subtitle == rhs.subtitle
    }
}

/// Configuration for the searchable selection screen
public struct SearchableSelectionConfiguration {
    public let title: String
    public let searchPlaceholder: String
    public let emptyResultsText: String
    public let showItemCount: Bool
    
    public init(
        title: String = "Select Item",
        searchPlaceholder: String = "Search...",
        emptyResultsText: String = "No results found",
        showItemCount: Bool = true
    ) {
        self.title = title
        self.searchPlaceholder = searchPlaceholder
        self.emptyResultsText = emptyResultsText
        self.showItemCount = showItemCount
    }
}

// MARK: - Private Types

private final class SearchableSelectionControllerArguments {
    let selectItem: (SearchableSelectionItem) -> Void
    let updateSearchQuery: (String) -> Void
    
    init(
        selectItem: @escaping (SearchableSelectionItem) -> Void,
        updateSearchQuery: @escaping (String) -> Void
    ) {
        self.selectItem = selectItem
        self.updateSearchQuery = updateSearchQuery
    }
}

private enum SearchableSelectionSection: Int32 {
    case search
    case items
}

private enum SearchableSelectionEntry: ItemListNodeEntry {
    case searchField(PresentationTheme, String, String)
    case item(Int32, PresentationTheme, SearchableSelectionItem, Bool)
    case emptyState(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .searchField:
            return SearchableSelectionSection.search.rawValue
        case .item, .emptyState:
            return SearchableSelectionSection.items.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .searchField:
            return -1
        case let .item(index, _, _, _):
            return index
        case .emptyState:
            return Int32.max
        }
    }
    
    static func ==(lhs: SearchableSelectionEntry, rhs: SearchableSelectionEntry) -> Bool {
        switch lhs {
        case let .searchField(lhsTheme, lhsText, lhsPlaceholder):
            if case let .searchField(rhsTheme, rhsText, rhsPlaceholder) = rhs,
               lhsTheme === rhsTheme,
               lhsText == rhsText,
               lhsPlaceholder == rhsPlaceholder {
                return true
            }
            return false
        case let .item(lhsIndex, lhsTheme, lhsItem, lhsSelected):
            if case let .item(rhsIndex, rhsTheme, rhsItem, rhsSelected) = rhs,
               lhsIndex == rhsIndex,
               lhsTheme === rhsTheme,
               lhsItem == rhsItem,
               lhsSelected == rhsSelected {
                return true
            }
            return false
        case let .emptyState(lhsTheme, lhsText):
            if case let .emptyState(rhsTheme, rhsText) = rhs,
               lhsTheme === rhsTheme,
               lhsText == rhsText {
                return true
            }
            return false
        }
    }
    
    static func <(lhs: SearchableSelectionEntry, rhs: SearchableSelectionEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SearchableSelectionControllerArguments
        switch self {
        case let .searchField(_, text, placeholder):
            return ItemListSingleLineInputItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: NSAttributedString(string: ""),
                text: text,
                placeholder: placeholder,
                type: .regular(capitalization: false, autocorrection: false),
                alignment: .default,
                clearType: .onFocus,
                sectionId: self.section,
                textUpdated: { text in
                    arguments.updateSearchQuery(text)
                },
                action: {}
            )
        case let .item(_, _, item, selected):
            if let subtitle = item.subtitle {
                return ItemListCheckboxItem(
                    presentationData: presentationData,
                    systemStyle: .glass,
                    title: item.title,
                    subtitle: subtitle,
                    style: .left,
                    checked: selected,
                    zeroSeparatorInsets: false,
                    sectionId: self.section,
                    action: {
                        arguments.selectItem(item)
                    }
                )
            } else {
                return ItemListCheckboxItem(
                    presentationData: presentationData,
                    systemStyle: .glass,
                    title: item.title,
                    style: .left,
                    checked: selected,
                    zeroSeparatorInsets: false,
                    sectionId: self.section,
                    action: {
                        arguments.selectItem(item)
                    }
                )
            }
        case let .emptyState(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct SearchableSelectionControllerState: Equatable {
    var searchQuery: String = ""
}

private func searchableSelectionControllerEntries(
    theme: PresentationTheme,
    items: [SearchableSelectionItem],
    selectedId: String?,
    searchQuery: String,
    configuration: SearchableSelectionConfiguration
) -> [SearchableSelectionEntry] {
    var entries: [SearchableSelectionEntry] = []
    
    // Search field
    entries.append(.searchField(theme, searchQuery, configuration.searchPlaceholder))
    
    // Filter items
    let filteredItems: [SearchableSelectionItem]
    if searchQuery.isEmpty {
        filteredItems = items
    } else {
        let query = searchQuery.lowercased()
        filteredItems = items.filter { item in
            item.id.lowercased().contains(query) ||
            item.title.lowercased().contains(query) ||
            (item.subtitle?.lowercased().contains(query) ?? false)
        }
    }
    
    if filteredItems.isEmpty {
        entries.append(.emptyState(theme, configuration.emptyResultsText))
    } else {
        var index: Int32 = 0
        for item in filteredItems {
            let isSelected = item.id == selectedId
            entries.append(.item(index, theme, item, isSelected))
            index += 1
        }
    }
    
    return entries
}

// MARK: - Public API

/// Creates a searchable selection screen controller
/// - Parameters:
///   - context: The account context
///   - items: Array of items to display
///   - selectedId: Currently selected item ID (optional)
///   - configuration: Screen configuration
///   - completion: Called when an item is selected with the selected item's ID
/// - Returns: A view controller presenting the searchable list
public func searchableSelectionScreen(
    context: AccountContext,
    items: [SearchableSelectionItem],
    selectedId: String? = nil,
    configuration: SearchableSelectionConfiguration = SearchableSelectionConfiguration(),
    completion: @escaping (String) -> Void
) -> ViewController {
    let statePromise = ValuePromise(SearchableSelectionControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: SearchableSelectionControllerState())
    let updateState: ((SearchableSelectionControllerState) -> SearchableSelectionControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    
    let arguments = SearchableSelectionControllerArguments(
        selectItem: { item in
            completion(item.id)
            dismissImpl?()
        },
        updateSearchQuery: { text in
            updateState { state in
                var state = state
                state.searchQuery = text
                return state
            }
        }
    )
    
    let signal = combineLatest(
        queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries = searchableSelectionControllerEntries(
            theme: presentationData.theme,
            items: items,
            selectedId: selectedId,
            searchQuery: state.searchQuery,
            configuration: configuration
        )
        
        let title: String
        if configuration.showItemCount && items.count > 0 {
            title = "\(configuration.title) (\(items.count))"
        } else {
            title = configuration.title
        }
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(title),
            leftNavigationButton: nil,
            rightNavigationButton: ItemListNavigationButton(
                content: .text(presentationData.strings.Common_Done),
                style: .bold,
                enabled: true,
                action: {
                    dismissImpl?()
                }
            ),
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: false
        )
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    controller.alwaysSynchronous = true
    
    dismissImpl = { [weak controller] in
        controller?.dismiss(animated: true, completion: nil)
    }
    
    return controller
}
