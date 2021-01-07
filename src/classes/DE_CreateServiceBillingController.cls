public class DE_CreateServiceBillingController {
	   
    public class Response{
        @auraEnabled
        public String actionName {get;set;} 
        @auraEnabled
        public String errors {get;set;} 
        @auraEnabled
        public Boolean isSuccess {get;set;} 
        @auraEnabled
        public OutputValues OutputValues {get;set;}
    }
    
    public class OutputValues {
        @auraEnabled
		public String serviceReportId {get;set;}
        @auraEnabled
		public String contentVersionId {get;set;} 
        @auraEnabled
		public String entityId {get;set;} 
    }
    
    public class AuraResponse{
        @auraEnabled
        public String errorJSON {get;set;} 
        @auraEnabled
        public Boolean isSuccess {get;set;} 
        @auraEnabled
        public string fileId {get;set;}
        @auraEnabled
        public string serviceBillingId {get;set;}
        @auraEnabled
        public string fileName {get;set;}
    }
    
    
    @auraEnabled
    public static AuraResponse createServiceBillingReport(Id recordId,String sessionId){
        AuraResponse ar = new AuraResponse();
        Id templateIdVal;
        String salesforceHost = System.Url.getSalesforceBaseURL().toExternalForm();
        String url = salesforceHost + '/services/data/v41.0/actions/standard/createServiceReport';
        HttpRequest request = new HttpRequest();
        request.setEndpoint(url);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Authorization', 'OAuth ' + sessionId);
        List<DE_Claims_Asset_Setup__mdt> claimsMTD = [SELECT Id,Service_Template_Id__c FROM DE_Claims_Asset_Setup__mdt WHERE DeveloperName='Master'];
        if(claimsMTD.size()>0 && String.isNotBlank(claimsMTD[0].Service_Template_Id__c)){
            templateIdVal = claimsMTD[0].Service_Template_Id__c;
        } else {
            templateIdVal = [SELECT Id FROM ServiceReportLayout LIMIT 1].Id;
        }
    	Map<String,Object> requestMap = new Map<String,Object>();
        Map<String,Object> requestBody = new Map<String,Object>();
        List<Map<String,Object>> inputs = new List<Map<String,Object>>();
    	requestBody.put('entityId',recordId);
    	requestBody.put('templateId',templateIdVal);
        inputs.add(requestBody);
        requestMap.put('inputs',inputs);
        String jsonString = JSON.serialize(requestMap);
        system.debug(jsonString);
        request.setBody(jsonString);
        Http http = new Http();
        HttpResponse response = http.send(request);
        if (response.getStatusCode() != 200) {
            System.debug('The status code returned was not expected: ' + response.getStatusCode() + ' ' + response.getStatus() + ' ' + response.getBody());
            ar.isSuccess=false;
            ar.errorJSON = response.getBody();
        } else {
            System.debug(response.getBody());
            List<Response> responseList = (List<Response>)JSON.deserialize(response.getBody(),List<Response>.class);
            ar = createServiceBilling(responseList[0].OutputValues);
        }
        return ar;
	}
    
    public static AuraResponse createServiceBilling(OutputValues ov){
        AuraResponse ar = new AuraResponse();
        ar.isSuccess = true;
        ar.fileId = [SELECT Id,ContentDocumentId FROM ContentVersion WHERE Id=:ov.contentVersionId].ContentDocumentId;
        ServiceReport sr = new ServiceReport(Id=ov.serviceReportId);
        delete sr;
        List<DE_Service_Billing__c> sbList = [SELECT Id,Version__c FROM DE_Service_Billing__c WHERE WorkOrder__c=:ov.entityId ORDER BY CreatedDate DESC];
        String name = 'Service_Bill_V';
        Decimal version = 1;
        if(sbList.size()>0){
            version = sbList[0].Version__c+1;
            name = name+version;
        } else {
            name = name+version;
        }
        DE_Service_Billing__c sb = new DE_Service_Billing__c(WorkOrder__c=ov.entityId,Name=name,Version__c=version,FileId__c=ar.fileId);
        insert sb;
        ar.fileName=name;
        ar.serviceBillingId = sb.Id;
        ContentDocument cd = new ContentDocument(Id=ar.fileId,Title=name);
        update cd;
        return ar;
    }
    
    @auraEnabled
    public static void deleteBillings(String sbId,String cdId){
        delete new DE_Service_Billing__c(Id=sbId);
        delete new ContentDocument(Id=cdId);
    }
}