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
    private var logFiles: [URL] = [] // 存储所有 .log 文件的路径

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
        // 获取 logsDirectory 路径
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let logsDirectory = cachesDirectory.appendingPathComponent("FTLogs")
        let logsBackupDirectory = logsDirectory.appendingPathComponent("FTBackupLogs")

        // 读取 logsDirectory 下的 FTLog.log 文件
        let ftLogFile = logsDirectory.appendingPathComponent("FTLog.log")
        if FileManager.default.fileExists(atPath: ftLogFile.path) {
            logFiles.append(ftLogFile)
        }

        // 读取 _logsBackupDirectory 下的所有 .log 文件
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
