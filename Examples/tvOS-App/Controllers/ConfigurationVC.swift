//
//  ConfigurationVC.swift
//  tvOS-App
//
//  Created by hulilei on 2025/2/8.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

import UIKit

class ConfigurationVC: UIViewController {
    
    // 输入框
    let datakitURLTextField = UITextField()
    let appIDTextField = UITextField()
    
    // 确认按钮
    let confirmButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 设置背景颜色
        view.backgroundColor = .white
        
        // 设置输入框
        setupTextField(datakitURLTextField, placeholder: "Enter Datakit URL")
        setupTextField(appIDTextField, placeholder: "Enter App ID")
        
        // 设置确认按钮
        confirmButton.setTitle("Confirm", for: .normal)
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .primaryActionTriggered)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加子视图
        view.addSubview(datakitURLTextField)
        view.addSubview(appIDTextField)
        view.addSubview(confirmButton)
        
        // 设置布局约束
        setupConstraints()
    }
    
    private func setupTextField(_ textField: UITextField, placeholder: String) {
        textField.placeholder = placeholder
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // datakitURLTextField 约束
            datakitURLTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            datakitURLTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 50),
            datakitURLTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -50),
            datakitURLTextField.heightAnchor.constraint(equalToConstant: 40),
            
            // appIDTextField 约束
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
            // 处理输入为空的情况
            print("Please fill in all fields")
            return
        }
        
        // 处理确认按钮点击事件
        print("Datakit URL: \(datakitURL)")
        print("App ID: \(appID)")
        
        // 这里可以添加进一步的逻辑，比如验证输入、发送网络请求等
    }
}
