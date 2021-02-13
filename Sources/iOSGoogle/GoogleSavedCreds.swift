//
//  GoogleSavedCreds.swift
//  
//
//  Created by Christopher G Prince on 2/8/21.
//

import Foundation
import iOSSignIn
import GSignIn
import iOSShared

public class GoogleSavedCreds: GenericCredentialsCodable, Equatable {
    public var userId:String
    public var username:String?
    
    // Unused. Just for compliance to `GenericCredentialsCodable`. See `GoogleCredentials`.
    public var uiDisplayName:String?
    
    public var accessToken: String
    public var refreshToken: String
    public var email:String?
    public var serverAuthCode: String?
    
    var _googleUser:Data?
    var googleUser:GIDGoogleUser? {
        return Self.googleUserFrom(data: _googleUser)
    }
    
    private static func googleUserFrom(data:Data?) -> GIDGoogleUser? {
        guard let data = data else {
            return nil
        }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: GIDGoogleUser.self, from: data)
        } catch let error {
            logger.error("\(error)")
            return nil
        }
    }
    
    private static func dataFromGoogleUser(_ googleUser: GIDGoogleUser?) -> Data? {
        do {
            return try NSKeyedArchiver.archivedData(withRootObject: googleUser as Any, requiringSecureCoding: true)
        } catch let error {
            logger.error("\(error)")
            return nil
        }
    }
    
    // The `GIDGoogleUser` is needed to do the credentials referesh in `GoogleCredentials`.
    public init(accessToken: String, refreshToken: String, userId:String, username:String?, email:String?, serverAuthCode: String?, googleUser:GIDGoogleUser?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userId = userId
        self.username = username
        self.email = email
        self.serverAuthCode = serverAuthCode
        self._googleUser = Self.dataFromGoogleUser(googleUser)
    }
    
    // Update tokens
    init(creds: GoogleSavedCreds, accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userId = creds.userId
        self.username = creds.username
        self.email = creds.email
        self.serverAuthCode = creds.serverAuthCode
        self._googleUser = creds._googleUser
    }
    
    public static func == (lhs: GoogleSavedCreds, rhs: GoogleSavedCreds) -> Bool {
        return lhs.accessToken == rhs.accessToken &&
            lhs.refreshToken == rhs.refreshToken &&
            lhs.userId == rhs.userId &&
            lhs.username == rhs.username &&
            lhs.email == rhs.email &&
            lhs.serverAuthCode == rhs.serverAuthCode &&
            lhs._googleUser == rhs._googleUser
    }
}
