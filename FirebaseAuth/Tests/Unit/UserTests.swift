// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License")
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import XCTest

@testable import FirebaseAuth
import FirebaseCore

class UserTests: RPCBaseTests {
  static let kFakeAPIKey = "FAKE_API_KEY"
  let kGoogleIDToken = "GOOGLE_ID_TOKEN"
  let kGoogleAccessToken = "GOOGLE_ACCESS_TOKEN"
  let kGoogleID = "GOOGLE_ID"
  let kGoogleEmail = "usergmail.com"
  let kGoogleDisplayName = "Google Doe"
  let kNewEmail = "newuser@company.com"
  let kNewPassword = "newpassword"
  let kNewDisplayName = "New User Doe"
  let kUserName = "User Doe"
  let kGoogleProfile = ["email": "usergmail.com", "given_name": "MyFirst", "family_name": "MyLast"]

  static var auth: Auth?

  override class func setUp() {
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.apiKey = kFakeAPIKey
    options.projectID = "myUserProjectID"
    FirebaseApp.configure(name: "test-UserTests", options: options)
    auth = Auth.auth(app: FirebaseApp.app(name: "test-UserTests")!)
  }

  /** @fn testUserPropertiesAndNSSecureCoding
      @brief Tests properties of the @c User instance before and after being
          serialized/deserialized.
   */
  func testUserPropertiesAndNSSecureCoding() throws {
    let kProviderUserInfoKey = "providerUserInfo"
    let kPhotoUrlKey = "photoUrl"
    let kProviderIDkey = "providerId"
    let kDisplayNameKey = "displayName"
    let kFederatedIDKey = "federatedId"
    let kEmailKey = "email"
    let kPasswordHashKey = "passwordHash"
    let kTestPasswordHash = "testPasswordHash"
    let kEmailVerifiedKey = "emailVerified"
    let kLocalIDKey = "localId"
    let kGoogleID = "GOOGLE_ID"
    let kGoogleDisplayName = "Google Doe"
    let kGoogleEmail = "user@gmail.com"
    let kGooglePhotoURL = "https://googleusercontents.com/user/profile"
    let kFacebookID = "FACEBOOK_ID"
    let kFacebookEmail = "user@facebook.com"
    let kPhoneNumber = "555-1234"
    let kUserArchiverKey = "userArchiverKey"
    let kEnrollmentID = "fakeEnrollment"

    var providerUserInfos = [[
      kProviderIDkey: EmailAuthProvider.id,
      kFederatedIDKey: kEmail,
      kEmailKey: kEmail,
    ],
    [
      kProviderIDkey: GoogleAuthProvider.id,
      kDisplayNameKey: kGoogleDisplayName,
      kPhotoUrlKey: kGooglePhotoURL,
      kFederatedIDKey: kGoogleID,
      kEmailKey: kGoogleEmail,
    ],
    [
      kProviderIDkey: FacebookAuthProvider.id,
      kFederatedIDKey: kFacebookID,
      kEmailKey: kFacebookEmail,
    ]]

    #if os(iOS)
      providerUserInfos.append([
        kProviderIDkey: PhoneAuthProvider.id,
        kFederatedIDKey: kPhoneNumber,
        "phoneNumber": kPhoneNumber,
      ])
    #endif

    rpcIssuer?.fakeGetAccountProviderJSON = [[
      kProviderUserInfoKey: providerUserInfos,
      kLocalIDKey: kLocalID,
      kDisplayNameKey: kDisplayName,
      kEmailKey: kEmail,
      kPhotoUrlKey: kTestPhotoURL,
      kEmailVerifiedKey: true,
      kPasswordHashKey: kTestPasswordHash,
      "createdAt": String(Int(kCreationDateTimeIntervalInSeconds) * 1000), // to nanoseconds
      "lastLoginAt": String(Int(kLastSignInDateTimeIntervalInSeconds) * 1000),
    ]]

    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        XCTAssertEqual(user.providerID, "Firebase")
        XCTAssertEqual(user.uid, self.kLocalID)
        XCTAssertEqual(user.displayName, self.kDisplayName)
        XCTAssertEqual(user.photoURL, URL(string: self.kTestPhotoURL))
        XCTAssertEqual(user.email, self.kEmail)
        XCTAssertEqual(user.metadata.creationDate, Date(timeIntervalSince1970:
          self.kCreationDateTimeIntervalInSeconds))
        XCTAssertEqual(user.metadata.lastSignInDate,
                       Date(timeIntervalSince1970: self.kLastSignInDateTimeIntervalInSeconds))

        // Verify FIRUser properties besides providerData contents.
        XCTAssertFalse(user.isAnonymous)
        XCTAssertTrue(user.isEmailVerified)
        XCTAssertEqual(user.refreshToken, self.kRefreshToken)
        XCTAssertEqual(user.providerData.count, providerUserInfos.count)

        let providerMap = user.providerData.reduce(into: [String: UserInfo]()) {
          $0[$1.providerID] = $1
        }

        // Verify FIRUserInfo properties from email/password.
        let passwordUserInfo = try XCTUnwrap(providerMap[EmailAuthProvider.id])
        XCTAssertEqual(passwordUserInfo.uid, self.kEmail)
        XCTAssertNil(passwordUserInfo.displayName)
        XCTAssertNil(passwordUserInfo.photoURL)
        XCTAssertEqual(passwordUserInfo.email, self.kEmail)

        // Verify FIRUserInfo properties from the Google auth provider.
        let googleUserInfo = try XCTUnwrap(providerMap[GoogleAuthProvider.id])
        XCTAssertEqual(googleUserInfo.uid, kGoogleID)
        XCTAssertEqual(googleUserInfo.displayName, kGoogleDisplayName)
        XCTAssertEqual(googleUserInfo.photoURL, URL(string: kGooglePhotoURL))
        XCTAssertEqual(googleUserInfo.email, kGoogleEmail)

        // Verify FIRUserInfo properties from the Facebook auth provider.
        let facebookUserInfo = try XCTUnwrap(providerMap[FacebookAuthProvider.id])
        XCTAssertEqual(facebookUserInfo.uid, kFacebookID)
        XCTAssertNil(facebookUserInfo.displayName)
        XCTAssertNil(facebookUserInfo.photoURL)
        XCTAssertEqual(facebookUserInfo.email, kFacebookEmail)

        #if os(iOS)
          // Verify FIRUserInfo properties from the phone auth provider.
          let phoneUserInfo = try XCTUnwrap(providerMap[PhoneAuthProvider.id])
          XCTAssertEqual(phoneUserInfo.phoneNumber, kPhoneNumber)
        #endif

        // Test NSSecureCoding
        XCTAssertTrue(User.supportsSecureCoding)

        let data = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWith: data)
        archiver.encode(user, forKey: kUserArchiverKey)
        archiver.finishEncoding()

        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data as Data)
        // TODO: The unarchive will fail without this, because of FIRUser not being in the allowed classes.
        // Meanwhile the unarchive in FIRAuth.m getUser method.
        unarchiver.requiresSecureCoding = false
        let unarchivedUser = try XCTUnwrap(unarchiver
          .decodeObject(forKey: kUserArchiverKey) as? User)

        // Verify NSSecureCoding for FIRUser
        XCTAssertEqual(unarchivedUser.providerID, user.providerID)
        XCTAssertEqual(unarchivedUser.uid, user.uid)
        XCTAssertEqual(unarchivedUser.email, user.email)
        XCTAssertEqual(unarchivedUser.photoURL, user.photoURL)
        XCTAssertEqual(unarchivedUser.displayName, user.displayName)

        // Verify NSSecureCoding properties besides providerData contents.
        XCTAssertEqual(unarchivedUser.isAnonymous, user.isAnonymous)
        XCTAssertEqual(unarchivedUser.isEmailVerified, user.isEmailVerified)
        XCTAssertEqual(unarchivedUser.refreshToken, user.refreshToken)
        XCTAssertEqual(unarchivedUser.metadata.creationDate, user.metadata.creationDate)
        XCTAssertEqual(unarchivedUser.metadata.lastSignInDate, user.metadata.lastSignInDate)
        XCTAssertEqual(unarchivedUser.providerData.count, user.providerData.count)

        let unarchivedProviderMap = unarchivedUser.providerData.reduce(into: [String: UserInfo]()) {
          $0[$1.providerID] = $1
        }
        // Verify NSSecureCoding properties from email/password.
        let unarchivedPasswordUserInfo = try XCTUnwrap(unarchivedProviderMap[EmailAuthProvider.id])
        XCTAssertEqual(unarchivedPasswordUserInfo.uid, passwordUserInfo.uid)
        XCTAssertEqual(unarchivedPasswordUserInfo.displayName, passwordUserInfo.displayName)
        XCTAssertEqual(unarchivedPasswordUserInfo.photoURL, passwordUserInfo.photoURL)
        XCTAssertEqual(unarchivedPasswordUserInfo.email, passwordUserInfo.email)

        // Verify NSSecureCoding properties from the Google auth provider.
        let unarchivedGoogleUserInfo = try XCTUnwrap(unarchivedProviderMap[GoogleAuthProvider.id])
        XCTAssertEqual(unarchivedGoogleUserInfo.uid, googleUserInfo.uid)
        XCTAssertEqual(unarchivedGoogleUserInfo.displayName, googleUserInfo.displayName)
        XCTAssertEqual(unarchivedGoogleUserInfo.photoURL, googleUserInfo.photoURL)
        XCTAssertEqual(unarchivedGoogleUserInfo.email, googleUserInfo.email)

        // Verify NSSecureCoding properties from the Facebook auth provider.
        let unarchivedFacebookUserInfo =
          try XCTUnwrap(unarchivedProviderMap[FacebookAuthProvider.id])
        XCTAssertEqual(unarchivedFacebookUserInfo.uid, facebookUserInfo.uid)
        XCTAssertEqual(unarchivedFacebookUserInfo.displayName, facebookUserInfo.displayName)
        XCTAssertEqual(unarchivedFacebookUserInfo.photoURL, facebookUserInfo.photoURL)
        XCTAssertEqual(unarchivedFacebookUserInfo.email, facebookUserInfo.email)

        #if os(iOS)
          // Verify FIRUserInfo properties from the phone auth provider.
          let unarchivedPhoneUserInfo = try XCTUnwrap(unarchivedProviderMap[PhoneAuthProvider.id])
          XCTAssertEqual(unarchivedPhoneUserInfo.phoneNumber, phoneUserInfo.phoneNumber)

          // TODO: Finish multifactor
          // Verify FIRMultiFactorInfo properties.
