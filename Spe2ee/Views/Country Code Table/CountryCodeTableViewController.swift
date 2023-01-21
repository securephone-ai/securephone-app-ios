import UIKit

/// Views that register to this protocol will be able receive the selected country code inside the callback
protocol CountryCodeTableViewControllerDelegate {
  func didSelect(countryCode: CountryCode);
}

class CountryCodeTableViewController: UITableViewController {
  
  var delegate: CountryCodeTableViewControllerDelegate?
  let searchController = UISearchController(searchResultsController: nil)
  var isSearchBarEmpty: Bool {
    return searchController.searchBar.text?.isEmpty ?? true
  }
  var countryCodes = [CountryCode]()
  var filteredCountryCodes = [CountryCode]()
  var selectedCountryCode: CountryCode?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    if let cCodes = CountryCodeManager.GetCountryCodes() {
      countryCodes = cCodes
    }
    searchController.searchResultsUpdater = self
    searchController.obscuresBackgroundDuringPresentation = false
    searchController.searchBar.placeholder = "Search"
    navigationItem.searchController = searchController
    definesPresentationContext = true
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    guard let delegate = self.delegate else { return }
    guard let countryCode = selectedCountryCode else { return }
    delegate.didSelect(countryCode: countryCode)
  }
  
}

// MARK: - Table view data source
extension CountryCodeTableViewController {
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return isSearchBarEmpty ? countryCodes.count : filteredCountryCodes.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: .value1, reuseIdentifier: "CountryCodeCell")
    cell.textLabel?.text = isSearchBarEmpty ? countryCodes[indexPath.row].name : filteredCountryCodes[indexPath.row].name
    cell.detailTextLabel?.text = isSearchBarEmpty ? countryCodes[indexPath.row].code : filteredCountryCodes[indexPath.row].code
    return cell
  }
  
}

// MARK: - Table view delegate
extension CountryCodeTableViewController {
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    selectedCountryCode = isSearchBarEmpty ? countryCodes[indexPath.row] : filteredCountryCodes[indexPath.row]
    guard let navController = navigationController else {
      dismiss(animated: true, completion: nil)
      return;
    }
    navController.popViewController(animated: true)
  }
  
}

// MARK: - UISearchControl
extension CountryCodeTableViewController: UISearchResultsUpdating {
  
  func updateSearchResults(for searchController: UISearchController) {
    let searchBar = searchController.searchBar
    filterContentForSearchText(searchBar.text!)
  }
  
  func filterContentForSearchText(_ searchText: String) {
    filteredCountryCodes = countryCodes.filter { (countryCode: CountryCode) -> Bool in
      return countryCode.name.lowercased().contains(searchText.lowercased())
    }
    tableView.reloadData()
  }

}
