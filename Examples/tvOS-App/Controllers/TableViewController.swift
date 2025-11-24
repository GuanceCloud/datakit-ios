import Foundation
import UIKit
import FTMobileSDK

class TableViewController: UITableViewController {
    var dataSource:Array<String> = []

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "TableViewController"
        self.tableView.accessibilityIdentifier = "TABLE_VIEW"
        dataSource = ["appendGlobalContext","appendRUMGlobalContext","appendLogGlobalContext"]
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CELL") ?? UITableViewCell(style: .default, reuseIdentifier: "CELL")
        cell.selectionStyle = .none
        cell.textLabel?.text = dataSource[indexPath.row]
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath:IndexPath){
        switch indexPath.row {
        case 0:
            FTMobileAgent.appendGlobalContext(["global_key": "global_value"])
        case 1:
            FTMobileAgent.appendRUMGlobalContext(["rum_key": "rum_value"])
        case 2:
            FTMobileAgent.appendLogGlobalContext(["log_key": "log_value"])
        default:
            print("default")
        }
    }
    
}
