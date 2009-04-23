/* -------------------------------------------------------------------------------------
* TransferContact Class: Controller for the TransferContacts page
* M.Smith 8 April 2009
* http://www.force2b.net
*
* Mass Contact Transfer Controller Class
* - Used by the TransferContacts Page 
* - Works with the TransferContactsSearchResults and searchCriteria Classes
*  ------------------------------------------------------------------------------------- */
public With Sharing class transferContacts {

    // From and To UserID's         
    public string fromUserID;
    public string toUserID;
    
    // Option to send an eMail to the owner after transferring 
    public boolean sendeMailToOwner = false;
    
    // If this is set to TRUE (by an InputHidden tag on the page) then show SOQL and other debug messages
    public boolean DebugMode = false;
    
    // Collection of search results for displaying
    // List<contact> searchResults = new List<contact>();
    public List<transferContactSearchResults> searchResults = new List<transferContactSearchResults>();
    
    // Collection of criteria line items using Wrapper class
    public List<searchCriteria> criteriaLine = New List<searchCriteria>();

    // Collection of fields for criteria picklist - build this once and reuse for each line
    public List<SelectOption> cacheFieldSelectValues = new List<SelectOption>();
    
    // Flag to identify when a transfer was just completed and running the query a second time for additional records
    private Boolean transferJustCompleted = false;
    
    // Capture a Map and Set of Contact Fields so we only do the Describe ONCE per instance
    private Map<String, Schema.SObjectField> contactFieldMap = null;
    
    // ------------------------------------------------
    // Constructor Method
    // ------------------------------------------------
    public transferContacts() {
    
        // Build a cached list of Contact/Account fields for the criteria picklist
        BuildSearchFieldsList();
        
        // Init the criteria object to be used on the page via <Apex:DataTable>
        for (integer j = 0; j < 5; j++) {
            searchCriteria critLine = new searchCriteria();
            critLine.SearchField = '';
            critLine.SearchOperator = '';
            critLine.SearchValue = '';
            if (j < 4) critLine.Logical = 'AND';
            criteriaLine.add(critLine);
        }

        // Define the private vars of the Map and Set of Contact Fields
        // so we only do the describe one time        
        contactFieldMap = Schema.SObjectType.Contact.fields.getMap();
                
    }

// ------------------------------------------------
   
    // Get/Set methods to enable or disable DebugMode on the page.
    // This is called by an InputHidden tag on the page
    public boolean getSetDebugModeTRUE()    { this.DebugMode = true; return TRUE; }
    public boolean getSetDebugModeFALSE()   { this.DebugMode = false; return FALSE; }
    public void setSetDebugModeTRUE(boolean x)  { this.DebugMode = true; }
    public void setSetDebugModeFALSE(boolean x) { this.DebugMode = false; }

    // Get/Set Methods for the FROM and TO UserID's
    public String getfromUserID()   { return fromUserID; }
    public String gettoUserID()     { return toUserID; }
    public void setfromUserID(string userID)    { this.fromUserID = userID; }
    public void settoUserID(string userID)      { this.toUserID = userID; }
    
    // Get/Set Methods for the Send eMail to New Owner Option
    public Boolean getsendeMailToOwner()     { return this.sendeMailToOwner; }
    public void setsendeMailToOwner(boolean s)    { 
    	this.sendeMailToOwner = s; 
    }
    
    // Returns the date format (MM/DD/YYYY, DD/MM/YYYY, etc.) that criteria should be entered in
    // This is determined in the CriteriaWrapper class by loooking at the users Locale settings
    public string getInputDateFormat() { return criteriaLine[0].getInputDateFormat() ; }
    
// ------------------------------------------------

    // Create a SelectOption list of all usernames in the User table (active and inactive)
    public List<SelectOption> getFromUsers() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new selectOption('', '--- select a User ---'));
        for (User u : [Select ID, Name FROM User Order by Name]) {
                options.add(new selectOption(u.ID, u.Name));
        }
        return options;
    }

    // Create a SelectOption list of Active Users in the User table
    public List<SelectOption> getToUsers() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new selectOption('', '--- select a User ---'));
        for (User u : [Select ID, Name FROM User WHERE IsActive=true Order by Name]) {
                options.add(new selectOption(u.ID, u.Name));
        }
        return options;
    } 

    // Return the list of Contact/Account fields for the criteria picklists
    public List<SelectOption> getsearchFields() {
        return this.cacheFieldSelectValues;
    }
    
    // Create a SelectOption list Contact & Account fields for a select list
    // Uses a method in the Criteria Class to build the select lists for the two objects
    private void BuildSearchFieldsList() {
    
        if (cacheFieldSelectValues.size() == 0) {
        
            // Create the Schema Lists for the Contact and Account objects
            Schema.DescribeSObjectResult contactDescribe = Contact.sObjectType.getDescribe();
            Schema.DescribeSObjectResult accountDescribe = Account.sObjectType.getDescribe();
            
            // Create the Maps of Fields for the Contact and Account objects
            Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();
            Map<String, Schema.SObjectField> accountFields = Schema.SObjectType.Account.fields.getMap();
            
            searchCriteria critClass = new searchCriteria();
            
            // Return SelectOption lists for the Contact and Account objects
            List<SelectOption> sel1 = critClass.GetFieldsForObject(contactFields, '', '');
            List<SelectOption> sel2 = critClass.GetFieldsForObject(accountFields, 'Account.', 'Account.');
            
            // Combine the two returned SelectOption[] lists into a single list
            List<SelectOption> options = new List<SelectOption>();
            options.add(new selectOption('', '- select field -'));
            for (Selectoption selOpt : sel1) {
                options.add(selOpt);
            }
            for (Selectoption selOpt : sel2) {
                options.add(selOpt);
            }
            
            // Set the cached value so we only do this once per instance
            cacheFieldSelectValues = options;
            
        } 
    } 

    // ------------------------------------------------
    // Returns a List<> of Criteria Objects for use with <Apex:DataTable>
    // to allow multiple lines to be displayed and the values retrievable
    // ------------------------------------------------
    public list<searchCriteria> getsearchCriteria() {
        return criteriaLine;
    }

	// -------------------------------------------------------------------------------------
	// SEARCH BUTTON:
	// Builds SOQL Statement based on selection criteria
	// Fills searchResults[] list
	// -------------------------------------------------------------------------------------
    public pageReference doSearch() {
    
        // If no TOUser selected, then show error and return
        if (toUserID == null) {
            ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.FATAL, 'A "Transfer To User" Must be Selected'));
            return null;
        }

        // Build a list of ALL Contact Fields for the Query.
        // This allows the user to modify the VisualForce page to show any
        // columns they want in the display without having to modify the Class 
        // in a development environment.
        Set <String> contactFlds = contactFieldMap.keySet();
        string contactFieldsList = ''; 
        for (string f : contactFlds) {
            string fldType = ('' + contactFieldMap.get(f).getDescribe().getType()).replace('Schema.DisplayType.', '') ;
            if (fldType <> 'REFERENCE' && f <> 'IsDeleted' && f <> 'SystemModstamp') {
                if (contactFieldsList <> '') contactFieldsList += ', ';
                contactFieldsList += f;
            }
        }

        // Build the base SOQL String, querying the standard Contact fields WHERE the current OwnerID = the selected value
        string cSOQL = 'SELECT ' + contactFieldsList + ', Account.Name, Account.Site, Account.Owner.Name, '  +
            'Account.Industry, Account.Type, Account.Owner.Alias, ' + 
            'Owner.Name, Owner.Alias, CreatedBy.Name, CreatedBy.Alias, LastModifiedBy.Name, LastModifiedBy.Alias ' +
            'FROM Contact WHERE OwnerID <> \'' + toUserID + '\' ';
            
        // If a From User was selected, add this to the critiera
        if (fromUserID <> null) cSOQL += ' AND OwnerID = \'' + fromUserID + '\' ';
        
        // For each criteria line item, call the method to build the where clause component
        for (searchCriteria cl : criteriaLine) {
                cSOQL += cl.buildWhereClause(DebugMode); 
        }
        
        // Sort the results and limit to the first 250 rows
        cSOQL += ' ORDER BY Account.Name, Name LIMIT 250' ;
        
        // Debug: Display the SOQL Query string
        if (DebugMode) ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.INFO, cSOQL));
        
        // Run the database query and place results into the TransferContactSearchResults class 
        try {
            searchResults.clear();
            List<Contact> results = Database.Query(cSOQL);
            
            // If zero or more than 250 records returned, display a message 
            if (results.size() == 250) ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'NOTE: Only the first 250 rows are displayed.'));
            if (results.size() == 0 && !transferJustCompleted) ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'NO RECORDS FOUND.'));
            
            // Build the searchResults[] list used by the Apex:DataTable tag on the page
            for (Contact c : results) {
                searchResults.add( new transferContactSearchResults(c) ) ;
            }
            
        } catch (Exception ex) {
                // ERROR! Display message on screen
            ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Query Error: ' + ex.getMessage()));
        }
        
        transferJustCompleted = false;     // Reset the flag used to track when a transfer was completed versus a new query
        return null;
        
    }
 
    // Return searchResults to the DATAGRID
    public list<transferContactSearchResults> getSearchResults() {
        if (fromUserID != '') {
            return this.searchResults;
        } else {
            return null ;
        }
    }
    
    // Used with the Style attribute on the OutputPanel tag show the search results if there are any
    public string getShowBlockIfResults() {
        if (this.searchResults.size() > 0) {
            return 'display: block;' ;
        } else {
            return 'display: none;' ;
        }
    }
    
    // ----------------------------------------------------------------------
    // Transfer Button:
    // - Query the selected contacts
    // - Change the OwnerID
    // - Call database.update()
    // - Check for errors
    // - Send an eMail if needed
    // - Rerun the query to display any remaining contacts
    // ----------------------------------------------------------------------
    public pageReference doTransfer() {
    
        if (toUserID == '' || toUserID == null) {
        	ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'ERROR: A "To User" must be specified'));
        	return null;
        }
        
        // Build a list of Contact ID's to transfer ownership for
        List<string> IDs = New List<string>();
        for (transferContactSearchResults c : searchResults) {
            if (c.selected) IDs.add(c.contact.ID) ;
        }
        if (DebugMode) ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Selected Count: ' + IDs.size()));
        
        // Query the contacts being transferred
        List<Contact> contacts = [SELECT ID, OwnerID, Name, Account.Name, Title, Owner.Alias FROM Contact WHERE ID IN :IDs];
        for (Contact c : contacts) {
            c.ownerID = toUserID ;
        }
        if (DebugMode) ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Query Size: ' + contacts.size()));

        // Process Errors and Count the Number of Records Transferred
        Integer transferCount = 0;
        List<database.saveresult> srs = database.update(contacts);
        for (database.saveresult sr : srs) {
            if (!sr.isSuccess()) {
                ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.FATAL, sr.getId() + '/' + sr.getErrors()[0].getMessage() ));
            } else {
            	transferCount++; 
            }
        }

        // If there were any errors, then re-build the list of contacts transferred to use for sending the eMail
        if (transferCount <> contacts.size() && transferCount > 0) {        
	        // Requery the contacts to figure out which were transferred and which were not.
	        List<Contact> contacts2 = [SELECT ID, OwnerID, Name, Account.Name, Title, Owner.Alias FROM Contact WHERE ID IN :IDs];
	        contacts = new List<Contact>();
	        for (Contact c : contacts2) {
	            if (c.OwnerID == toUserID) contacts.add(c);
	        }
        }

        // Display the Transfer Count
        ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.INFO, transferCount + ' Records Successfully Transfered' ));
        
        // If the 'Send eMail to New Owner' option is checked:
        if (DebugMode) ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'sendeMailToOwner=' + sendeMailToOwner));
        if (sendeMailToOwner && transferCount > 0) 	sendEMail(contacts); 
        
        // Set the flag that this just finished
        transferJustCompleted = true;       

        // Re-run the [Search] button functionality.
        doSearch();

        return null;
    }
    
    // ----------------------------------------------------------------------
    // If the 'Send eMail to New Owner' option is checked
    // Send a simple email with Text/Html body listing the contacts just transferred
    // Called by doTransfer() passing in the contacts[] list.
    // ----------------------------------------------------------------------
    private boolean sendEMail(List<Contact> TransferedContacts) {
    	string htmlBody = '<HTML><BODY><h3>';
    	string textBody = '';
    	
    	htmlbody += 'The following Contacts were just transferred to you by ' + UserInfo.getName() + '</h3>';
    	textBody += 'The following Contacts were just transferred to you ' + UserInfo.getName() + ':\r\r';

        // Build table/list of Contacts Transferred    	
    	htmlBody += '<Table width="100%"><TR><TD width="25%"><B>Contact Name</B></TD><TD width="25%"><B>Account Name</B></TD>' + 
    	   '<TD width="25%"><B>Title</B></TD><TD><B>Old Owner</B></TD></TR>';
        textBody += 'CONTACT NAME\t\t\tACCOUNT NAME\t\t\tTITLE\t\t\tOLD OWNER\r';
        
        // Use this to get the base URL of the SalesForce instance
        string BaseURL = ApexPages.currentPage().getHeaders().get('Host');
        
        // Build the table/list of contacts
        // Make the Name field a link to the contact
        for (Contact c : TransferedContacts) {
            pageReference cView = new ApexPages.StandardController(c).view();
            htmlBody += '<TR><TD><a href="' + BaseURL + cView.getUrl() + '">' + c.Name + '</a></TD><TD>' 
                + null2String(c.Account.Name) + '</TD><TD>' + null2String(c.Title) + '</TD><TD>' + c.Owner.Alias + '</TD></TR>';
            textBody += c.Name + '\t\t\t' + null2String(c.Account.Name) + '\t\t\t' + null2String(c.Title) + '\t\t\t' + c.Owner.Alias + '\r';
        }
        htmlBody += '</Table>';
        
        // Get the target user eMail address
        User user = [SELECT ID, eMail FROM User Where ID = :toUserID Limit 1];
        
        // Create the eMail object
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        // Set the TO address
        String[] toAddresses = new String[] {user.Email};
        mail.setToAddresses(toAddresses);
        
        // Specify the name used as the display name.
        mail.setSenderDisplayName(UserInfo.getName());
        
		// Specify the subject line for your email address.
		mail.setSubject(TransferedContacts.size() + ' Contacts Transferred To You');
		
		// Set options
		mail.setBccSender(false);
		mail.setUseSignature(false);
		
		// Specify the text content of the email.
		mail.setPlainTextBody(textBody);
		mail.setHtmlBody(htmlBody);
		
		// Send the email
		Messaging.SendEmailResult [] sr = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
		 
		if (!sr[0].isSuccess()) { 
			// Error sending the message; display the error on the page
			Messaging.SendEmailError r = sr[0].getErrors()[0];
			ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error Sending Message: ' + sr[0].getErrors()[0].getMessage() ));
			return false;
		} else { return true; }
        
    }
    
    // Simple function to convert NULL to ''
    private string null2String(string s) { if (s == null) return ''; else return s; }

	/* -------------------------------------------------------------------------------------
	* TransferContactSearchResults: Mass Transfer Search Results Wrapper Class
	* - Used by the TransferContacts Class and Page 
	* - Main purpose is to return a LIST of Contacts along with a custom checkbox that can 
	*   be used to let the user select which rows to transfer and which to ignore.
	*  ------------------------------------------------------------------------------------- */
	Public Class transferContactSearchResults{
	
	    public boolean selected = true;
	    public Contact contact = null;
	    
	    public transferContactSearchResults() { }
	    public transferContactSearchResults(Contact c) { contact = c; }
	    
	    public Contact getcontact()         { return this.contact ; }
	    public void setcontact(Contact c)   { this.contact = c; } 
	
	    public boolean getselected()        { return this.selected; }
	    public void setselected(boolean s)  { this.selected = s; } 
	    
	    // Returns these DateTime fields as Date types formatted based on the current users Locale setting in SalesForce 
	    public string getCreatedDate()      { return date.newInstance(this.contact.CreatedDate.year(), this.contact.CreatedDate.month(), this.contact.CreatedDate.day()).format() ; }
	    public string getLastModifiedDate() { return date.newInstance(this.contact.LastModifiedDate.year(), this.contact.LastModifiedDate.month(), this.contact.LastModifiedDate.day()).format() ; }
	}
}