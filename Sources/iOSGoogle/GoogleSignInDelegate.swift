
import Foundation
import UIKit

public protocol GoogleSignInDelegate: AnyObject {
    // Need the current view controller for Google Sign In, or it crashes!!
    func getCurrentViewController() -> UIViewController?
}
