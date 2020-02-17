import UIKit

final class FloatingButton: UIControl {
    
    private enum Constants {
        static let insets = UIEdgeInsets(top: 0, left: 52, bottom: 0, right: 52)
    }
    
    private let titleLabel = UILabel()
    private let contentView = UIView()
    private let imageView = UIImageView()
    private var imageWidthConstraint: NSLayoutConstraint?
    private var imageTrailingConstraint: NSLayoutConstraint?

    var minimumWidth: CGFloat = 169 {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }
    
    var textColor: UIColor = .white {
        didSet {
            titleLabel.textColor = textColor
        }
    }
    
    var text: String? {
        set {
            accessibilityLabel = newValue
            titleLabel.text = newValue
        }
        get {
            return titleLabel.text
        }
    }

    var image: UIImage? {
        didSet {
            if let image = image {
                imageWidthConstraint?.constant = image.size.width + 8
                imageTrailingConstraint?.constant = 8
            } else {
                imageWidthConstraint?.constant = 0
                imageTrailingConstraint?.constant = 0
            }
            imageView.image = image?.withRenderingMode(.alwaysTemplate)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
    
    override var isHighlighted: Bool {
        didSet {
            titleLabel.textColor = isHighlighted ? textColor.withAlphaComponent(0.5) : textColor
        }
    }
    
    override var isEnabled: Bool {
        didSet {
            titleLabel.alpha = isEnabled ? 1.0 : 0.2
        }
    }
    
    override var intrinsicContentSize: CGSize {
        let titleLabelSize = titleLabel.intrinsicContentSize
        let imageWidth = imageWidthConstraint?.constant ?? 0
        return CGSize(width: max(minimumWidth, titleLabelSize.width + Constants.insets.left + Constants.insets.right + imageWidth),
                          height: 52)
    }

    private func setup() {
        backgroundColor = Color.accent

        isAccessibilityElement = true
        accessibilityTraits = .button
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.isUserInteractionEnabled = false
        addSubview(contentView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = Font.bold(.hecto)
        titleLabel.textColor = Color.background
        titleLabel.textAlignment = .center
        titleLabel.setContentHuggingPriority( .defaultHigh, for: .horizontal)
        contentView.addSubview(titleLabel)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .center
        contentView.addSubview(imageView)
        
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 7)
        layer.shadowRadius = 21

        let imageWidthConstraint = imageView.widthAnchor.constraint(equalToConstant: 0)
        self.imageWidthConstraint = imageWidthConstraint
        
        let imageTrailingConstraint = titleLabel.leadingAnchor.constraint(equalTo: imageView.layoutMarginsGuide.trailingAnchor, constant: 0)
        self.imageTrailingConstraint = imageTrailingConstraint
        
        NSLayoutConstraint.activate([
            widthAnchor.constraint(greaterThanOrEqualToConstant: minimumWidth),
            imageWidthConstraint,
            contentView.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            imageTrailingConstraint,
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
            ])
    }
}
