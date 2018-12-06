//
//  OktaAPI.swift
//  OktaLogin
//
//  Created by Alex on 12/4/18.
//  Copyright © 2018 Alex. All rights reserved.
//

import Foundation

class OktaLogin: NSObject {
    
    enum Result {
        case success(accessToken: String, idToken: String)
        case error(String)
    }
    
    init(baseURL: URL, clientID: String, redirectURI: String, user: String, password: String) {
        self.baseURL = baseURL
        self.clientID = clientID
        self.redirectURI = redirectURI
        state = .ready(user: user, password: password)
        super.init()
        session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    }
    
    func login(completion: @escaping (Result) -> Void) {
        guard case .ready(_, _) = state else { return }
        self.completion = completion
        proceedWithState()
    }
    
    // MARK: - Private
    
    private var baseURL: URL
    private var clientID: String
    private var redirectURI: String
    private var state: State { didSet { proceedWithState() } }
    private var session: URLSession!
    private var completion: ((Result) -> Void)?
    
    private enum State {
        case ready(user: String, password: String)
        case sessionTokenReceived(sessionToken: String)
        case authCodeReceived(code: String, pkce: PKCE)
        case error(String)
        case loggedIn(accessToken: String, idToken: String)
    }
    
    private func proceedWithState() {
        switch state {
        case .ready(user: let user, password: let password):
            print("Performing primary authenication for \(user) ...")
            makePrimaryAuthenicationRequest(user: user, password: password)
        case .sessionTokenReceived(sessionToken: let token):
            print("Session Token received: \(token)")
            print("Performing authorization code request ...")
            makeAuthorizationCodeRequest(sessionToken: token)
        case .authCodeReceived(code: let code, pkce: let pkce):
            print("Authenication code received: \(code)")
            print("Performing code exchange request ...")
            makeCodeExchangeRequest(code: code, pkce: pkce)
        case .loggedIn(accessToken: let accessToken, idToken: let idToken):
            print("*** LOGGED IN ***")
            DispatchQueue.main.async {
                self.completion?(.success(accessToken: accessToken, idToken: idToken))
            }
        case .error(let error):
            print("ERROR: \(error)")
            DispatchQueue.main.async {
                self.completion?(.error(error))
            }
        }
    }
    
    private func makePrimaryAuthenicationRequest(user: String, password: String) {
        
        var url = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        url.path = "/api/v1/authn"

        let body: [String: Any] = ["username": user,
                                   "password": password,
                                   "relayState": "test",
                                   "options": ["multiOptionalFactorEnroll": false,
                                               "warnBeforePasswordExpired": false]]
        var request = URLRequest(url: url.url!)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = session.dataTask(with: request) { data, response, error in
            guard error == nil else {
                self.state = .error(error!.localizedDescription)
                return
            }
            let response = response as! HTTPURLResponse
            guard response.statusCode == 200 else {
                let body = String(data: data ?? Data(), encoding: .utf8)
                self.state = .error("Response: [\(response.statusCode)]\n\(body ?? "?")")
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
    
    private func makeAuthorizationCodeRequest(sessionToken: String) {
        
        let pkce = PKCE()
        
        let params: [String: String] = ["client_id": clientID,
                                        "response_type": "code",
                                        "scope": "openid offline_access",
                                        "redirect_uri": redirectURI,
                                        "state": String.randomAlphanumeric(length: 64),
                                        "code_challenge_method": "S256",
                                        "code_challenge": pkce.codeChallange,
                                        "sessionToken": sessionToken]
        
        var url = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        url.path = "/oauth2/default/v1/authorize"
        url.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        let task = session.dataTask(with: url.url!) { data, response, error in
            guard error == nil else {
                self.state = .error(error!.localizedDescription)
                return
            }
            let response = response as! HTTPURLResponse
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
            self.state = .authCodeReceived(code: code, pkce: pkce)
        }
        task.resume()
    }
    
    private func makeCodeExchangeRequest(code: String, pkce: PKCE) {
        
        let params: [String: String] = ["grant_type": "authorization_code",
                                        "client_id": clientID,
                                        "redirect_uri": redirectURI,
                                        "code": code,
                                        "code_verifier": pkce.codeVerifier]
        
        var url = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        url.path = "/oauth2/default/v1/token"
        
        var request = URLRequest(url: url.url!)
        request.httpMethod = "POST"
        request.httpBody = params.map({ "\($0.key)=\($0.value)" }).joined(separator: "&").data(using: .utf8)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpShouldHandleCookies = false
        
        let task = session.dataTask(with: request) { data, response, error in
            guard error == nil else {
                self.state = .error(error!.localizedDescription)
                return
            }
            let response = response as! HTTPURLResponse
            guard response.statusCode == 200 else {
                self.state = .error("Unexpected status code (\(response.statusCode))")
                return
            }
            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    self.state = .error("Error parsing server response")
                    return
            }
            guard let accessToken = json?["access_token"] as? String,
                let idToken = json?["id_token"] as? String else {
                self.state = .error("Tokens not found")
                return
            }
            self.state = .loggedIn(accessToken: accessToken, idToken: idToken)
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
