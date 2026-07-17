//
//  LogDetailVC.swift
//  tvOS-App
//
//  Created by hulilei on 2025/2/8.
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import UIKit

class LogDetailVC: UIViewController {

    private let textView = UITextView()
    private let logFile: URL

    init(logFile: URL) {
        self.logFile = logFile
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadLogContent()
    }

    private func setupUI() {
        title = logFile.lastPathComponent

        textView.font = UIFont.systemFont(ofSize: 24)
        textView.isUserInteractionEnabled = true
        textView.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        view.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func loadLogContent() {
        do {
            let logContent = try String(contentsOf: logFile, encoding: .utf8)
            textView.text = logContent
        } catch {
            textView.text = "Failed to read log file: \(error)"
        }
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [textView]
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        if let nextFocusedView = context.nextFocusedView, nextFocusedView == textView {
            textView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.1)
        } else if let previouslyFocusedView = context.previouslyFocusedView, previouslyFocusedView == textView {
            textView.backgroundColor = .clear
        }
    }
}
