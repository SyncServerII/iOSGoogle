
import Foundation
import iOSSignIn
import GSignIn
import ServerShared
import iOSShared

public class GoogleCredentials : GenericCredentials, CustomDebugStringConvertible {
    public var emailAddress: String! {
        return savedCreds.email
    }
    
    enum GoogleCredentialsError: Swift.Error {
        case noGoogleUser
        case credentialsRefreshError
    }
    
    var savedCreds:GoogleSavedCreds!

    public var userId:String {
        return savedCreds.userId
    }
    
    public var username:String? {
        return savedCreds.username
    }
    
    public var uiDisplayName:String? {
        return savedCreds.email ?? savedCreds.username
    }
    
    public var email:String? {
        return savedCreds.email
    }
    
    var googleUser:GIDGoogleUser? {
        return savedCreds.googleUser
    }

    var accessToken: String? {
        return savedCreds.accessToken
    }

    // Used on the server to obtain a refresh code and an access token. The refresh token obtained on signin in the app can't be transferred to the server and used there.
    var serverAuthCode: String? {
        return savedCreds.serverAuthCode
    }
    
    // Helper
    public init(savedCreds:GoogleSavedCreds) {
        self.savedCreds = savedCreds
    }

    public var httpRequestHeaders:[String:String] {
        var result = [String:String]()
        result[ServerConstants.XTokenTypeKey] = AuthTokenType.GoogleToken.rawValue
        result[ServerConstants.HTTPOAuth2AccessTokenKey] = self.accessToken
        result[ServerConstants.HTTPOAuth2AuthorizationCodeKey] = self.serverAuthCode
        return result
    }
    
    public var debugDescription: String {
        return "Google Access Token: \(String(describing: accessToken))"
    }
    
    enum RefreshCredentialsResult : Error {
        case noGoogleUser
    }
    
    func callCompletion(error:Error?, completion: @escaping (Error?) ->()) {
        DispatchQueue.main.async {
            completion(error)
        }
    }
    
    // So we don't lose reference below
    private var strongGoogleUser: GIDGoogleUser?
    
    open func refreshCredentials(completion: @escaping (Swift.Error?) ->()) {
        // See also this on refreshing of idTokens: http://stackoverflow.com/questions/33279485/how-to-refresh-authentication-idtoken-with-gidsignin-or-gidauthentication
        
        guard let googleUser = googleUser else {
            callCompletion(error: GoogleCredentialsError.noGoogleUser, completion: completion)
            return
        }
        
        self.strongGoogleUser = googleUser

        self.strongGoogleUser?.authentication.refreshTokens() { [weak self] auth, error in
            guard let self = self else {
                logger.error("Error: No self!")
                return
            }
                        
            if let error = error {
                logger.error("Error refreshing tokens: \(error)")
                // 10/22/17; It doesn't seem reasonable to sign the user out at this point, after a single attempt at refreshing credentials. If we have no network connection-- Why sign the user out then?
                self.callCompletion(error: error, completion: completion)
                return
            }
            
            guard let accessToken = auth?.accessToken else {
                logger.error("Error refreshing tokens: No access token")
                self.callCompletion(error: GoogleCredentialsError.credentialsRefreshError, completion: completion)
                return
            }
            
            logger.debug("accessToken: \(accessToken)")
            logger.debug("refreshToken: \(String(describing: auth?.refreshToken))")

            logger.notice("refreshCredentials: Success")
            self.savedCreds = GoogleSavedCreds(creds: self.savedCreds, accessToken: accessToken, refreshToken: self.savedCreds.refreshToken)
            GoogleSyncServerSignIn.savedCreds = self.savedCreds
            self.callCompletion(error: nil, completion: completion)
        }
    }
}
