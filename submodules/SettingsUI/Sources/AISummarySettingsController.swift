import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AIModule

private final class AISummarySettingsControllerArguments {
    let context: AccountContext
    let selectMessageCount: () -> Void
    let updatePrompt: (String) -> Void
    let resetPrompt: () -> Void

    init(
        context: AccountContext,
        selectMessageCount: @escaping () -> Void,
        updatePrompt: @escaping (String) -> Void,
        resetPrompt: @escaping () -> Void
    ) {
        self.context = context
        self.selectMessageCount = selectMessageCount
        self.updatePrompt = updatePrompt
        self.resetPrompt = resetPrompt
    }
}

private enum AISummarySettingsSection: Int32 {
    case messageCount
    case prompt
}

private enum AISummarySettingsEntry: ItemListNodeEntry {
    case messageCountHeader(PresentationTheme, String)
    case messageCount(PresentationTheme, String, SummaryMessageCount)
    case messageCountInfo(PresentationTheme, String)

    case promptHeader(PresentationTheme, String)
    case prompt(PresentationTheme, String, String)
    case promptInfo(PresentationTheme, String)
    case resetPrompt(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
        case .messageCountHeader, .messageCount, .messageCountInfo:
            return AISummarySettingsSection.messageCount.rawValue
        case .promptHeader, .prompt, .promptInfo, .resetPrompt:
            return AISummarySettingsSection.prompt.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .messageCountHeader:
            return 0
        case .messageCount:
            return 1
        case .messageCountInfo:
            return 2
        case .promptHeader:
            return 3
        case .prompt:
            return 4
        case .promptInfo:
            return 5
        case .resetPrompt:
            return 6
        }
    }

    static func <(lhs: AISummarySettingsEntry, rhs: AISummarySettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AISummarySettingsControllerArguments
        switch self {
        case let .messageCountHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .messageCount(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value.displayName, sectionId: self.section, style: .blocks, action: {
                arguments.selectMessageCount()
            })
        case let .messageCountInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .promptHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .prompt(_, placeholder, text):
            return ItemListMultilineInputItem(presentationData: presentationData, text: text, placeholder: placeholder, maxLength: nil, sectionId: self.section, style: .blocks, minimalHeight: 120.0, textUpdated: { value in
                arguments.updatePrompt(value)
            })
        case let .promptInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .resetPrompt(_, text):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.resetPrompt()
            })
        }
    }
}

private struct AISummarySettingsControllerState: Equatable {
    var configuration: AIConfiguration
}

private func aiSummarySettingsControllerEntries(
    presentationData: PresentationData,
    state: AISummarySettingsControllerState
) -> [AISummarySettingsEntry] {
    var entries: [AISummarySettingsEntry] = []

    // Message count section
    entries.append(.messageCountHeader(presentationData.theme, "MESSAGE COUNT"))
    entries.append(.messageCount(presentationData.theme, "Messages to Summarize", state.configuration.summaryMessageCount))
    entries.append(.messageCountInfo(presentationData.theme, "The number of recent messages to include when generating the summary."))

    // Prompt section
    entries.append(.promptHeader(presentationData.theme, "CUSTOM PROMPT"))
    entries.append(.prompt(presentationData.theme, "Enter custom prompt...", state.configuration.summaryPrompt))
    entries.append(.promptInfo(presentationData.theme, "Customize the AI prompt used for generating summaries. Leave empty to use the default prompt."))
    entries.append(.resetPrompt(presentationData.theme, "Reset to Default Prompt"))

    return entries
}

public func aiSummarySettingsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(AISummarySettingsControllerState(
        configuration: AIConfigurationStorage.shared.getConfiguration()
    ), ignoreRepeated: true)
    let stateValue = Atomic(value: AISummarySettingsControllerState(
        configuration: AIConfigurationStorage.shared.getConfiguration()
    ))
    let updateState: ((AISummarySettingsControllerState) -> AISummarySettingsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    var presentControllerImpl: ((ViewController, Any?) -> Void)?

    let arguments = AISummarySettingsControllerArguments(
        context: context,
        selectMessageCount: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = ActionSheetController(presentationData: presentationData)

            var items: [ActionSheetItem] = []
            for count in SummaryMessageCount.allCases {
                items.append(ActionSheetButtonItem(title: count.displayName, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    updateState { state in
                        var state = state
                        state.configuration.summaryMessageCount = count
                        AIConfigurationStorage.shared.saveConfiguration(state.configuration)
                        return state
                    }
                }))
            }

            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])

            presentControllerImpl?(actionSheet, nil)
        },
        updatePrompt: { value in
            updateState { state in
                var state = state
                state.configuration.summaryPrompt = value
                AIConfigurationStorage.shared.saveConfiguration(state.configuration)
                return state
            }
        },
        resetPrompt: {
            updateState { state in
                var state = state
                state.configuration.summaryPrompt = AIConfiguration.defaultSummaryPrompt
                AIConfigurationStorage.shared.saveConfiguration(state.configuration)
                return state
            }
        }
    )

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Summary Settings"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: aiSummarySettingsControllerEntries(presentationData: presentationData, state: state), style: .blocks)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)

    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }

    return controller
}
