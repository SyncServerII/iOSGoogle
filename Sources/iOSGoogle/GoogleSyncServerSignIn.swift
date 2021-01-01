
//
//  GoogleSignIn.swift
//  SyncServer
//
//  Created by Christopher Prince on 11/26/15.
//  Copyright © 2015 Christopher Prince. All rights reserved.
//

import Foundation
import ServerShared
import GSignIn
import iOSSignIn
import iOSShared

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
    
    public init(serverClientId:String, appClientId:String, signInDelegate:GoogleSignInDelegate?) {
        self.signInDelegate = signInDelegate
        self.serverClientId = serverClientId
        self.appClientId = appClientId
        super.init()
        signInOutButton.delegate = self
    }
    
    public var userType:UserType = .owning
    public var cloudStorageType: CloudStorageType? = .Google
    
    public func appLaunchSetup(userSignedIn: Bool, withLaunchOptions options:[UIApplication.LaunchOptionsKey : Any]?) {
    
        stickySignIn = userSignedIn
    
        // 7/30/17; Seems this is not needed any more using the GoogleSignIn Cocoapod; see https://stackoverflow.com/questions/44398121/google-signin-cocoapod-deprecated
        /*
        var configureError: NSError?
        GGLContext.sharedInstance().configureWithError(&configureError)
        assert(configureError == nil, "Error configuring Google services: \(String(describing: configureError))")
        */

        GIDSignIn.sharedInstance().delegate = self
        
        // Seem to need the following for accessing the serverAuthCode. Plus, you seem to need a "fresh" sign-in (not a silent sign-in). PLUS: serverAuthCode is *only* available when you don't do the silent sign in.
        // https://developers.google.com/identity/sign-in/ios/offline-access?hl=en
        GIDSignIn.sharedInstance().serverClientID = self.serverClientId
        GIDSignIn.sharedInstance().clientID = self.appClientId

        // 8/20/16; I had a difficult to resolve issue relating to scopes. I had re-created a file used by SharedNotes, outside of SharedNotes, and that application was no longer able to access the file. See https://developers.google.com/drive/v2/web/scopes The fix to this issue was in two parts: 1) to change the scope to access all of the users files, and to 2) force updating of the access_token/refresh_token on the server. (I did this later part by hand-- it would be good to be able to force this automatically).
        
        // "Per-file access to files created or opened by the app"
        // GIDSignIn.sharedInstance().scopes.append("https://www.googleapis.com/auth/drive.file")
        // I've also considered the Application Data Folder scope, but users cannot access the files in that-- which is against the goals in SyncServer.
        
        // "Full, permissive scope to access all of a user's files."
        GIDSignIn.sharedInstance().scopes.append("https://www.googleapis.com/auth/drive")
        
        // 12/20/15; Trying to resolve my user sign in issue
        // It looks like, at least for Google Drive, calling this method is sufficient for dealing with rcStaleUserSecurityInfo. I.e., having the IdToken for Google become stale. (Note that while it deals with the IdToken becoming stale, dealing with an expired access token on the server is a different matter-- and the server seems to need to refresh the access token from the refresh token to deal with this independently).
        // See also this on refreshing of idTokens: http://stackoverflow.com/questions/33279485/how-to-refresh-authentication-idtoken-with-gidsignin-or-gidauthentication
        
        autoSignIn = userSignedIn
        
        if userSignedIn {
            // I'm not sure if this is ever going to happen-- that we have non-nil creds on launch.
            if let creds = credentials {
                delegate?.haveCredentials(self, credentials: creds)
            }
            
            GIDSignIn.sharedInstance().restorePreviousSignIn()
        }
        else {
            // I'm doing this to force a user-signout, so that I get the serverAuthCode. Seems I only get this with the user explicitly signed out before hand.
            GIDSignIn.sharedInstance().signOut()
        }
    }
    
    public func networkChangedState(networkIsOnline: Bool) {
        if stickySignIn && networkIsOnline && credentials == nil {
            autoSignIn = true
            logger.info("GoogleSignIn: Trying autoSignIn...")
            GIDSignIn.sharedInstance().restorePreviousSignIn()
        }
    }

    public func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance().handle(url)
    }
    
    public var userIsSignedIn: Bool {
        return stickySignIn
    }
    
    public var credentials:GenericCredentials? {
        // hasAuthInKeychain can be true, and yet GIDSignIn.sharedInstance().currentUser can be nil. Seems to make more sense to test GIDSignIn.sharedInstance().currentUser.
        if GIDSignIn.sharedInstance().currentUser == nil {
            return nil
        }
        else {
            return signedInUser(forUser: GIDSignIn.sharedInstance().currentUser)
        }
    }
    
    func signedInUser(forUser user:GIDGoogleUser) -> GoogleCredentials {
        let name = user.profile.name
        let email = user.profile.email

        let creds = GoogleCredentials()
        creds.userId = user.userID
        creds.email = email
        creds.username = name
        creds.accessToken = user.authentication.accessToken
        logger.debug("user.serverAuthCode: \(String(describing: user.serverAuthCode))")
        creds.serverAuthCode = user.serverAuthCode
        creds.googleUser = user
        
        return creds
    }
    
    public func signInButton(configuration: [String : Any]?) -> UIView? {
        return signInOutButton
    }
}

