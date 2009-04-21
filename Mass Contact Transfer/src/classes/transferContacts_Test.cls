@isTest
/* -------------------------------------------------------------------------------------
* TransferContacts_Test Class: Test the Classes used by the Mass Contact Transfer page
* M.Smith 8 April 2009
* http://www.force2b.net
*  ------------------------------------------------------------------------------------- */
private class transferContacts_Test {

    static testMethod void myUnitTest() {
        
        // Add 10 new contacts that we can search for and transfer
        string UniqueKey = 'AbcDefGhi12345';
        list<Contact> c = New List<Contact>();
        for (Integer i = 0; i < 10; i++) {
            Contact cnew = new Contact(LastName = 'Test Contact ' + i, FirstName = UniqueKey);
            insert cnew;
            c.add(cnew);
        }
        
        // Get the current user and some other user
        // NOTE: There must be at least one other active user in the system!
        user anotheruserid = [Select ID, LocaleSidKey, Alias From User WHERE IsActive = True AND Id <> :UserInfo.getUserID() LIMIT 1];
        user currentuser = [Select ID, LocaleSidKey, Alias From User WHERE IsActive = True AND Id = :UserInfo.getUserID() LIMIT 1];
        
        // Create a PageReference to the VF page being tested       
        PageReference pageRef = Page.transferContacts;
        test.setCurrentPage(pageRef);

        // Create an instance of the searchCriteria to test all
        // get/set methods and the BuildWhereClause() method
        searchCriteria  critClass = new searchCriteria();
        
        // Call the various Get/Set methods to test these
        // nothing to check for, just want to run the code 
        system.debug(critClass.getInputDateFormat());
        critClass.getSearchField();
        critClass.getSearchOperator();
        critClass.getSearchValue();
        critClass.getLogical();
        critClass.getSearchValue();
        critClass.seterrMsg('');
        critClass.setLogical('AND');
        
        // Test all possible combinations of Fields and Operators
        List<SelectOption> operators = critClass.getOperatorSelectList();
        Set <String> fields = new Set<String>{'STRING/Field1', 'DATE/Field2', 'DATETIME/Field3', 
            'PICKLIST/Field4', 'MULTIPICKLIST/Field5', 'EMAIL/Field6', 'PHONE/Field7', 
            'DOUBLE/Field8', 'CURRENCY/Field9', 'BOOLEAN/Field10', 'TEXTAREA/Field11'}; 
        Set <String> values = new Set<String>{'abcde', 'abcd, efgh, ijkl', 'true', '100', 
            '12/31/2007', '12-21-2008', 'TODAY', 'NEXT 3 WEEKS'};
        
        // Three nested loops - Fields, Operators, Values
        // nothing to check for, just want to run the code
        // Can look through the Test results for Debug entries if neded 
        for (string f : fields) {
            critClass.setSearchField(f);
            for (SelectOption o : operators) {
                critClass.setSearchOperator (o.getValue());
                for (string v : values) {
                    critClass.setSearchValue (v);
                    System.debug(f + ' ' + o.getValue() + ' ' + v + ' :' + critClass.buildWhereClause(true) + ' - ' + critClass.geterrMsg());
                }
            }           
        }

        // Create an instance of the page controller to test its methods
        transferContacts cntrlr = new transferContacts();

        // Call the various Get/Set methods to test these
        // nothing to check for, just want to run the code 
        cntrlr.setSetDebugModeFALSE(true);
        cntrlr.setSetDebugModeTRUE(true);
        cntrlr.getSetDebugModeTRUE();
        cntrlr.getSetDebugModeFALSE();
        cntrlr.getInputDateFormat();
        cntrlr.settoUserID(anotheruserid.ID);
        cntrlr.setfromUserID(UserInfo.getUserID());
        cntrlr.getfromUserID();
        cntrlr.gettoUserID();
        cntrlr.getFromUsers();
        cntrlr.getToUsers();
        cntrlr.getShowBlockIfResults();
        
        // Create a search criteria that must succeed
        // Get the error message values for each to confirm no errors on any criteria line
        cntrlr.criteriaLine[0].setSearchField('STRING/FirstName');
        cntrlr.criteriaLine[0].setSearchOperator('eq');
        cntrlr.criteriaLine[0].setSearchValue(UniqueKey);
        System.Debug(cntrlr.criteriaLine[0].buildWhereClause(true));
        System.assertEquals('', cntrlr.criteriaLine[0].geterrMsg());

        cntrlr.criteriaLine[1].setSearchField('DATETIME/CreatedDate');
        cntrlr.criteriaLine[1].setSearchOperator ('eq');
        cntrlr.criteriaLine[1].setSearchValue ('TODAY');
        System.Debug(cntrlr.criteriaLine[1].buildWhereClause(true));            
        System.assertEquals('', cntrlr.criteriaLine[1].geterrMsg());

        cntrlr.criteriaLine[2].setSearchField('STRING/LastName');
        cntrlr.criteriaLine[2].setSearchOperator ('starts');
        cntrlr.criteriaLine[2].setSearchValue ('Test Contact');
        System.Debug(cntrlr.criteriaLine[2].buildWhereClause(true));            
        System.assertEquals('', cntrlr.criteriaLine[2].geterrMsg());

        cntrlr.criteriaLine[3].setSearchField('STRING/Owner.Alias');
        cntrlr.criteriaLine[3].setSearchOperator ('eq');
        cntrlr.criteriaLine[3].setSearchValue (currentuser.Alias);
        System.Debug(cntrlr.criteriaLine[3].buildWhereClause(true));      
        System.assertEquals('', cntrlr.criteriaLine[3].geterrMsg());
        
        // Run the Search against this criteria
        PageReference cntrlrResult = cntrlr.doSearch();
        
        // Confirm that the results match the number of contacts added above
        System.assertEquals(null, cntrlrResult);
        System.assertEquals(c.size(), cntrlr.searchResults.size());
        
        // Enum the searchResult to test some of the code in this class
        // Nothing to test for here
        for (transferContacts.TransferContactSearchResults sr : cntrlr.searchResults) {
            sr.getcontact();
            sr.getselected();
            sr.setselected(true);
            sr.getCreatedDate();
            sr.getLastModifiedDate();  
        }
        
        // Test the send mail functionality.
        cntrlr.setsendeMailToOwner(true);
        cntrlr.getsendeMailToOwner();
        
        // Click the transfer button
        cntrlrResult = cntrlr.doTransfer();

        // Confirm that all 10 contacts were transferred with no errors 
        System.assertEquals(cntrlrResult, null);
        System.assertEquals(cntrlr.searchResults.size(), 0);
        
    }
}