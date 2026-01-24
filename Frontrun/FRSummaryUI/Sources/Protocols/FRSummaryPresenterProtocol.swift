import Foundation
import Postbox

public protocol FRSummaryPresenterProtocol: AnyObject {
    func dismissSummary(animated: Bool)
    func navigateToMessage(_ messageId: MessageId)
    func openSettings()
}
