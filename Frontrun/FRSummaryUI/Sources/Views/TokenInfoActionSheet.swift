import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import AccountContext

// MARK: - TokenInfoActionSheetItem

final class TokenInfoActionSheetItem: ActionSheetItem {
    let name: String
    let symbol: String
    let price: String
    let change: String
    let isUp: Bool
    let marketCap: String?
    let volume: String?
    let imageUrl: String?
    let context: AccountContext
    let theme: PresentationTheme

    init(name: String, symbol: String, price: String, change: String, isUp: Bool, marketCap: String?, volume: String?, imageUrl: String?, context: AccountContext, theme: PresentationTheme) {
        self.name = name
        self.symbol = symbol
        self.price = price
        self.change = change
        self.isUp = isUp
        self.marketCap = marketCap
        self.volume = volume
        self.imageUrl = imageUrl
        self.context = context
        self.theme = theme
    }

    func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return TokenInfoActionSheetItemNode(item: self, theme: theme)
    }

    func updateNode(_ node: ActionSheetItemNode) {
    }
}

// MARK: - TokenInfoActionSheetItemNode

final class TokenInfoActionSheetItemNode: ActionSheetItemNode {
    private let item: TokenInfoActionSheetItem

    private let imageNode: ASImageNode
    private let nameLabel: ImmediateTextNode
    private let priceLabel: ImmediateTextNode
    private let changeLabel: ImmediateTextNode
    private let statsLabel: ImmediateTextNode

    private var imageDisposable: Disposable?

    init(item: TokenInfoActionSheetItem, theme: ActionSheetControllerTheme) {
        self.item = item

        self.imageNode = ASImageNode()
        self.imageNode.contentMode = .scaleAspectFill
        self.imageNode.cornerRadius = 20
        self.imageNode.clipsToBounds = true
        self.imageNode.backgroundColor = theme.secondaryTextColor.withAlphaComponent(0.1)

        let placeholderImage = Self.generatePlaceholder(symbol: item.symbol, size: CGSize(width: 40, height: 40), theme: theme)
        self.imageNode.image = placeholderImage

        self.nameLabel = ImmediateTextNode()
        self.nameLabel.displaysAsynchronously = false
        self.nameLabel.maximumNumberOfLines = 1

        self.priceLabel = ImmediateTextNode()
        self.priceLabel.displaysAsynchronously = false
        self.priceLabel.maximumNumberOfLines = 1

        self.changeLabel = ImmediateTextNode()
        self.changeLabel.displaysAsynchronously = false
        self.changeLabel.maximumNumberOfLines = 1

        self.statsLabel = ImmediateTextNode()
        self.statsLabel.displaysAsynchronously = false
        self.statsLabel.maximumNumberOfLines = 1

        super.init(theme: theme)

        self.addSubnode(self.imageNode)
        self.addSubnode(self.nameLabel)
        self.addSubnode(self.priceLabel)
        self.addSubnode(self.changeLabel)
        self.addSubnode(self.statsLabel)

        self.nameLabel.attributedText = NSAttributedString(
            string: "\(item.name) ($\(item.symbol))",
            font: Font.semibold(16.0),
            textColor: theme.primaryTextColor
        )

        self.priceLabel.attributedText = NSAttributedString(
            string: item.price,
            font: Font.regular(15.0),
            textColor: theme.primaryTextColor
        )

        self.changeLabel.attributedText = NSAttributedString(
            string: "24h: \(item.change)",
            font: Font.medium(14.0),
            textColor: item.isUp ? UIColor.systemGreen : UIColor.systemRed
        )

        var statsText = ""
        if let mc = item.marketCap {
            statsText += "MCap: \(mc)"
        }
        if let vol = item.volume {
            if !statsText.isEmpty { statsText += " • " }
            statsText += "Vol: \(vol)"
        }

        if !statsText.isEmpty {
            self.statsLabel.attributedText = NSAttributedString(
                string: statsText,
                font: Font.regular(13.0),
                textColor: theme.secondaryTextColor
            )
        }

        if let imageUrl = item.imageUrl, URL(string: imageUrl) != nil {
            self.imageDisposable = (item.context.engine.resources.httpData(url: imageUrl)
            |> deliverOnMainQueue).startStrict(next: { [weak self] data in
                if let image = UIImage(data: data) {
                    self?.imageNode.image = image
                }
            })
        }
    }

    private static func generatePlaceholder(symbol: String, size: CGSize, theme: ActionSheetControllerTheme) -> UIImage {
        let firstChar = symbol.prefix(1).uppercased()

        let hash = abs(symbol.hashValue)
        let colors: [UIColor] = [
            UIColor(rgb: 0x5E97F6),
            UIColor(rgb: 0x9C27B0),
            UIColor(rgb: 0x00BCD4),
            UIColor(rgb: 0x4CAF50),
            UIColor(rgb: 0xFF9800),
            UIColor(rgb: 0xE91E63),
            UIColor(rgb: 0x009688),
            UIColor(rgb: 0x673AB7),
        ]
        let color = colors[hash % colors.count]

        return UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))

            let font = UIFont.systemFont(ofSize: size.width * 0.45, weight: .semibold)
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white
            ]

            let textSize = (firstChar as NSString).size(withAttributes: textAttributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            (firstChar as NSString).draw(in: textRect, withAttributes: textAttributes)
        }
    }

    deinit {
        self.imageDisposable?.dispose()
    }

    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let padding: CGFloat = 16.0
        let imageSize: CGFloat = 40.0
        let spacing: CGFloat = 4.0
        let textLeftOffset = padding + imageSize + 12.0
        let maxTextWidth = constrainedSize.width - textLeftOffset - padding

        let nameSize = self.nameLabel.updateLayout(CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude))
        let priceSize = self.priceLabel.updateLayout(CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude))
        let changeSize = self.changeLabel.updateLayout(CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude))
        let statsSize = self.statsLabel.updateLayout(CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude))

        var textHeight = nameSize.height + spacing + priceSize.height + spacing + changeSize.height
        if statsSize.width > 0 {
            textHeight += spacing + statsSize.height
        }

        let contentHeight = max(imageSize, textHeight)
        let size = CGSize(width: constrainedSize.width, height: padding + contentHeight + padding)

        let imageY = (size.height - imageSize) / 2.0
        transition.updateFrame(node: self.imageNode, frame: CGRect(x: padding, y: imageY, width: imageSize, height: imageSize))

        var yOffset = padding

        transition.updateFrame(node: self.nameLabel, frame: CGRect(origin: CGPoint(x: textLeftOffset, y: yOffset), size: nameSize))
        yOffset += nameSize.height + spacing

        transition.updateFrame(node: self.priceLabel, frame: CGRect(origin: CGPoint(x: textLeftOffset, y: yOffset), size: priceSize))
        yOffset += priceSize.height + spacing

        transition.updateFrame(node: self.changeLabel, frame: CGRect(origin: CGPoint(x: textLeftOffset, y: yOffset), size: changeSize))
        yOffset += changeSize.height + spacing

        if statsSize.width > 0 {
            transition.updateFrame(node: self.statsLabel, frame: CGRect(origin: CGPoint(x: textLeftOffset, y: yOffset), size: statsSize))
        }

        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
}
