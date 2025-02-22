//
//  CategoryViewController.swift
//  ToDoListApp
//
//  Created by Tomasz Paluszkiewicz on 03/11/2020.
//  Copyright © 2020 Tomasz Paluszkiewicz. All rights reserved.
//

import UIKit
import RealmSwift
import UserNotifications
import EventKit
import ChameleonFramework

class CategoryViewController: UITableViewController {
    
    let defaults = UserDefaults.standard
    let eventStore = EKEventStore()
    
    let realm = try! Realm()
    var categories: Results<Category>?
    
    
    override func viewDidLoad() {
        //print("LAUNCHED: viewDidLoad(CategoryListView)")
        super.viewDidLoad()
        
        /// Check first launch. If true then show BeginViewController
        let firstLaunch = defaults.bool(forKey: KeyUserDefaults.firstLaunch)
        if firstLaunch == false {
            let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let newViewController = storyBoard.instantiateViewController(withIdentifier: IdentifierVC.beginVC) as! BeginViewController
            newViewController.modalPresentationStyle = .fullScreen
            //newViewController.modalTransitionStyle = .partialCurl
            self.navigationController?.present(newViewController, animated: true, completion: nil)
        }
        
        Helper.authorizationPushNotification()
        Helper.authorizationCalendarEvent()
        loadReamDatabase()
        viewDidLoadConfig()
        
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        
        self.view.backgroundColor = DefaultSettings.sharedInstance.backgroundColor
        
    }
    
    
    @objc func optionsButtonPressed() {
        
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let newViewController = storyBoard.instantiateViewController(withIdentifier: IdentifierVC.optionsVC) as! OptionsViewController
        newViewController.modalPresentationStyle = .fullScreen
        //newViewController.modalTransitionStyle = .partialCurl
        self.navigationController?.present(newViewController, animated: true, completion: nil)
        
    }
    
    
    //MARK: - TableView DataSource Methods
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories?.count ?? 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        /// Set name of cell
        let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell", for: indexPath)
        cell.textLabel?.numberOfLines = 0
        
        if let category = categories?[indexPath.row] {
            /// Set text in row
            cell.textLabel?.text = category.name
            cell.textLabel?.font = UIFont(name: Fonts.helveticNeueMedium, size: 20)
            
            guard let categoryColor = UIColor(hexString: category.color) else { fatalError() }
            
            /// Cell backgroundColor
            cell.backgroundColor = categoryColor
            /// Cell text color
            cell.textLabel?.textColor = ContrastColorOf(categoryColor, returnFlat: true)
        }
        
