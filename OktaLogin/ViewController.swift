//
//  ViewController.swift
//  OktaLogin
//
//  Created by Alex on 12/4/18.
//  Copyright © 2018 Alex. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // MARK: - Private
    
    @IBOutlet private var loginField: UITextField!
    @IBOutlet private var passwordField: UITextField!
    @IBOutlet private var loginButton: UIButton!
    @IBOutlet private var activityIndicator: UIActivityIndicatorView!
    
    @IBAction private func loginTapped() {
        
        guard let user = loginField.text, let password = passwordField.text else { return }
        
        activityIndicator.startAnimating()
        
        OktaAPI.login(user: user, password: password) { [weak self] in
            
            self?.activityIndicator.stopAnimating()
        }
    }
}

