//
//  ConfigurationVC.swift
//  tvOS-App
//
//  Created by hulilei on 2025/2/8.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

import UIKit

class ConfigurationVC: UIViewController {
    
    // Input fields
    let datakitURLTextField = UITextField()
    let appIDTextField = UITextField()
    
    // Confirm button
    let confirmButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set background color
        view.backgroundColor = .white
        
        // Set input fields
        setupTextField(datakitURLTextField, placeholder: "Enter Datakit URL")
        setupTextField(appIDTextField, placeholder: "Enter App ID")
        
        // Set confirm button
        confirmButton.setTitle("Confirm", for: .normal)
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .primaryActionTriggered)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews
        view.addSubview(datakitURLTextField)
        view.addSubview(appIDTextField)
        view.addSubview(confirmButton)
        
        // Set layout constraints
        setupConstraints()
    }
    
    private func setupTextField(_ textField: UITextField, placeholder: String) {
        textField.placeholder = placeholder
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // datakitURLTextField constraints
            datakitURLTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            datakitURLTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 50),
            datakitURLTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -50),
            datakitURLTextField.heightAnchor.constraint(equalToConstant: 40),
            
            // appIDTextField constraints
            appIDTextField.topAnchor.constraint(equalTo: datakitURLTextField.bottomAnchor, constant: 20),
            appIDTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 50),
            appIDTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -50),
            appIDTextField.heightAnchor.constraint(equalToConstant: 40),
            
           
            confirmButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            confirmButton.widthAnchor.constraint(equalToConstant: 100),
            confirmButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    @objc private func confirmButtonTapped() {
        guard let datakitURL = datakitURLTextField.text, !datakitURL.isEmpty,
              let appID = appIDTextField.text, !appID.isEmpty else {
            // Handle empty input
            print("Please fill in all fields")
            return
        }
        
        // Handle confirm button tapped
        print("Datakit URL: \(datakitURL)")
        print("App ID: \(appID)")
        
        // Here you can add further logic, such as verifying input, sending network requests, etc.
    }
}
