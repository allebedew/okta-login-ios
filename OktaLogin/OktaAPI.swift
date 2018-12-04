//
//  OktaAPI.swift
//  OktaLogin
//
//  Created by Alex on 12/4/18.
//  Copyright © 2018 Alex. All rights reserved.
//

import Foundation

class OktaAPI {
    
    static func login(user: String, password: String, completion: @escaping () -> Void) {
        
        makePrimaryAuthenicationRequest(user: user, password: password) { token in
            guard let token = token else {
                DispatchQueue.main.async {
                    completion()
                }
                return
            }
            
            DispatchQueue.main.async {
                completion()
            }
        }
        
    }
    
    private static func makePrimaryAuthenicationRequest(user: String, password: String,
                                                        completion: @escaping (_ token: String?) -> Void) {
        print("Performin primary authenication for \(user) ...")
        
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
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
                completion(nil)
                return
            }
            guard statusCode == 200 else {
                let body = String(data: data ?? Data(), encoding: .utf8)
                print("Response: [\(statusCode)]\n\(body ?? "?")")
                completion(nil)
                return
            }
            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    print("Error parsing server response")
                    completion(nil)
                    return
            }
            guard let token = json?["sessionToken"] as? String else {
                print("Session Token not found")
                completion(nil)
                return
            }
            
            print("Session Token received: \(token)")
            completion(token)
        }
        task.resume()
    }
    
}
