
import Foundation
import iOSSignIn
import GSignIn
import ServerShared
import iOSShared

public class GoogleCredentials : GenericCredentials, CustomDebugStringConvertible {
    enum GoogleCredentialsError: Swift.Error {
        case noGoogleUser
        case credentialsRefreshError
    }
    
    public var userId:String = ""
    public var username:String? = ""
    
    public var uiDisplayName:String? {
        return email ?? username
    }
    
    public var email:String?
    
    var currentlyRefreshing = false
    var googleUser:GIDGoogleUser?

    var accessToken: String?
    
    // Used on the server to obtain a refresh code and an access token. The refresh token obtained on signin in the app can't be transferred to the server and used there.
    var serverAuthCode: String?
    
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
    
    open func refreshCredentials(completion: @escaping (Swift.Error?) ->()) {
        // See also this on refreshing of idTokens: http://stackoverflow.com/questions/33279485/how-to-refresh-authentication-idtoken-with-gidsignin-or-gidauthentication
        
        guard self.googleUser != nil
        else {
            completion(GoogleCredentialsError.noGoogleUser)
            return
        }
        
        Synchronized().sync() {
            if self.currentlyRefreshing {
                return
            }
            
            self.currentlyRefreshing = true
        }
        
        logger.debug("refreshCredentials")
        
        self.googleUser!.authentication.refreshTokens() { auth, error in
            self.currentlyRefreshing = false
            
            if error == nil {
                logger.debug("refreshCredentials: Success")
                self.accessToken = auth?.accessToken
                completion(nil)
            }
            else {
                logger.error("Error refreshing tokens: \(error!)")
                // 10/22/17; It doesn't seem reasonable to sign the user out at this point, after a single attempt at refreshing credentials. If we have no network connection-- Why sign the user out then?
                completion(GoogleCredentialsError.credentialsRefreshError)
            }
        }
    }
}