// MARK: UserSignIn methods.
extension GoogleSyncServerSignIn {
    @objc public func signUserOut() {
        stickySignIn = false
        GIDSignIn.sharedInstance().signOut()
        signInOutButton.buttonShowing = .signIn
        delegate?.userIsSignedOut(self)
    }
}

extension GoogleSyncServerSignIn : GIDSignInDelegate {
    public func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!)
    {
        DispatchQueue.main.async {
            self.didSignInHelper(user: user, error: error)
        }
    }
    
    func didSignInHelper(user: GIDGoogleUser?, error: Error?) {
        if let error = error {
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
                logger.debug("GIDSignIn: Got a -4 error code")
            }
            
            if !haveAuthToken || !autoSignIn {
                // Must be an explicit request by user.
                signUserOut()
                logger.debug("signUserOut: No auth token or not auto sign in")
                return
            }
            
            guard let user = user else {
                signUserOut()
                logger.debug("signUserOut: No user!")
                return
            }
            
            let creds = signedInUser(forUser: user)
            delegate?.haveCredentials(self, credentials: creds)
            signInOutButton.buttonShowing = .signOut
            delegate?.signInCompleted(self, autoSignIn: false)
        
            return
        }
        
        guard let user = user else {
            signUserOut()
            logger.debug("signUserOut: No error and no user!")
            return
        }
        
        // 11/14/18; I'm getting two calls to this delegate method, in rapid succession, on a sign in, with error == nil. And it's messing things up. Trying to avoid that.
        guard self.signInOutButton.buttonShowing != .signOut else {
            logger.debug("GoogleSyncServerSignIn: avoiding 2x sign in issue.")
            return
        }
    
        self.signInOutButton.buttonShowing = .signOut
        let creds = signedInUser(forUser: user)
        delegate?.haveCredentials(self, credentials: creds)
        stickySignIn = true
        delegate?.signInCompleted(self, autoSignIn: false)
        autoSignIn = false
    }
    
    public func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!)
    {
    }
}

extension GoogleSyncServerSignIn: GoogleSignInOutButtonDelegate {
    func signInStarted(_ button: GoogleSignInOutButton) {
        delegate?.signInStarted(self)
    }
    
    func signUserOut(_ button: GoogleSignInOutButton) {
        signUserOut()
    }
    
    func getCurrentViewController(_ button: GoogleSignInOutButton) -> UIViewController? {
        return signInDelegate?.getCurrentViewController()
    }
}
