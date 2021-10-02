
import Foundation
import UIKit
import GoogleSignIn
import iOSShared

protocol GoogleSignInOutButtonDelegate: AnyObject {
    func signInStarted(_ button: GoogleSignInOutButton)
    func signUserOut(_ button: GoogleSignInOutButton)
}

class GoogleSignInOutButton : UIView {
    // 12/18/20; Not getting the graphics assets to load for this from the XCFramework I've made. I'm not going to use this directly.
    let googleSignInButton = GIDSignInButton()
    
    // Subviews: `signInOutContentView` and `signInOutButton`
    let signInOutContainer = UIView()
    
    // Subviews: `googleIconView` and `signInOutLabel`.
    let signInOutContentView = UIView()
    
    let signInOutButton = UIButton(type: .system)
    
    let signInOutLabel = UILabel()
    var googleIconView:UIImageView!
    
    let signInText = "Sign in with Google"
    let signOutText = "Sign out"
    
    weak var delegate: GoogleSignInOutButtonDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: CGRect.zero)
        
        signInOutButton.addTarget(self, action: #selector(signInOutButtonAction), for: .touchUpInside)

        // Only adding this as a subview in case somehow Google's Sign In library depends on it actually being a subview.
        googleSignInButton.isHidden = true
        addSubview(googleSignInButton)
        
        addSubview(signInOutContainer)
        
        signInOutContainer.addSubview(signInOutContentView)
        signInOutContainer.addSubview(signInOutButton)

        let imageURL = Bundle.module.bundleURL.appendingPathComponent("Images/GoogleIcon-100x100.png")
        let iconImage = UIImage(contentsOfFile: imageURL.path)
        googleIconView = UIImageView(image: iconImage)
        googleIconView.contentMode = .scaleAspectFit
        signInOutContentView.addSubview(googleIconView)
        
        signInOutLabel.font = UIFont.boldSystemFont(ofSize: 15.0)
        signInOutContentView.addSubview(signInOutLabel)

        let layer = signInOutButton.layer
        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 0.5
        
        self.buttonShowing = .signIn
    }
    
    @objc func signInOutButtonAction() {
        logger.debug("signInOutButtonAction")
        switch buttonShowing {
        case .signIn:
            delegate?.signInStarted(self)
            googleSignInButton.sendActions(for: .touchUpInside)
        case .signOut:
            delegate?.signUserOut(self)
        }
    }
    
    func layout(with frame: CGRect) {
        signInOutContainer.frame.size = frame.size
        signInOutContentView.frame.size = frame.size
        signInOutButton.frame.size = frame.size
        
        let margin:CGFloat = 20
        var sizeReducedByMargins = frame.size
        sizeReducedByMargins.height -= margin
        sizeReducedByMargins.width -= margin
        signInOutContentView.frame.size = sizeReducedByMargins
        signInOutContentView.frame.origin = CGPoint(x: margin*0.5, y: margin*0.5)
        
        let iconSize = frame.size.height * 0.6
        googleIconView.frame.size = CGSize(width: iconSize, height: iconSize)
        googleIconView.frame.origin = CGPoint.zero
        googleIconView.centerVerticallyInSuperview()

        signInOutLabel.frame.origin.x = iconSize * 1.7
        signInOutLabel.centerVerticallyInSuperview()
        
        switch traitCollection.userInterfaceStyle {
        case .dark:
            signInOutContainer.backgroundColor = UIColor.darkGray
        case .light, .unspecified:
            signInOutContainer.backgroundColor = UIColor.white
        @unknown default:
            signInOutContainer.backgroundColor = UIColor.white
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        layout(with: frame)
    }
    
    enum State {
        case signIn
        case signOut
    }

    fileprivate var _state:State!
    var buttonShowing:State {
        get {
            return self._state
        }
        
        set {
            logger.debug("Change sign-in state: \(newValue)")
            
            DispatchQueue.main.async {
                self._state = newValue
                switch self._state! {
                case .signIn:
                    self.signInOutLabel.text = self.signInText
                
                case .signOut:
                    self.signInOutLabel.text = self.signOutText
                }
                
                self.signInOutLabel.sizeToFit()
                
                self.setNeedsDisplay()
            }
        }
    }
}

