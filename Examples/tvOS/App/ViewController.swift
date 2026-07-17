//
//  ViewController.swift
//  tvOS-App
//
//  Created by hulilei on 2024/12/16.
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
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

class ViewController: UICollectionViewController {
    struct Action {
        var title: String
        var callback: () -> Void
    }
    
    var actions: [Action]!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        view.backgroundColor = UIColor(white: 0.8, alpha: 1)
        self.navigationController?.navigationBar.backgroundColor = UIColor.black
        self.navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 20, left: 10, bottom: 10, right: 10)
        layout.itemSize = CGSize(width: (UIScreen.main.bounds.width / 4) - 20, height: 200)
        layout.minimumInteritemSpacing = 20

        self.collectionView.collectionViewLayout = layout
        self.collectionView.register(ActionCell.self, forCellWithReuseIdentifier: "ActionCell")
        
        actions = [
            Action(title: "Open TableViewController", callback: openTableView),
            Action(title: "Open Nib ViewController", callback: openNibViewController),
            Action(title: "Open SplitViewController", callback: openSplitViewController),
            Action(title: "Debug Logs", callback: openDebugLogsController),

        ]
    }
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return actions.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ActionCell", for: indexPath) as? ActionCell ?? ActionCell()
        cell.titleLabel.text = actions[indexPath.item].title
        cell.accessibilityIdentifier = actions[indexPath.item].title
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        actions[indexPath.item].callback()
    }
        
    private func openTableView() {
        let tableVC = TableViewController()
        navigationController?.pushViewController(tableVC, animated: true)
    }
    
    private func openNibViewController() {
        let nibVC = NibViewController()
        navigationController?.pushViewController(nibVC, animated: true)
    }
    
    private func openSplitViewController() {
        let splitVC = SplitViewController(style: .doubleColumn)
        self.present(splitVC, animated: false, completion: nil)
    }
    
    private func openDebugLogsController() {
        let debugLogs = DebugLogsVC()
        navigationController?.pushViewController(debugLogs, animated: true)
    }
    
//    private func openConfigurationController() {
//        let splitVC = ConfigurationVC()
//        navigationController?.pushViewController(splitVC, animated: true)
//    }

}

