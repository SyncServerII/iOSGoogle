
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
                let string = String(data: data, encoding: .utf8)
                logger.debug("savedCreds: \(String(describing: string))")
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
        
        //logger.debug("GIDSignIn.sharedInstance()?.hasPreviousSignIn(): \(String(describing: GIDSignIn.sharedInstance()?.hasPreviousSignIn()))")
        
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
        return GIDSignIn.sharedInstance().handle(url)
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
    
    public func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!)
    {
        logger.error("\(String(describing: error))")
    }
    
    func setupAndSaveCreds(user: GIDGoogleUser?) -> GenericCredentials? {
        guard let user = user else {
            signUserOut(message: "signUserOut: No user!")
            return nil
        }
        
        guard let accessToken = user.authentication.accessToken else {
            signUserOut(message: "No access token")
            return nil
        }
        
        guard let refreshToken = user.authentication.refreshToken else {
            signUserOut(message: "No refresh token")
            return nil
        }
        
        guard let userID = user.userID else {
            signUserOut(message: "No userID")
            return nil
        }
        
        logger.debug("user.serverAuthCode: \(String(describing: user.serverAuthCode))")
        
        Self.savedCreds = GoogleSavedCreds(accessToken: accessToken, refreshToken: refreshToken, userId: userID, username: user.profile.name, email: user.profile.email, serverAuthCode: user.serverAuthCode, googleUser: user)
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
    }
    
    func signUserOut(_ button: GoogleSignInOutButton) {
        signUserOut()
    }
    
    func getCurrentViewController(_ button: GoogleSignInOutButton) -> UIViewController? {
        return signInDelegate?.getCurrentViewController()
    }
}
