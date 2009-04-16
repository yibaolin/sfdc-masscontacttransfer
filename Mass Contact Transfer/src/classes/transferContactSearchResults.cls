/* -------------------------------------------------------------------------------------
* TransferContactSearchResults class
* M.Smith 28 March 2009
* http://www.force2b.net
*
* Mass Transfer Search Results Wrapper Class
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