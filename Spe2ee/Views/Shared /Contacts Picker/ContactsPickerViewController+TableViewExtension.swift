
import Foundation
import Contacts
import UIKit

// MARK: Table delegate and data source
extension ContactsPickerViewController: UITableViewDelegate, UITableViewDataSource {
  
  func numberOfSections(in tableView: UITableView) -> Int {
    guard let contactsPicker = contactsPicker else { return 0 }
    
    if !searchString.isEmpty || !contactsPicker.isDataGrouped {
      return 1
    }
    
    if contactsPicker.dataSourceType == .phone {
      guard let items = contactsPicker.groupedItems else { return 0 }
      return items.count
    } else {
      // Get it from the delegate
      guard let rows = contactsPicker.dataSource?.numberOfSectionsContactsPicker() else { return 0 }
      return rows
    }
  }
  
  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 30
  }
  
  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    guard let contactsPicker = contactsPicker else { return UIView() }
    
    let view = UIView()
    view.frame = CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 30)
    view.backgroundColor = .systemGray5
    
    let label = UILabel()
    view.addSubview(label)
    
    if searchString.count > 0 {
      label.text = "Search Results".localized()
    } else {
      if contactsPicker.dataSourceType == .phone {
        label.text = contactsPicker.groupedItems![section].key.uppercased()
      } else {
        label.text = Blackbox.shared.contactsSections[section].sectionInitial.uppercased()
      }
    }
    label.sizeToFit()
    label.pin.left(15).vCenter()
    
    return view
  }
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return CGFloat(ContactsPickerConfig.tableStyle.tableRowHeight)
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    guard let contactsPicker = contactsPicker else { return 0 }
    
    if !searchString.isEmpty {
      return contactsPicker.filteredItems.count
    }
    
    if contactsPicker.dataSourceType == .phone {
      if contactsPicker.isDataGrouped {
        return contactsPicker.groupedItems![section].value.count
      } else {
        return contactsPicker.items.count
      }
    } else {
      //Try to get rows from delegate
      guard let rows = contactsPicker.dataSource?.contactPickerRows(forSection: section) else { return 0 }
      return rows
    }
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let contactsPicker = contactsPicker else { return UITableViewCell() }
    
    //Get Reference to Cell
    let cell: ContactsPickerTableCell = self.contentView.tableView.dequeueReusableCell(withIdentifier: ContactsPickerTableCell.ID) as! ContactsPickerTableCell
    cell.selectionStyle = .none
    
    var item:ContactItem!
    
    if !searchString.isEmpty {
      item = contactsPicker.filteredItems[indexPath.row]
    } else {
      if contactsPicker.isDataGrouped {
        if contactsPicker.dataSourceType == .phone {
         
        }
      } else {
        item = contactsPicker.items[indexPath.row]
      }
        
      if contactsPicker.dataSourceType == .phone {
        if contactsPicker.isDataGrouped {
          item = contactsPicker.groupedItems![indexPath.section].value[indexPath.row]
        } else {
          item = contactsPicker.items[indexPath.row]
        }
      } else {
        //Try to get item from delegate
        item = contactsPicker.dataSource?.getItem(at: indexPath)
      }
    }
    
    //Configure cell properties
    cell.labelTitle.text        = item.title
    cell.labelSubTitle.text     = item.description
    cell.initials.isHidden      = true
    cell.imageAvatar.isHidden   = true
    
    if let contact = item.userInfo as? CNContact {
      
      DispatchQueue.global(qos: .background).async {
        
        if (contact.imageDataAvailable && contact.imageData!.count > 0) {
          let img = UIImage(data: contact.imageData!)
          DispatchQueue.main.async {
            item.image = img
            cell.imageAvatar.image      = img
            cell.initials.isHidden      = true
            cell.imageAvatar.isHidden   = false
          }
        } else {
          DispatchQueue.main.async {
            cell.initials.text          = item.getInitials()
            cell.initials.isHidden      = false
            cell.imageAvatar.isHidden   = true
          }
        }
      }
      
    } else {
      if item.image == nil && item.imageURL == nil{
        cell.initials.text          = item.getInitials()
        cell.initials.isHidden      = false
        cell.imageAvatar.isHidden   = true
      } else {
        if item.imageURL != ""{
          cell.initials.isHidden      = true
          cell.imageAvatar.isHidden   = false
          cell.imageAvatar.setImageFromURL(stringImageUrl: item.imageURL!)
        }else{
          cell.imageAvatar.image      = item.image
          cell.initials.isHidden      = true
          cell.imageAvatar.isHidden   = false
        }
      }
    }
    
    if item.color != nil{
      cell.initials.backgroundColor = item.color!
    } else {
      cell.initials.backgroundColor   = updateInitialsColorForIndexPath(indexPath)
    }
    
    //Set initial state
    if let itm_pre = self.selectedItems.firstIndex(where: { (itm) -> Bool in
      itm == item
    }){
      self.selectedItems[itm_pre].color = cell.initials.backgroundColor!
      cell.accessoryType = UITableViewCell.AccessoryType.checkmark
    }else{
      cell.accessoryType = UITableViewCell.AccessoryType.none
    }
    
    return cell
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let contactsPicker = contactsPicker else { return }
    
    //Get selected cell
    let cell = tableView.cellForRow(at: indexPath) as! ContactsPickerTableCell
    
    var item: ContactItem!
    
    if contactsPicker.dataSourceType == .phone {
      
      if !searchString.isEmpty {
        item = contactsPicker.filteredItems[indexPath.row]
      } else {
        if contactsPicker.isDataGrouped {
          item = contactsPicker.groupedItems![indexPath.section].value[indexPath.row]
        } else {
          item = contactsPicker.items[indexPath.row]
        }
      }
    } else {
      //Try to get item from delegate
      item = contactsPicker.dataSource?.getItem(at: indexPath)
    }
    
    //Save item data
    item.color = cell.initials.backgroundColor!
    
    //Check if cell is already selected or not
    if cell.accessoryType == UITableViewCell.AccessoryType.checkmark
    {
      
      //Set accessory type
      cell.accessoryType = UITableViewCell.AccessoryType.none
      
      //Comunicate deselection to delegate
      contactsPicker.delegate?.didUnselect(item: item)
      
      //Reload collectionview
      self.reloadAndPositionScroll(idp: item.row!, remove: true)
      updateSelectionScrollViewHeight()
      
    }
    else {
      // Set accessory type
      cell.accessoryType = UITableViewCell.AccessoryType.checkmark
      
      // Add current item to selected
      selectedItems.append(item)
      updateSelectionScrollViewHeight()
      
      // Comunicate selection to delegate
      contactsPicker.delegate?.didSelect(item: item)
      
      // Reload collectionview
      self.reloadAndPositionScroll(idp: item.row!, remove:false)
    }
    
    // Reset search
    if !searchString.isEmpty {
      //searchBar.text = ""
      contentView.searchBar.text = ""
      contentView.searchBar.resignFirstResponder()
      searchString = ""
      contactsPicker.delegate?.userDidSearch(searchString: "")
      self.contentView.tableView.reloadData()
    }
    
  }
  
  /// Function that select a random color for passed indexpath
  ///
  /// - Parameter indexpath:
  /// - Returns: UIColor random, from Config.colorArray
  private func updateInitialsColorForIndexPath(_ indexpath: IndexPath) -> UIColor{
    
    //Applies color to Initial Label
    let randomValue = (indexpath.row + indexpath.section) % ContactsPickerConfig.colorArray.count
    
    return ContactsPickerConfig.colorArray[randomValue]
    
  }
  
  /// Reaload collectionview data and scroll to last position
  ///
  /// - Parameters:
  ///   - idp: is the tableview position index
  ///   - remove: true if you have to remove item
  private func reloadAndPositionScroll(idp: Int, remove: Bool) {
    
    //Identify the item inside selected array
    let item = selectedItems.filter { (itm) -> Bool in
      itm.row == idp
    }.first
    
    //Remove
    if remove {
      
      // For remove from collection view and create IndexPath, i need the index posistion in the array
      let id = selectedItems.firstIndex { (itm) -> Bool in
        itm.row == idp
      }
      
      // Filter array removing the item
      selectedItems = selectedItems.filter({ (itm) -> Bool in
        itm.row != idp
      })
      
      // Reload collectionview
      if id != nil{
        removeItemAndReload(index: id!)
      }
      
      guard let contactsPicker = contactsPicker else { return }
      contactsPicker.delegate?.didUnselect(item: item!)
      
      // Reload cell state
      reloadCellState(row: idp, selected: false)
      
      
      if selectedItems.count <= 0{
        // Toggle scrollview
        toggleSelectionScrollView(show: false)
      }
      // Add
    } else {
      
      toggleSelectionScrollView(show: true)
      
      // Reload data
      self.contentView.selectionScrollView.insertItems(at: [IndexPath(item: selectedItems.count-1, section: 0)])
      let lastItemIndex = IndexPath(item: self.selectedItems.count-1, section: 0)
      
      // Scroll to selected item
      self.contentView.selectionScrollView.scrollToItem(at: lastItemIndex, at: .right, animated: true)
      
      reloadCellState(row: idp, selected: true)
    }
  }
  
  /// Remove item from collectionview and reset tag for button
  ///
  /// - Parameter index: id to remove
  private func removeItemAndReload(index:Int) {
    
    //if no selection reload all
    if selectedItems.count == 0{
      self.contentView.selectionScrollView.reloadData()
    } else {
      //reload current
      self.contentView.selectionScrollView.deleteItems(at: [IndexPath(item: index, section: 0)])
    }
  }
  
  // MARK: - UISearchBarDelegate
  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    guard let contactsPicker = contactsPicker else { return }
    self.searchString = searchText
    
    contactsPicker.filteredItems.removeAll()
    
    if (searchText.isEmpty) {
      self.perform(#selector(self.hideKeyboardWithSearchBar(_:)), with: searchBar, afterDelay: 0)
      self.searchString = ""
      
    } else {
      if contactsPicker.isDataGrouped {
        contactsPicker.groupedItems!.forEach { (arg0) in
          let (_, value) = arg0
          
          for contact in value where contact.title.lowercased().contains(searchString.lowercased()) {
            contactsPicker.filteredItems.append(contact)
          }
        }
      } else {
        contactsPicker.filteredItems = contactsPicker.items.filter({$0.title.lowercased().contains(searchString.lowercased())})
      }
    }
    contactsPicker.delegate?.userDidSearch(searchString: searchText)
    self.contentView.tableView.reloadData()
  }
  
  @objc func hideKeyboardWithSearchBar(_ searchBar:UISearchBar){
    searchBar.resignFirstResponder()
  }
  
  func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool{
    return true
  }
  
}
