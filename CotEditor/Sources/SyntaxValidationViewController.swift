/*
 
 SyntaxValidationViewController.swift
 
 CotEditor
 https://coteditor.com
 
 Created by 1024jp on 2014-09-08.
 
 ------------------------------------------------------------------------------
 
 © 2014-2016 1024jp
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 
 */

import Cocoa

class SyntaxValidationViewController: NSViewController {
    
    private(set) var didValidate = false
    
    private dynamic var result: String?
    
    
    
    // MARK:
    // MARK: View Controller Methods
    
    /// nib name
    override var nibName: String? {
        
        return "SyntaxValidationView"
    }
    
    
    // MARK: Public Methods
    
    /// validate style and insert the results to text view (return: if valid)
    func validateSyntax() -> Bool {
        
        guard let style = self.representedObject as? [String: AnyObject] else { return true }
        
        let results = CESyntaxManager.shared().validateSyntax(style)
        var message = ""
        
        switch results.count {
        case 0:
            message += "✅ " + NSLocalizedString("No error was found.", comment: "syntax style validation result")
        case 1:
            message += NSLocalizedString("An error was found!", comment: "syntax style validation result")
        default:
            message += String(format: NSLocalizedString("%i errors were found!", comment: "syntax style validation result"), results.count)
        }
        
        for result in results {
            message += "\n\n⚠️ " + result.localizedType + " [" + result.localizedRole + "] :" + result.string + "\n\t> " + result.localizedFailureReason
        }
        
        self.result = message
        
        return results.count == 0
    }
    
    
    
    // MARK: Action Messages
    
    /// start syntax style validation
    @IBAction func startValidation(_ sender: AnyObject?) {
        
        self.validateSyntax()
    }
    
}