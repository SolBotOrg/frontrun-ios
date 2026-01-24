import Foundation
import UIKit
import Display
import AccountContext
import ComponentFlow
import ViewControllerComponent
import TelegramPresentationData
import Postbox

public final class FRSummarySheetScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let peerId: PeerId

    public var parentController: () -> ViewController? = { return nil }

    public init(context: AccountContext, peerId: PeerId) {
        self.context = context
        self.peerId = peerId

        super.init(
            context: context,
            component: FRSummarySheetScreenComponent(context: context, peerId: peerId),
            navigationBarAppearance: .none,
            theme: .default
        )

        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.disablesInteractiveModalDismiss = false
    }
}
