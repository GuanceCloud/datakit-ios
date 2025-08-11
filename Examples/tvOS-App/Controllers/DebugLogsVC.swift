//
//  DebugLogsVC.swift
//  tvOS-App
//
//  Created by hulilei on 2025/2/8.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

import UIKit

class DebugLogsVC: UIViewController,UITableViewDataSource,UITableViewDelegate {

    private let tableView = UITableView()
    private var logFiles: [URL] = [] // Store paths of all .log files

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadLogFiles()
    }

    private func setupUI() {
        title = "Debug Logs"

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        tableView.frame = view.bounds
    }

    private func loadLogFiles() {
        // Get logsDirectory path
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let logsDirectory = cachesDirectory.appendingPathComponent("FTLogs")
        let logsBackupDirectory = logsDirectory.appendingPathComponent("FTBackupLogs")

        // Read FTLog.log file in logsDirectory
        let ftLogFile = logsDirectory.appendingPathComponent("FTLog.log")
        if FileManager.default.fileExists(atPath: ftLogFile.path) {
            logFiles.append(ftLogFile)
        }

        // Read all .log files in _logsBackupDirectory
        do {
            let backupLogFiles = try FileManager.default.contentsOfDirectory(at: logsBackupDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "log" }
            logFiles.append(contentsOf: backupLogFiles)
        } catch {
            print("Failed to read backup log files: \(error)")
        }

        tableView.reloadData()
    }
}
extension DebugLogsVC {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return logFiles.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let logFile = logFiles[indexPath.row]
        cell.textLabel?.text = logFile.lastPathComponent
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let logFile = logFiles[indexPath.row]
        let logDetailVC = LogDetailVC(logFile: logFile)
        navigationController?.pushViewController(logDetailVC, animated: true)
    }
}