//        XCTAssertEqual(user.multiFactor.enrolledFactors[0].factorID, PhoneMultiFactorID)
//        XCTAssertEqual(user.multiFactor.enrolledFactors[0].UID, kEnrollmentID)
//        XCTAssertEqual(user.multiFactor.enrolledFactors[0].displayName, self.kDisplayName)
//        NSDateFormatter *dateFormatter =
//            [[NSDateFormatter alloc] init];
//        [dateFormatter
//            setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
//        NSDate *date =
//            [dateFormatter dateFromString:kEnrolledAt];
//        XCTAssertEqual(
//            user.multiFactor.enrolledFactors[0].enrollmentDate,
//            date);
        #endif
      } catch {
        XCTFail("Caught an error in \(#function): \(error)")
      }
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testUpdateEmailSuccess
      @brief Tests the flow of a successful @c updateEmail:completion: call.
   */
  func testUpdateEmailSuccess() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      self.changeUserEmail(user: user, expectation: expectation)
    }
    waitForExpectations(timeout: 5)
  }

  // TODO: revisit after Auth.swift
  /** @fn testUpdateEmailWithAuthLinkAccountSuccess
      @brief Tests a successful @c updateEmail:completion: call updates provider info.
   */
//  func testUpdateEmailWithAuthLinkAccountSuccess() {
//    setFakeGetAccountProvider()
//    let expectation = self.expectation(description: #function)
//    self.signInWithEmailPasswordReturnFakeUserLink() { user in
//      self.changeUserEmail(user: user, expectation: expectation)
//    }
//    waitForExpectations(timeout: 5)
//  }

  /** @fn testUpdateEmailFailure
      @brief Tests the flow of a failed @c updateEmail:completion: call.
   */
  func testUpdateEmailFailure() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        let group = self.createGroup()

        user.updateEmail(to: self.kNewEmail) { rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.invalidEmail.rawValue)
          // Email should not have changed on the client side.
          XCTAssertEqual(user.email, self.kEmail)
          // User is still signed in.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          expectation.fulfill()
        }
        group.wait()

        try self.rpcIssuer?.respond(serverErrorMessage: "INVALID_EMAIL")

      } catch {
        XCTFail("Caught an error in \(#function): \(error)")
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testUpdateEmailAutoSignOut
      @brief Tests the flow of a failed @c updateEmail:completion: call that automatically signs out.
   */
  func testUpdateEmailAutoSignOut() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        let group = self.createGroup()

        user.updateEmail(to: self.kNewEmail) { rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.invalidUserToken.rawValue)
          // Email should not have changed on the client side.
          XCTAssertEqual(user.email, self.kEmail)
          // User is no longer signed in..
          XCTAssertNil(UserTests.auth?.currentUser)
          expectation.fulfill()
        }
        group.wait()

        try self.rpcIssuer?.respond(serverErrorMessage: "INVALID_ID_TOKEN")

      } catch {
        XCTFail("Caught an error in \(#function): \(error)")
      }
    }
    waitForExpectations(timeout: 5)
  }

  // TODO: Three phone number tests for iOS go here.

  /** @fn testUpdatePasswordSuccess
      @brief Tests the flow of a successful @c updatePassword:completion: call.
   */
  func testUpdatePasswordSuccess() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      self.changeUserEmail(user: user, changePassword: true, expectation: expectation)
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testUpdatePasswordFailure
      @brief Tests the flow of a failed @c updatePassword:completion: call.
   */
  func testUpdatePasswordFailure() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        let group = self.createGroup()

        user.updatePassword(to: self.kNewPassword) { rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.requiresRecentLogin.rawValue)
          // Email should not have changed on the client side.
          XCTAssertEqual(user.email, self.kEmail)
          // User is still signed in.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          expectation.fulfill()
        }
        group.wait()

        try self.rpcIssuer?.respond(serverErrorMessage: "CREDENTIAL_TOO_OLD_LOGIN_AGAIN")

      } catch {
        XCTFail("Caught an error in \(#function): \(error)")
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testUpdateEmptyPasswordFailure
      @brief Tests the flow of a failed @c updatePassword:completion: call due to an empty password.
   */
  func testUpdateEmptyPasswordFailure() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        let group = self.createGroup()

        user.updatePassword(to: self.kNewPassword) { rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.weakPassword.rawValue)
          // Email should not have changed on the client side.
          XCTAssertEqual(user.email, self.kEmail)
          // User is still signed in.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          expectation.fulfill()
        }
        group.wait()

        try self.rpcIssuer?.respond(serverErrorMessage: "WEAK_PASSWORD")

      } catch {
        XCTFail("Caught an error in \(#function): \(error)")
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testUpdatePasswordFailureAutoSignOut
      @brief Tests the flow of a failed @c updatePassword:completion: call that automatically signs
          out.
   */
  func testUpdatePasswordFailureAutoSignOut() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        let group = self.createGroup()

        user.updatePassword(to: self.kNewPassword) { rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.userDisabled.rawValue)
          // Email should not have changed on the client side.
          XCTAssertEqual(user.email, self.kEmail)
          // User is signed out.
          XCTAssertNil(UserTests.auth?.currentUser)
          expectation.fulfill()
        }
        group.wait()

        try self.rpcIssuer?.respond(serverErrorMessage: "USER_DISABLED")

      } catch {
        XCTFail("Caught an error in \(#function): \(error)")
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testChangeProfileSuccess
      @brief Tests a successful user profile change flow.
   */
  func testChangeProfileSuccess() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        let group = self.createGroup()

        let profileChange = user.createProfileChangeRequest()
        profileChange.photoURL = URL(string: self.kTestPhotoURL)
        profileChange.displayName = self.kNewDisplayName
        profileChange.commitChanges { error in
          XCTAssertTrue(Thread.isMainThread)
          XCTAssertNil(error)
          XCTAssertEqual(user.displayName, self.kNewDisplayName)
          XCTAssertEqual(user.photoURL, URL(string: self.kTestPhotoURL))
          expectation.fulfill()
        }
        group.wait()

        try self.rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                               "refreshToken": self.kRefreshToken])
      } catch {
        XCTFail("Caught an error in \(#function): \(error)")
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testChangeProfileFailure
      @brief Tests a failed user profile change flow.
   */
  func testChangeProfileFailure() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        let group = self.createGroup()

        let profileChange = user.createProfileChangeRequest()
        profileChange.displayName = self.kNewDisplayName
        profileChange.commitChanges { rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.tooManyRequests.rawValue)
          // Email should not have changed on the client side.
          XCTAssertEqual(user.email, self.kEmail)
          XCTAssertEqual(user.displayName, self.kDisplayName)
          // User is still signed in.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          expectation.fulfill()
        }
        group.wait()

        try self.rpcIssuer?.respond(serverErrorMessage: "TOO_MANY_ATTEMPTS_TRY_LATER")

      } catch {
        XCTFail("Caught an error in \(#function): \(error)")
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testChangeProfileFailureAutoSignOut
      @brief Tests a failed user profile change flow that automatically signs out.
   */
  func testChangeProfileFailureAutoSignOut() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        let group = self.createGroup()

        let profileChange = user.createProfileChangeRequest()
        profileChange.displayName = self.kNewDisplayName
        profileChange.commitChanges { rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.userNotFound.rawValue)
          // Email should not have changed on the client side.
          XCTAssertEqual(user.email, self.kEmail)
          // User is signed out.
          XCTAssertNil(UserTests.auth?.currentUser)
          expectation.fulfill()
        }
        group.wait()

        try self.rpcIssuer?.respond(serverErrorMessage: "USER_NOT_FOUND")

      } catch {
        XCTFail("Caught an error in \(#function): \(error)")
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testGetIDTokenResultSuccess
      @brief Tests the flow of a successful @c getIDTokenResultWithCompletion: call.
   */
  func testGetIDTokenResultSuccess() {
    internalGetIDTokenResult(token: RPCBaseTests.kFakeAccessToken, forceRefresh: false)
  }

  /** @fn testGetIDTokenResultForcingRefreshSameAccessTokenSuccess
      @brief Tests the flow of a successful @c getIDTokenResultForcingRefresh:completion: call when
          the returned access token is the same as the stored access token.
   */
  func testGetIDTokenResultForcingRefreshSameAccessTokenSuccess() {
    internalGetIDTokenResult(token: RPCBaseTests.kFakeAccessToken)
  }

  /** @fn testGetIDTokenResultForcingRefreshSuccess
      @brief Tests the flow successful @c getIDTokenResultForcingRefresh:completion: calls.
   */
  func testGetIDTokenResultForcingRefreshSuccess() {
    internalGetIDTokenResult(token: RPCBaseTests.kFakeAccessTokenLength415)
    internalGetIDTokenResult(token: RPCBaseTests.kFakeAccessTokenLength416)
    internalGetIDTokenResult(token: RPCBaseTests.kFakeAccessTokenLength523,
                             emailMatch: "aunitestuser4@gmail.com")
  }

  /** @fn testGetIDTokenResultSuccessWithBase64EncodedURL
      @brief Tests the flow of a successful @c getIDTokenResultWithCompletion: call using a base64 url
          encoded string.
   */
  func testGetIDTokenResultSuccessWithBase64EncodedURL() {
    internalGetIDTokenResult(token: RPCBaseTests.kFakeAccessTokenWithBase64,
                             emailMatch: ">>>>>>>>????????@gmail.com",
                             audMatch: "??????????>>>>>>>>>>")
  }

  /** @fn testGetIDTokenResultForcingRefreshFailure
      @brief Tests the flow of a failed @c getIDTokenResultForcingRefresh:completion: call.
   */
  func testGetIDTokenResultForcingRefreshFailure() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser(fakeAccessToken: RPCBaseTests.kFakeAccessToken) { user in
      self.rpcIssuer?.secureTokenNetworkError = true
      user.getIDTokenResult(forcingRefresh: true) { tokenResult, rawError in
        do {
          XCTAssertTrue(Thread.isMainThread)
          XCTAssertNil(tokenResult)
          let error = try XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.networkError.rawValue)
        } catch {
          XCTFail("Caught an error in \(#function): \(error)")
        }
        expectation.fulfill()
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testReloadSuccess
      @brief Tests the flow of a successful @c reloadWithCompletion: call.
   */
  func testReloadSuccess() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      user.reload { error in
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertNil(error)
        XCTAssertEqual(user.displayName, self.kDisplayName)
        XCTAssertEqual(user.email, self.kEmail)
        expectation.fulfill()
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testReloadFailure
      @brief Tests the flow of a failed @c reloadWithCompletion: call.
   */
  func testReloadFailure() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        let group = self.createGroup()

        // Clear fake so we can inject error
        self.rpcIssuer?.fakeGetAccountProviderJSON = nil

        user.reload { rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.quotaExceeded.rawValue)
          // User is still signed in.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          expectation.fulfill()
        }
        group.wait()

        try self.rpcIssuer?.respond(serverErrorMessage: "QUOTA_EXCEEDED")

      } catch {
        XCTFail("Caught an error in \(#function): \(error)")
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testReloadFailureAutoSignOut
      @brief Tests the flow of a failed @c reloadWithCompletion: call that automtatically signs out.
   */
  func testReloadFailureAutoSignOut() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        let group = self.createGroup()

        // Clear fake so we can inject error
        self.rpcIssuer?.fakeGetAccountProviderJSON = nil

        user.reload { rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.userTokenExpired.rawValue)
          // User is no longer signed in.
          XCTAssertNil(UserTests.auth?.currentUser)
          expectation.fulfill()
        }
        group.wait()

        try self.rpcIssuer?.respond(serverErrorMessage: "TOKEN_EXPIRED")

      } catch {
        XCTFail("Caught an error in \(#function): \(error)")
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testReauthenticateSuccess
      @brief Tests the flow of a successful @c reauthenticateWithCredential:completion: call.
   */
  func testReauthenticateSuccess() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        let group = self.createGroup()
        let emailCredential = EmailAuthProvider.credential(withEmail: self.kEmail,
                                                           password: self.kFakePassword)
        user.reauthenticate(with: emailCredential) { rawResult, error in
          XCTAssertTrue(Thread.isMainThread)
          XCTAssertNil(error)
          let result = try! XCTUnwrap(rawResult)
          XCTAssertEqual(result.user.uid, user.uid)
          XCTAssertEqual(result.user.email, user.email)
          XCTAssertEqual(result.additionalUserInfo?.newUser, false)
          // User is still signed in.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          expectation.fulfill()
        }
        group.wait()
        try self.rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                               "refreshToken": self.kRefreshToken])
      } catch {
        XCTFail("Caught an error in \(#function): \(error)")
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testReauthenticateWithCredentialSuccess
      @brief Tests the flow of a successful @c reauthenticateWithCredential call.
   */
  func testReauthenticateWithCredentialSuccess() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithGoogleCredential { user in
      do {
        let group = self.createGroup()
        let googleCredential = GoogleAuthProvider.credential(withIDToken: self.kGoogleIDToken,
                                                             accessToken: self.kGoogleAccessToken)
        user.reauthenticate(with: googleCredential) { reauthenticatedAuthResult, error in
          XCTAssertTrue(Thread.isMainThread)
          XCTAssertNil(error)
          // Verify that the current user is unchanged.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          // Verify that the current user and reauthenticated user are not same pointers.
          XCTAssertNotEqual(user, reauthenticatedAuthResult?.user)
          // Verify that anyway the current user and reauthenticated user have same IDs.
          XCTAssertEqual(reauthenticatedAuthResult?.user.uid, user.uid)
          XCTAssertEqual(reauthenticatedAuthResult?.user.email, user.email)
          XCTAssertEqual(reauthenticatedAuthResult?.user.displayName, user.displayName)
          XCTAssertEqual(reauthenticatedAuthResult?.additionalUserInfo?.username, self.kUserName)
          XCTAssertEqual(reauthenticatedAuthResult?.additionalUserInfo?.providerID,
                         GoogleAuthProvider.id)
          XCTAssertEqual(
            reauthenticatedAuthResult?.additionalUserInfo?.profile as? [String: String],
            self.kGoogleProfile
          )
          expectation.fulfill()
        }
        group.wait()
        try self.rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                               "refreshToken": self.kRefreshToken,
                                               "federatedId": self.kGoogleID,
                                               "providerId": GoogleAuthProvider.id,
                                               "localId": self.kLocalID,
                                               "displayName": self.kDisplayName,
                                               "rawUserInfo": self.kGoogleProfile,
                                               "username": self.kUserName])
      } catch {
        XCTFail("Caught an error in \(#function): \(error)")
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testReauthenticateFailure
      @brief Tests the flow of a failed @c reauthenticateWithCredential:completion: call.
   */
  func testReauthenticateFailure() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        let group = self.createGroup()

        self.setFakeGetAccountProvider(withLocalID: "A different Local ID")
        let emailCredential = EmailAuthProvider.credential(withEmail: self.kEmail,
                                                           password: self.kFakePassword)
        user.reauthenticate(with: emailCredential) { reauthenticatedAuthResult, rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.userMismatch.rawValue)
          // Email should not have changed on the client side.
          XCTAssertEqual(user.email, self.kEmail)
          // User is still signed in.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          expectation.fulfill()
        }
        group.wait()
        try self.rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                               "refreshToken": self.kRefreshToken])
      } catch {
        XCTFail("Caught an error in \(#function): \(error)")
      }
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testReauthenticateUserMismatchFailure
      @brief Tests the flow of a failed @c reauthenticateWithCredential:completion: call due to trying
          to reauthenticate a user that does not exist.
   */
  func testReauthenticateUserMismatchFailure() {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser { user in
      do {
        let group = self.createGroup()

        let googleCredential = GoogleAuthProvider.credential(withIDToken: self.kGoogleIDToken,
                                                             accessToken: self.kGoogleAccessToken)
        user.reauthenticate(with: googleCredential) { reauthenticatedAuthResult, rawError in
          XCTAssertTrue(Thread.isMainThread)
          let error = try! XCTUnwrap(rawError)
          XCTAssertEqual((error as NSError).code, AuthErrorCode.userMismatch.rawValue)
          // Email should not have changed on the client side.
          XCTAssertEqual(user.email, self.kEmail)
          // User is still signed in.
          XCTAssertEqual(UserTests.auth?.currentUser, user)
          expectation.fulfill()
        }
        group.wait()
        try self.rpcIssuer?.respond(serverErrorMessage: "USER_NOT_FOUND")
      } catch {
        XCTFail("Caught an error in \(#function): \(error)")
      }
    }
    waitForExpectations(timeout: 5)
  }

  // MARK: Private helper functions

  private func internalGetIDTokenResult(token: String, forceRefresh: Bool = true,
                                        emailMatch: String = "aunitestuser@gmail.com",
                                        audMatch: String = "test_aud") {
    setFakeGetAccountProvider()
    let expectation = self.expectation(description: #function)
    signInWithEmailPasswordReturnFakeUser(fakeAccessToken: token) { user in
      user.getIDTokenResult(forcingRefresh: forceRefresh) { rawTokenResult, error in
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertNil(error)
        XCTAssertEqual(user.displayName, self.kDisplayName)
        XCTAssertEqual(user.email, self.kEmail)
        let tokenResult = try! XCTUnwrap(rawTokenResult)
        XCTAssertEqual(tokenResult.token, token)
        XCTAssertNotNil(tokenResult.issuedAtDate)
        XCTAssertNotNil(tokenResult.authDate)
        XCTAssertNotNil(tokenResult.expirationDate)
        XCTAssertNotNil(tokenResult.signInProvider)

        // The lowercased is for the base64 test which seems to be an erroneously uppercased "Password"?
        XCTAssertEqual(tokenResult.signInProvider.lowercased(), EmailAuthProvider.id)
        XCTAssertEqual(tokenResult.claims["email"] as! String, emailMatch)
        XCTAssertEqual(tokenResult.claims["aud"] as! String, audMatch)

        // TODO: is this right? The ObjC implementation was non-nil, but the test token is nil:
        XCTAssertNil(tokenResult.signInSecondFactor)
        expectation.fulfill()
      }
    }
    waitForExpectations(timeout: 5)
  }

  private func changeUserEmail(user: User, changePassword: Bool = false,
                               expectation: XCTestExpectation) {
    do {
      XCTAssertEqual(user.providerID, "Firebase")
      XCTAssertEqual(user.uid, kLocalID)
      XCTAssertEqual(user.displayName, kDisplayName)
      XCTAssertEqual(user.photoURL, URL(string: kTestPhotoURL))
      XCTAssertEqual(user.email, kEmail)

      // Pretend that the display name on the server has been changed since the original signin.
      setFakeGetAccountProvider(withNewDisplayName: kNewDisplayName)

      let group = createGroup()
      if changePassword {
        user.updatePassword(to: kNewPassword) { error in
          XCTAssertNil(error)
          XCTAssertEqual(user.displayName, self.kNewDisplayName)
          XCTAssertFalse(user.isAnonymous)
          expectation.fulfill()
        }
      } else {
        user.updateEmail(to: kNewEmail) { error in
          XCTAssertNil(error)
          XCTAssertEqual(user.email, self.kNewEmail)
          XCTAssertEqual(user.displayName, self.kNewDisplayName)
          XCTAssertFalse(user.isAnonymous)
          expectation.fulfill()
        }
      }
      group.wait()

      let request = try XCTUnwrap(rpcIssuer?.request as? SetAccountInfoRequest)
      XCTAssertEqual(request.APIKey, UserTests.kFakeAPIKey)
      XCTAssertEqual(request.accessToken, RPCBaseTests.kFakeAccessToken)
      if changePassword {
        XCTAssertEqual(request.password, kNewPassword)
        XCTAssertNil(request.email)
      } else {
        XCTAssertEqual(request.email, kNewEmail)
        XCTAssertNil(request.password)
      }
      XCTAssertNil(request.localID)
      XCTAssertNil(request.displayName)
      XCTAssertNil(request.photoURL)
      XCTAssertNil(request.providers)
      XCTAssertNil(request.deleteAttributes)
      XCTAssertNil(request.deleteProviders)

      try rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                        "email": kNewEmail,
                                        "refreshToken": kRefreshToken])

    } catch {
      XCTFail("Caught an error in \(#function): \(error)")
    }
  }

  private func signInWithEmailPasswordReturnFakeUser(fakeAccessToken: String = RPCBaseTests
    .kFakeAccessToken,
    completion: @escaping (User) -> Void) {
    let kRefreshToken = "fakeRefreshToken"
    setFakeSecureTokenService(fakeAccessToken: fakeAccessToken)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    do {
      try UserTests.auth?.signOut()
      UserTests.auth?.signIn(withEmail: kEmail, password: kFakePassword) { authResult, error in
        // 4. After the response triggers the callback, verify the returned result.
        XCTAssertTrue(Thread.isMainThread)
        guard let user = authResult?.user else {
          XCTFail("authResult.user is missing")
          return
        }
        XCTAssertEqual(user.refreshToken, kRefreshToken)
        XCTAssertFalse(user.isAnonymous)
        XCTAssertEqual(user.email, self.kEmail)
        guard let additionalUserInfo = authResult?.additionalUserInfo else {
          XCTFail("authResult.additionalUserInfo is missing")
          return
        }
        XCTAssertFalse(additionalUserInfo.isNewUser)
        XCTAssertEqual(additionalUserInfo.providerID, EmailAuthProvider.id)
        XCTAssertNil(error)
        completion(user)
      }
      group.wait()

      // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
      let request = try XCTUnwrap(rpcIssuer?.request as? VerifyPasswordRequest)
      XCTAssertEqual(request.email, kEmail)
      XCTAssertEqual(request.password, kFakePassword)
      XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)
      XCTAssertTrue(request.returnSecureToken)

      // 3. Send the response from the fake backend.
      try rpcIssuer?.respond(withJSON: ["idToken": fakeAccessToken,
                                        "isNewUser": true,
                                        "refreshToken": kRefreshToken])

    } catch {
      XCTFail("Throw in \(#function): \(error)")
    }
  }

  private func signInWithGoogleCredential(completion: @escaping (User) -> Void) {
    setFakeSecureTokenService(fakeAccessToken: RPCBaseTests.kFakeAccessToken)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    do {
      try UserTests.auth?.signOut()
      let googleCredential = GoogleAuthProvider.credential(withIDToken: kGoogleIDToken,
                                                           accessToken: kGoogleAccessToken)
      UserTests.auth?.signIn(with: googleCredential) { authResult, error in
        // 4. After the response triggers the callback, verify the returned result.
        XCTAssertTrue(Thread.isMainThread)
        guard let user = authResult?.user else {
          XCTFail("authResult.user is missing")
          return
        }
        XCTAssertEqual(user.refreshToken, self.kRefreshToken)
        XCTAssertFalse(user.isAnonymous)
        XCTAssertEqual(user.email, self.kEmail)
        guard let additionalUserInfo = authResult?.additionalUserInfo,
              let profile = additionalUserInfo.profile as? [String: String] else {
          XCTFail("authResult.additionalUserInfo and/or profile is missing")
          return
        }
        XCTAssertEqual(profile, self.kGoogleProfile)
        XCTAssertFalse(additionalUserInfo.isNewUser)
        XCTAssertEqual(additionalUserInfo.providerID, GoogleAuthProvider.id)
        XCTAssertEqual(additionalUserInfo.username, self.kUserName)
        XCTAssertNil(error)
        completion(user)
      }
      group.wait()

      // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
      let request = try XCTUnwrap(rpcIssuer?.request as? VerifyAssertionRequest)
      XCTAssertEqual(request.providerID, GoogleAuthProvider.id)
      XCTAssertEqual(request.providerIDToken, kGoogleIDToken)
      XCTAssertEqual(request.providerAccessToken, kGoogleAccessToken)
      XCTAssertTrue(request.returnSecureToken)
      XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)
      XCTAssertTrue(request.returnSecureToken)

      // 3. Send the response from the fake backend.
      try rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                        "refreshToken": kRefreshToken,
                                        "federatedId": kGoogleID,
                                        "providerId": GoogleAuthProvider.id,
                                        "localId": kLocalID,
                                        "displayName": kDisplayName,
                                        "rawUserInfo": kGoogleProfile,
                                        "username": kUserName])

    } catch {
      XCTFail("Throw in \(#function): \(error)")
    }
  }

  // TODO: For testUpdateEmailWithAuthLinkAccountSuccess. Revisit after auth.swift. Should be able to
  // TODO: parameterize with signInWithEmailPasswordReturnFakeUser
