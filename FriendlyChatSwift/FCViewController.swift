//
//  Copyright (c) 2015 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Photos
import UIKit

import Firebase
import GoogleMobileAds
import Charts

/**
 * AdMob ad unit IDs are not currently stored inside the google-services.plist file. Developers
 * using AdMob can store them as custom values in another plist, or simply use constants. Note that
 * these ad units are configured to return only test ads, and should not be used outside this sample.
 */
let kBannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"

@objc(FCViewController)
class FCViewController: UIViewController, UITableViewDataSource, UITableViewDelegate,
    UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    
    @IBOutlet weak var pieChartView: PieChartView!
    
    var waterConsumed = Int() // records weight

  // Instance variables
  @IBOutlet weak var textField: UITextField!
  @IBOutlet weak var sendButton: UIButton!
  var ref: FIRDatabaseReference!
  var messages: [FIRDataSnapshot]! = []
  var msglength: NSNumber = 10
  var _refHandle: FIRDatabaseHandle!

  var storageRef: FIRStorageReference!
  var remoteConfig: FIRRemoteConfig!

  @IBOutlet weak var banner: GADBannerView!
  @IBOutlet weak var clientTable: UITableView!


  override func viewDidLoad() {
    super.viewDidLoad()

    self.clientTable.registerClass(UITableViewCell.self, forCellReuseIdentifier: "tableViewCell")

    configureDatabase()
    configureStorage()
    configureRemoteConfig()
    fetchConfig()
    loadAd()
    logViewLoaded()
    
    let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"]
    let unitsSold = [20.0, 4.0, 6.0, 3.0, 12.0, 16.0]
    
    setChart(months, values: unitsSold)
    
  }

  deinit {
    self.ref.child("messages").removeObserverWithHandle(_refHandle)
  }
    
    func setChart(dataPoints: [String], values: [Double]) {
        
        var dataEntries: [ChartDataEntry] = []
        
        for i in 0..<dataPoints.count {
            let dataEntry = ChartDataEntry(value: values[i], xIndex: i)
            dataEntries.append(dataEntry)
        }
        
        let pieChartDataSet = PieChartDataSet(yVals: dataEntries, label: "Units Sold")
        let pieChartData = PieChartData(xVals: dataPoints, dataSet: pieChartDataSet)
        pieChartView.data = pieChartData
        
        var colors: [UIColor] = []
        
        for i in 0..<dataPoints.count {
            let red = Double(arc4random_uniform(256))
            let green = Double(arc4random_uniform(256))
            let blue = Double(arc4random_uniform(256))
            
            let color = UIColor(red: CGFloat(red/255), green: CGFloat(green/255), blue: CGFloat(blue/255), alpha: 1)
            colors.append(color)
        }
        
        pieChartDataSet.colors = colors
        
    }

  func configureDatabase() {
    ref = FIRDatabase.database().reference()
    // Listen for new messages in the Firebase database
    _refHandle = self.ref.child("messages").observeEventType(.ChildAdded, withBlock: { (snapshot) -> Void in
      self.messages.append(snapshot)
      self.clientTable.insertRowsAtIndexPaths([NSIndexPath(forRow: self.messages.count-1, inSection: 0)], withRowAnimation: .Automatic)
    })
  }

  func configureStorage() {
    storageRef = FIRStorage.storage().referenceForURL("gs://watercup-e06b3.appspot.com")
  }

  func configureRemoteConfig() {
    remoteConfig = FIRRemoteConfig.remoteConfig()
    // Create Remote Config Setting to enable developer mode.
    // Fetching configs from the server is normally limited to 5 requests per hour.
    // Enabling developer mode allows many more requests to be made per hour, so developers
    // can test different config values during development.
    let remoteConfigSettings = FIRRemoteConfigSettings(developerModeEnabled: true)
    remoteConfig.configSettings = remoteConfigSettings!
  }

  func fetchConfig() {
    var expirationDuration: Double = 3600
    // If in developer mode cacheExpiration is set to 0 so each fetch will retrieve values from
    // the server.
    if (self.remoteConfig.configSettings.isDeveloperModeEnabled) {
      expirationDuration = 0
    }

    // cacheExpirationSeconds is set to cacheExpiration here, indicating that any previously
    // fetched and cached config would be considered expired because it would have been fetched
    // more than cacheExpiration seconds ago. Thus the next fetch would go to the server unless
    // throttling is in progress. The default expiration duration is 43200 (12 hours).
    remoteConfig.fetchWithExpirationDuration(expirationDuration) { (status, error) in
      if (status == .Success) {
        print("Config fetched!")
        self.remoteConfig.activateFetched()
        let friendlyMsgLength = self.remoteConfig["friendly_msg_length"]
        if (friendlyMsgLength.source != .Static) {
          self.msglength = friendlyMsgLength.numberValue!
          print("Friendly msg length config: \(self.msglength)")
        }
      } else {
        print("Config not fetched")
        print("Error \(error)")
      }
    }
  }

  @IBAction func didPressFreshConfig(sender: AnyObject) {
    fetchConfig()
  }

  @IBAction func didSendMessage(sender: UIButton) {
    textFieldShouldReturn(textField)
  }

  @IBAction func didPressCrash(sender: AnyObject) {
    FIRCrashMessage("Cause Crash button clicked")
  }

  func logViewLoaded() {
    FIRCrashMessage("View loaded")
  }

  func loadAd() {
    self.banner.adUnitID = kBannerAdUnitID
    self.banner.rootViewController = self
    self.banner.loadRequest(GADRequest())
  }

  func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
    guard let text = textField.text else { return true }

    let newLength = text.utf16.count + string.utf16.count - range.length
    return newLength <= self.msglength.integerValue // Bool
  }

  // UITableViewDataSource protocol methods
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return messages.count
  }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        // Dequeue cell
        let cell: UITableViewCell! = self.clientTable.dequeueReusableCellWithIdentifier("ClientCell", forIndexPath: indexPath)
        // Unpack message from Firebase DataSnapshot
        
        // changed vvv
        //print statements are there just to check the data...
        let messageSnapshot: FIRDataSnapshot! = self.messages[indexPath.row]
        //print(messageSnapshot)
        let message = messageSnapshot.value as! NSDictionary
        //print(message)
        let date = message.objectForKey("date") as! String
        let time = message.objectForKey("time") as! String
        //print(date)
        // changed ^^^
        
        //old code
        //let message = messageSnapshot.value as! Dictionary<String, String>
        //let date = message[Constants.MessageFields.date] as String!
        //
        
        if let imageUrl = message[Constants.MessageFields.imageUrl] {
            if imageUrl.hasPrefix("gs://") {
                FIRStorage.storage().referenceForURL(imageUrl as! String).dataWithMaxSize(INT64_MAX){ (data, error) in
                    if let error = error {
                        print("Error downloading: \(error)")
                        return
                    }
                    cell.imageView?.image = UIImage.init(data: data!)
                }
            } else if let url = NSURL(string:imageUrl as! String), data = NSData(contentsOfURL: url) {
                cell.imageView?.image = UIImage.init(data: data)
            }
            cell!.textLabel?.text = "sent by: \(date)"
        } else {
            
            //let text = message[Constants.MessageFields.weight] as! String! <- doesn't work
            
            // changed vvv
            let aNum = message.objectForKey("weight") as! NSNumber
            let text = aNum.stringValue
            // changed ^^^
            
            cell!.textLabel?.text = date + "/" + time + ": " + text
            cell!.imageView?.image = UIImage(named: "ic_account_circle")
            if let photoUrl = message[Constants.MessageFields.photoUrl], url = NSURL(string:photoUrl as! String), data = NSData(contentsOfURL: url) {
                cell!.imageView?.image = UIImage(data: data)
            }
        }
        return cell!
    }

  // UITextViewDelegate protocol methods
  func textFieldShouldReturn(textField: UITextField) -> Bool {
    let data = [Constants.MessageFields.weight: textField.text! as String]
    sendMessage(data)
    return true
  }

  func sendMessage(data: [String: String]) {
    var mdata = data
    mdata[Constants.MessageFields.date] = AppState.sharedInstance.displayName
    if let photoUrl = AppState.sharedInstance.photoUrl {
      mdata[Constants.MessageFields.photoUrl] = photoUrl.absoluteString
    }
    // Push data to Firebase Database
    self.ref.child("messages").childByAutoId().setValue(mdata)
  }

  // MARK: - Image Picker

  @IBAction func didTapAddPhoto(sender: AnyObject) {
    let picker = UIImagePickerController()
    picker.delegate = self
    if (UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera)) {
      picker.sourceType = .Camera
    } else {
      picker.sourceType = .PhotoLibrary
    }

    presentViewController(picker, animated: true, completion:nil)
  }

  func imagePickerController(picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [String : AnyObject]) {
      picker.dismissViewControllerAnimated(true, completion:nil)

    // if it's a photo from the library, not an image from the camera
    if #available(iOS 8.0, *), let referenceUrl = info[UIImagePickerControllerReferenceURL] {
      let assets = PHAsset.fetchAssetsWithALAssetURLs([referenceUrl as! NSURL], options: nil)
      let asset = assets.firstObject
      asset?.requestContentEditingInputWithOptions(nil, completionHandler: { (contentEditingInput, info) in
        let imageFile = contentEditingInput?.fullSizeImageURL
        let filePath = "\(FIRAuth.auth()?.currentUser?.uid)/\(Int(NSDate.timeIntervalSinceReferenceDate() * 1000))/\(referenceUrl.lastPathComponent!)"
        self.storageRef.child(filePath)
          .putFile(imageFile!, metadata: nil) { (metadata, error) in
            if let error = error {
              print("Error uploading: \(error.description)")
              return
            }
            self.sendMessage([Constants.MessageFields.imageUrl: self.storageRef.child((metadata?.path)!).description])
          }
      })
    } else {
      let image = info[UIImagePickerControllerOriginalImage] as! UIImage
      let imageData = UIImageJPEGRepresentation(image, 0.8)
      let imagePath = FIRAuth.auth()!.currentUser!.uid +
        "/\(Int(NSDate.timeIntervalSinceReferenceDate() * 1000)).jpg"
      let metadata = FIRStorageMetadata()
      metadata.contentType = "image/jpeg"
      self.storageRef.child(imagePath)
        .putData(imageData!, metadata: metadata) { (metadata, error) in
          if let error = error {
            print("Error uploading: \(error)")
            return
          }
          self.sendMessage([Constants.MessageFields.imageUrl: self.storageRef.child((metadata?.path)!).description])
      }
    }
  }

  func imagePickerControllerDidCancel(picker: UIImagePickerController) {
    picker.dismissViewControllerAnimated(true, completion:nil)
  }

  @IBAction func signOut(sender: UIButton) {
    let firebaseAuth = FIRAuth.auth()
    do {
      try firebaseAuth?.signOut()
      AppState.sharedInstance.signedIn = false
      dismissViewControllerAnimated(true, completion: nil)
    } catch let signOutError as NSError {
      print ("Error signing out: \(signOutError)")
    }
  }

  func showAlert(title:String, message:String) {
    dispatch_async(dispatch_get_main_queue()) {
        let alert = UIAlertController(title: title,
            message: message, preferredStyle: .Alert)
        let dismissAction = UIAlertAction(title: "Dismiss", style: .Destructive, handler: nil)
        alert.addAction(dismissAction)
        self.presentViewController(alert, animated: true, completion: nil)
    }
  }

}
