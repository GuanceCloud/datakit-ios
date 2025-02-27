import Foundation
import UIKit
protocol SplitViewItemClick {
    func tableViewSelectionDidSelect(index:Int)
}
class SplitViewController: UISplitViewController,SplitViewItemClick {
    var leftVC:SplitRootViewController=SplitRootViewController()
    var secondaryVC:SplitViewSecondaryController = SplitViewSecondaryController()
    @available(iOS 14.0, *)
    override init(style: UISplitViewController.Style) {
        super.init(style: style)
        initialize()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }
    
    private func initialize() {
        self.modalPresentationStyle = .fullScreen
        leftVC.delegate = self
        self.viewControllers = [leftVC, secondaryVC]
    }
    func tableViewSelectionDidSelect(index:Int){
        secondaryVC.showViewIndex(index: index)
    }
    
}

class SplitRootViewController: UITableViewController {
    var delegate:SplitViewItemClick?
    var dataSource = Array<String>.init()
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = ["RUM","LOG","TRACE"]
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
        if let delegate = delegate {
            delegate.tableViewSelectionDidSelect(index: indexPath.row)
        }
    }
}

class SplitViewSecondaryController: UIViewController {
    var rumVC:RUMViewController = RUMViewController.init()
    var logVC:LogViewController = LogViewController.init()
    var traceVC:TraceViewController = TraceViewController.init()
    var current:Int = 0
    override func viewDidLoad() {
        super.viewDidLoad()
        self.addChild(rumVC)
        self.addChild(logVC)
        self.addChild(traceVC)
        self.view.addSubview(rumVC.view)
    }
    
   public func showViewIndex(index:Int){
        if current != index {
            let to = getIndexVC(index: index)
            let from = getIndexVC(index: current)
            self.transition(from: from, to: to, duration: 0.1, options: .transitionCrossDissolve) {
                self.current = index
            }
        }
    }
    func getIndexVC(index:Int) -> UIViewController {
        if index == 0 {
            return rumVC
        }
        if index == 1 {
            return logVC
        }
        if index == 2 {
            return traceVC
        }
        return rumVC
    }
}