        return cell
        
    }
    
    
    
    //MARK: - TableView Delegate Methods
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        performSegue(withIdentifier: SegueIdentifier.goToItems, sender: self)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        
        if segue.identifier == SegueIdentifier.goToItems {
            let destinationVC = segue.destination as! ItemViewController
            
            if let indexPath = tableView.indexPathForSelectedRow {
                
                /// Property selectedCategory created and sended to ToDoListConroller
                destinationVC.selectedCategory = categories?[indexPath.row]
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        /// Delete row
        if (editingStyle == .delete) {
            
            deleteData(at: indexPath)
            
        }
    }
    
    
    //MARK: - Data Manipulation Methods
    
    func saveCategory(category: Category) {
        
        do {
            try realm.write {
                realm.add(category)
            }
        }catch {
            print("ERROR SAVING CONTEXT: \(error)")
        }
        tableView.reloadData()
    }
    
    func loadReamDatabase() {
        
        categories = realm.objects(Category.self)
    }
    
    func deleteData(at indexPath: IndexPath) {
        
        if let categoriesForDeletion = categories?[indexPath.row] {
            
            /// Delete all Calendar Events and PUSH Notifications in Category Folder
            for item in categoriesForDeletion.items {
                
                if item.dateCreated != nil {
                    let notificationCenter = UNUserNotificationCenter.current()
                    notificationCenter.removePendingNotificationRequests(withIdentifiers: ["id_\(item.title)-\(String(describing: item.dateCreated))"])
                }
                if let eventID = item.eventID {
                    if let event = self.eventStore.event(withIdentifier: eventID) {
                        do {
                            try self.eventStore.remove(event, span: .thisEvent)
                        } catch let error as NSError {
                            print("FAILED TO DELETE EVENT WITH ERROR : \(error)")
                        }
                    }
                }
                
            }
            
            /// Delete selected data
            do {
                try realm.write {
                    /// Delete children's also
                    realm.delete(categoriesForDeletion.items)
                    
                    /// Delete category Object
                    realm.delete(categoriesForDeletion)
                }
            } catch {
                print("ERROR DELETING CATEGORY: \(error)")
            }
            
        }
        
        ARSLineProgress.showFail()
        tableView.reloadData()
        
    }
    
    
    
    //MARK: - Add New Categories
    
    @IBAction func addButtonPressed(_ sender: Any) {
        
        /// Main property for TextField
        var textField = UITextField()
        
        /// Set Alert Window
        let mainAlert = UIAlertController(title: "Add New Category".localized(), message: "", preferredStyle: .alert)
        
        mainAlert.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        
        mainAlert.addAction(UIAlertAction(title: "Add".localized(), style: .default) { (action) in
            
            /// Add new Category
            let newCategory = Category()
            newCategory.name = textField.text!
            newCategory.color = UIColor.randomFlat().hexValue()
            
            
            guard newCategory.name != "" else{
                let alert = UIAlertController(title: "Text field is empty".localized(), message: "You have to type something here".localized(), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
                    self.present(mainAlert, animated: true, completion: nil)
                }))
                self.present(alert, animated: true, completion: nil)
                
                return
            }
            self.saveCategory(category: newCategory)
            ARSLineProgress.showSuccess()
        })
        
        mainAlert.addTextField { (alertTextField) in
            alertTextField.placeholder = "Title".localized()
            alertTextField.autocorrectionType = .yes
            alertTextField.spellCheckingType = .yes
            textField = alertTextField
        }
        
        present(mainAlert, animated: true, completion: nil)
        
    }
    
    
    //MARK: - LongPress Gesture Configuration for Color Change
    
    @objc func longpress(sender: UILongPressGestureRecognizer) {
        
        if sender.state == UIGestureRecognizer.State.began {
            let touchPoint = sender.location(in: tableView)
            if let indexPath = tableView.indexPathForRow(at: touchPoint) {
                
                
                
                let pickedRowColor = categories?[indexPath.row].color ?? "#ffffff"
                
                let alert = UIAlertController(style: .alert)
                alert.addColorPicker(color: UIColor(hexString: pickedRowColor)) { color in
                    
                    if let categoryColor = self.categories?[indexPath.row] {
                        
                        /// Update row color
                        do {
                            try self.realm.write {
                                
                                categoryColor.color = "\(color.hexValue())"
                            }
                        } catch {
                            print("ERROR CHANGE CATEGORY COLOR: \(error)")
                        }
                        
                    }
                    
                    self.tableView.reloadData()
                    
                }
                alert.addAction(title: "Cancel".localized(), style: .cancel)
                alert.show()
                
            }
        }
        
    }
    
    
    
    //MARK: - ViewDidLoad Configuration
    
    func viewDidLoadConfig() {
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longpress))
        tableView.addGestureRecognizer(longPress)
        
        navigationController?.navigationBar.tintColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        tableView.separatorStyle = .none
        tableView.rowHeight = 60
        navigationItem.leftBarButtonItem = UIBarButtonItem.optionsButton(self, action: #selector(optionsButtonPressed), imageName: ImageName.options)
        
    }
    
    
    
    
}


//MARK: - Extensions

extension UIBarButtonItem {
    
    static func optionsButton(_ target: Any?, action: Selector, imageName: String) -> UIBarButtonItem {
        let button = UIButton(type: .system)
        button.setImage(UIImage(named: imageName), for: .normal)
        button.addTarget(target, action: action, for: .touchUpInside)
        
        let menuBarItem = UIBarButtonItem(customView: button)
        menuBarItem.customView?.translatesAutoresizingMaskIntoConstraints = false
        menuBarItem.customView?.heightAnchor.constraint(equalToConstant: 24).isActive = true
        menuBarItem.customView?.widthAnchor.constraint(equalToConstant: 24).isActive = true
        
        return menuBarItem
    }
}
