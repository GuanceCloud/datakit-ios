import Foundation
import UIKit

class TableViewController: UITableViewController {
   
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "TableViewController"
        self.tableView.accessibilityIdentifier = "TABLE_VIEW"
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 100
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CELL") ?? UITableViewCell(style: .default, reuseIdentifier: "CELL")
        cell.selectionStyle = .none
        cell.textLabel?.text = "\(indexPath.row)"
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath:IndexPath){
        let dict:[String:Any] = ["key1":"value1","key2":"value2"]
        let key = dict["key"] as! String
        print("key:\(key)")
    }
    
}
