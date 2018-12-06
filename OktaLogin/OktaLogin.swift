//
//  OktaAPI.swift
//  OktaLogin
//
//  Created by Alex on 12/4/18.
//  Copyright © 2018 Alex. All rights reserved.
//

import Foundation

class OktaLogin: NSObject {
    
    private var session: URLSession!
    
    private var state: State { didSet { proceedWithState() } }
    private var pkce: PKCE
    
    private var completion: (() -> Void)?
    
    private enum State {
        case ready(user: String, password: String)
        case sessionTokenReceived(sessionToken: String)
        case authCodeReceived(code: String)
        case error(String)
        case loggedIn
    }
    
    init(user: String, password: String) {
        state = .ready(user: user, password: password)
        pkce = PKCE()
        super.init()
        session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    }
    
    func login(completion: @escaping () -> Void) {
        guard case .ready(_, _) = state else { return }
        self.completion = completion
        proceedWithState()
    }
    
    func proceedWithState() {
        switch state {
        case .ready(user: let user, password: let password):
            print("Performing primary authenication for \(user) ...")
            makePrimaryAuthenicationRequest(user: user, password: password)
        case .sessionTokenReceived(sessionToken: let token):
            print("Session Token received: \(token)")
            print("Performing authorization code request ...")
            makeAuthorizationCodeRequest(sessionToken: token)
        case .authCodeReceived(code: let code):
            print("Authenication code received: \(code)")
            
            
            
            
            
            
        default:
            break
        }
    }
    
    func makePrimaryAuthenicationRequest(user: String, password: String) {
        let url = URL(string: "https://lohika-um.oktapreview.com/api/v1/authn")!
        let body: [String: Any] = ["username": user,
                                   "password": password,
                                   "relayState": "test",
                                   "options": ["multiOptionalFactorEnroll": false,
                                               "warnBeforePasswordExpired": false]]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = session.dataTask(with: request) { data, response, error in
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
                self.state = .error("No response")
                return
            }
            guard statusCode == 200 else {
                let body = String(data: data ?? Data(), encoding: .utf8)
                self.state = .error("Response: [\(statusCode)]\n\(body ?? "?")")
                return
            }
            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    self.state = .error("Error parsing server response")
                    return
            }
            guard let token = json?["sessionToken"] as? String else {
                self.state = .error("Session Token not found")
                return
            }
            self.state = .sessionTokenReceived(sessionToken: token)
        }
        task.resume()
    }
    
    func makeAuthorizationCodeRequest(sessionToken: String) {
        let baseURL = "https://lohika-um.oktapreview.com"
        let params: [String: String] = ["client_id": "0oahng9nv4VQeNpvn0h7",
                                        "response_type": "code",
                                        "scope": "openid offline_access",
                                        "redirect_uri": "com.ios-okta-sdk-redirect-test-app:/callback",
                                        "state": String.randomAlphanumeric(length: 64),
                                        "code_challenge_method": "S256",
                                        "code_challenge": pkce.codeChallange,
                                        "sessionToken": sessionToken]
        
        var url = URLComponents(string: baseURL)!
        url.path = "/oauth2/default/v1/authorize"
        url.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        let task = session.dataTask(with: url.url!) { data, response, error in
            guard let response = response as? HTTPURLResponse else {
                self.state = .error("No response")
                return
            }
            guard response.statusCode == 302 else {
                self.state = .error("Unexpected status code (\(response.statusCode))")
                return
            }
            guard let location = response.allHeaderFields["Location"] as? String,
                let locationURL = URLComponents(string: location),
                let code = locationURL.queryItems?.first(where: { $0.name == "code" } )?.value else {
                    
                    self.state = .error("Can't find code in redirect location")
                    return
                    
            }
            self.state = .authCodeReceived(code: code)
        }
        task.resume()
    }
}

extension OktaLogin: URLSessionTaskDelegate {
    
    // Blocking HTTP redirects
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
