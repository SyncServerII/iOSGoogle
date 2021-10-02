
//
//  GoogleSignIn.swift
//  SyncServer
//
//  Created by Christopher Prince on 11/26/15.
//  Copyright © 2015 Christopher Prince. All rights reserved.
//

import Foundation
import ServerShared
import GoogleSignIn
import iOSSignIn
import iOSShared
import PersistentValue

// Discussion of using Google Sign In from sharing extension:
// https://stackoverflow.com/questions/39139160
// https://stackoverflow.com/questions/27082068
// https://stackoverflow.com/questions/39139160

// See https://developers.google.com/identity/sign-in/ios/sign-in
public class GoogleSyncServerSignIn : NSObject, GenericSignIn {
    public var signInName: String = "Google"
    
    fileprivate var stickySignIn = false

    fileprivate let serverClientId:String!
    fileprivate let appClientId:String!
    
    fileprivate let signInOutButton = GoogleSignInOutButton()
    
    weak public var delegate:GenericSignInDelegate?    
    
    fileprivate var autoSignIn = true
    weak var signInDelegate:GoogleSignInDelegate?
    
    static private let credentialsData = try! PersistentValue<Data>(name: "GoogleSyncServerSignIn.data", storage: .keyChain)
    
    public init(serverClientId:String, appClientId:String, signInDelegate:GoogleSignInDelegate) {
        self.signInDelegate = signInDelegate
        self.serverClientId = serverClientId
        self.appClientId = appClientId
        super.init()
        signInOutButton.delegate = self
    }
    
    static var savedCreds:GoogleSavedCreds? {
        set {
            let data = try? newValue?.toData()
#if DEBUG
            if let data = data {
                if let string = String(data: data, encoding: .utf8) {
                    logger.debug("savedCreds: \(string)")
                }
            }
#endif
            Self.credentialsData.value = data
        }
        
        get {
            guard let data = Self.credentialsData.value,
                let savedCreds = try? GoogleSavedCreds.fromData(data) else {
                return nil
            }
            return savedCreds
        }
    }
    
    public var credentials:GenericCredentials? {
        if let savedCreds = Self.savedCreds {
            return GoogleCredentials(savedCreds: savedCreds)
        }
        else {
            return nil
        }
    }
    
    public let userType:UserType = .owning
    public let cloudStorageType: CloudStorageType? = .Google
    
    // 8/20/16; I had a difficult to resolve issue relating to scopes. I had re-created a file used by SharedNotes, outside of SharedNotes, and that applicastion was no longer able to access the file. See https://developers.google.com/drive/v2/web/scopes The fix to this issue was in two parts: 1) to change the scope to access all of the users files, and to 2) force updating of the access_token/refresh_token on the server. (I did this later part by hand-- it would be good to be able to force this automatically).
    // "Per-file access to files created or opened by the app"
    // GIDSignIn.sharedInstance().scopes.append("https://www.googleapis.com/auth/drive.file")
    // I've also considered the Application Data Folder scope, but users cannot access the files in that-- which is against the goals in SyncServer.
    // "Full, permissive scope to access all of a user's files."
    var scopes: [String] {
        return ["https://www.googleapis.com/auth/drive"]
    }
    
    public func appLaunchSetup(userSignedIn: Bool, withLaunchOptions options:[UIApplication.LaunchOptionsKey : Any]?) {
    
        stickySignIn = userSignedIn

        // 12/20/15; Trying to resolve my user sign in issue
        // It looks like, at least for Google Drive, calling this method is sufficient for dealing with rcStaleUserSecurityInfo. I.e., having the IdToken for Google become stale. (Note that while it deals with the IdToken becoming stale, dealing with an expired access token on the server is a different matter-- and the server seems to need to refresh the access token from the refresh token to deal with this independently).
        // See also this on refreshing of idTokens: http://stackoverflow.com/questions/33279485/how-to-refresh-authentication-idtoken-with-gidsignin-or-gidauthentication
        
        autoSignIn = userSignedIn
                
        if userSignedIn {
            // I'm not sure if this is ever going to happen-- that we have non-nil creds on launch.
            if let creds = credentials {
                self.userSignedIn(autoSignIn: true, credentials: creds)
            }
            else {
                signUserOut(message: "No creds but userSignedIn == true")
            }
            
            // Going to rely on the creds I've saved.
            // GIDSignIn.sharedInstance().restorePreviousSignIn()
        }
        else {
            // I'm doing this to force a user-signout, so that I get the serverAuthCode. Seems I only get this with the user explicitly signed out before hand.
            signUserOut(message: "userSignedIn == false")
        }
    }
    
    func userSignedIn(autoSignIn: Bool, credentials: GenericCredentials) {
        self.autoSignIn = autoSignIn
        stickySignIn = true
        signInOutButton.buttonShowing = .signOut
        delegate?.haveCredentials(self, credentials: credentials)
        delegate?.signInCompleted(self, autoSignIn: autoSignIn)
    }
    
