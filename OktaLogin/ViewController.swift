//
//  ViewController.swift
//  OktaLogin
//
//  Created by Alex on 12/4/18.
//  Copyright © 2018 Alex. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet private var loginField: UITextField!
    @IBOutlet private var passwordField: UITextField!
    @IBOutlet private var loginButton: UIButton!
    @IBOutlet private var activityIndicator: UIActivityIndicatorView!
    
    @IBAction private func loginTapped() {
        
        guard let user = loginField.text, let password = passwordField.text else { return }
        
        activityIndicator.startAnimating()
        loginButton.isEnabled = false
        
        OktaLogin(baseURL: URL(string: "https://myorg.okta.com")!,
                  clientID: "", // your application client_id
                  redirectURI: "", // your application login redirect url, e.g. com.okta.myapp:/callback
                  user: user,
                  password: password).login() { [weak self] result in
                    
            self?.activityIndicator.stopAnimating()
            self?.loginButton.isEnabled = true
            
            switch result {
            case .success(accessToken: let accessToken, idToken: let idToken):
                let alert = UIAlertController(title: "Success!",
                                              message: "Access Token:\n\(accessToken)\n\nID Token:\n\(idToken)",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self?.present(alert, animated: true, completion: nil)
            case .error(let error):
                let alert = UIAlertController(title: "Error :-(",
                                              message: error,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self?.present(alert, animated: true, completion: nil)
            }
        }
    }
}