//  private func signInWithEmailPasswordReturnFakeUserLink(completion: @escaping (User) -> Void) {
//    let kRefreshToken = "fakeRefreshToken"
//    setFakeSecureTokenService()
//
//    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
//    let group = createGroup()
//
//    do {
//      try UserTests.auth?.signOut()
//      UserTests.auth?.signIn(withEmail: kEmail, link:"https://www.google.com?oobCode=aCode&mode=signIn") { authResult, error in
//        // 4. After the response triggers the callback, verify the returned result.
//        XCTAssertTrue(Thread.isMainThread)
//        guard let user = authResult?.user else {
//          XCTFail("authResult.user is missing")
//          return
//        }
//        XCTAssertEqual(user.refreshToken, kRefreshToken)
//        XCTAssertFalse(user.isAnonymous)
//        XCTAssertEqual(user.email, self.kEmail)
//        guard let additionalUserInfo = authResult?.additionalUserInfo else {
//          XCTFail("authResult.additionalUserInfo is missing")
//          return
//        }
//        XCTAssertFalse(additionalUserInfo.isNewUser)
//        XCTAssertEqual(additionalUserInfo.providerID, EmailAuthProvider.id)
//        XCTAssertNil(error)
//        completion(user)
//      }
//      group.wait()
//
//      // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
  ////      let request = try XCTUnwrap(rpcIssuer?.request as? VerifyPasswordRequest)
  ////      XCTAssertEqual(request.email, kEmail)
  ////      XCTAssertEqual(request.password, kFakePassword)
  ////      XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)
  ////      XCTAssertTrue(request.returnSecureToken)
  ////
  ////      // 3. Send the response from the fake backend.
  ////      try rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
  ////                                        "isNewUser": true,
  ////                                        "refreshToken": kRefreshToken])
//
//      // waitForExpectations(timeout: 10)
//      // assertUser(AuthTests.auth?.currentUser)
//    } catch {
//      XCTFail("Throw in \(#function): \(error)")
//    }
//  }
}