    public func networkChangedState(networkIsOnline: Bool) {
        /*
        if stickySignIn && networkIsOnline && credentials == nil {
            autoSignIn = true
            logger.info("GoogleSignIn: Trying autoSignIn...")
            GIDSignIn.sharedInstance().restorePreviousSignIn()
        }
        */
    }

    public func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    public var userIsSignedIn: Bool {
        return stickySignIn
    }

    public func signInButton(configuration: [String : Any]?) -> UIView? {
        return signInOutButton
    }
}

// MARK: UserSignIn methods.
extension GoogleSyncServerSignIn {
    @objc public func signUserOut() {
        signUserOut(message: nil)
    }
    
    @objc public func signUserOut(message: String? = nil) {
        logger.error("signUserOut: \(String(describing: message))")
        stickySignIn = false
        Self.savedCreds = nil
        GIDSignIn.sharedInstance.signOut()
        signInOutButton.buttonShowing = .signIn
        delegate?.userIsSignedOut(self)
    }
}

extension GoogleSyncServerSignIn {
    func setupAndSaveCreds(user: GIDGoogleUser?) -> GenericCredentials? {
        guard let user = user else {
            signUserOut(message: "signUserOut: No user!")
            return nil
        }
        
        let accessToken = user.authentication.accessToken
        let refreshToken = user.authentication.refreshToken
        
        guard let userID = user.userID else {
            signUserOut(message: "No userID")
            return nil
        }

        logger.debug("user.serverAuthCode: \(String(describing: user.serverAuthCode))")
        
        Self.savedCreds = GoogleSavedCreds(accessToken: accessToken, refreshToken: refreshToken, userId: userID, username: user.profile?.name, email: user.profile?.email, serverAuthCode: user.serverAuthCode, googleUser: user)
        guard let creds = credentials else {
            signUserOut(message: "No credentials")
            return nil
        }
        
        return creds
    }
}

extension GoogleSyncServerSignIn: GoogleSignInOutButtonDelegate {
    func signInStarted(_ button: GoogleSignInOutButton) {
        delegate?.signInStarted(self)
        let signInConfig = GIDConfiguration(clientID: self.appClientId, serverClientID: self.serverClientId)

        guard let viewController = signInDelegate?.getCurrentViewController() else {
            // Get a crash without a view controller.
            logger.error("Disabling Google Sign In because we have no view controller")
            signUserOut()
            return
        }
        
        GIDSignIn.sharedInstance.signIn(with: signInConfig, presenting: viewController) { [weak self] googleUser, error in
            guard let self = self else { return }
            
            if let error = error {
                self.errorHelper(user: googleUser, error: error)
                return
            }
            
            GIDSignIn.sharedInstance.addScopes(self.scopes, presenting: viewController) { googleUser, error in
                self.didSignInHelper(user: googleUser, error: error)
            }
        }
    }
    
    func signUserOut(_ button: GoogleSignInOutButton) {
        signUserOut()
    }
    
    func errorHelper(user: GIDGoogleUser?, error: Error) {
        logger.error("Error signing into Google: \(error)")
        
        // 10/22/17; Not always signing the user out here. It doesn't make sense if we get an error during launch. It doesn't make sense if we're attempting to do a creds refresh automatically when the app is running. It can make sense, however, if this is an explicit request by the user to sign-in.
        
        // See https://github.com/crspybits/SharedImages/issues/64
        /* From the delegate, error is actually an NSError:
                    - (void)signIn:(GIDSignIn *)signIn
            didSignInForUser:(GIDGoogleUser *)user
                   withError:(NSError *)error;
        */
        var haveAuthToken = true
        if let error = error as NSError?, error.code == -4 {
            haveAuthToken = false
            logger.warning("GIDSignIn: Got a -4 error code")
        }
        
        if !haveAuthToken || !autoSignIn {
            // Must be an explicit request by user.
            signUserOut(message: "No auth token or not auto sign in")
            return
        }
        
        guard let creds = setupAndSaveCreds(user: user) else {
            return
        }

        userSignedIn(autoSignIn: false, credentials: creds)
    }
    
    func didSignInHelper(user: GIDGoogleUser?, error: Error?) {
        if let error = error {
            errorHelper(user: user, error: error)
            return
        }
        
        // 11/14/18; I'm getting two calls to this delegate method, in rapid succession, on a sign in, with error == nil. And it's messing things up. Trying to avoid that.
        guard self.signInOutButton.buttonShowing != .signOut else {
            logger.warning("GoogleSyncServerSignIn: avoiding 2x sign in issue.")
            return
        }
        
        guard let creds = setupAndSaveCreds(user: user) else {
            return
        }

        userSignedIn(autoSignIn: false, credentials: creds)
    }
}
