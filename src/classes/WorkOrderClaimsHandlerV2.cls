public without sharing class WorkOrderClaimsHandlerV2 {
    public static Boolean isRecursion = false;
    
    public static void afterUpdate(Map<Id,WorkOrder> newMap,Map<Id,WorkOrder> oldMap){
        if(!isRecursion){
            createExpense(newMap,oldMap);
        }
        isRecursion=true;
    }
    
    public static void createExpense(Map<Id,WorkOrder> newMap,Map<Id,WorkOrder> oldMap){
        Set<Id> workOrderIdSet = new Set<Id>();
        Map<Id,ExpenseReport> woExpenseReportMap = new Map<Id,ExpenseReport>();
        List<Expense> expenseList = new List<Expense>();
        List<ProductConsumed> productConsumedList = new List<ProductConsumed>();
        List<ExpenseReportEntry> expenseReportEntryList = new List<ExpenseReportEntry>();
        Map<Id,PricebookEntry> peMap = new Map<Id,PricebookEntry>();
        
        List<DE_Claims_Asset_Setup__mdt> claimsMTD = [SELECT Id,IsClaims__c,IsLabour__c,IsHourly__c ,Service_Template_Id__c FROM DE_Claims_Asset_Setup__mdt WHERE DeveloperName='Master'];
        
        Product2 p = [SELECT Id FROM Product2 WHERE ProductCode = 'L-1000' LIMIT 1];
        for(PricebookEntry pe : [SELECT Id,Pricebook2Id,UnitPrice FROM PricebookEntry WHERE Product2Id=:p.Id]){
            peMap.put(pe.Pricebook2Id,pe);
        }
        system.debug('pe'+peMap);
		
        //Filter Completed Work Orders
        for(Id woId:newMap.keyset()){
            if(newMap.get(woId).Status == 'Completed' && oldMap.get(woId).Status != 'Completed'){
                workOrderIdSet.add(woId);
            }
        }
        
        //Fetch Work Order, Related Asset, Asset Warranty and Product Consumed
        Map<Id,WorkOrder> workOrderMap = new Map<Id,WorkOrder>([SELECT Id,AssetId,AssetWarrantyId,AssetWarranty.AssetWarrantyNumber,AssetWarranty.ExpensesCovered,AssetWarranty.ExpensesCoveredEndDate,AssetWarranty.LaborCovered,AssetWarranty.LaborCoveredEndDate,AssetWarranty.PartsCovered,AssetWarranty.PartsCoveredEndDate,WorkOrderNumber,Pricebook2Id,Work_Start__c,Work_End__c,(SELECT Product2Id,Product2.Name,ProductItemId,UnitPrice,QuantityConsumed,Total_Price__c,DE_Total_Effective_Amount__c,DE_Asset_Number__c FROM ProductsConsumed) FROM WorkOrder WHERE Id IN:workOrderIdSet]);
        for(WorkOrder wo:workOrderMap.values()){
            AssetWarranty aw = wo.AssetWarranty;
            Boolean createExpenseReport = false;
            for(ProductConsumed pc : wo.ProductsConsumed){
                if((aw.PartsCoveredEndDate>Date.today() || aw.PartsCoveredEndDate==null) && claimsMTD[0].IsClaims__c){
                    Expense ex = new Expense();
                    ex.DE_ProductConsumed__c = pc.Id;
                    ex.WorkOrderId = wo.Id;
                    ex.Description = 'Expense Auto-Generated for Asset being under warranty';
                    ex.ExpenseType = 'Billable';
                    ex.Title = pc.QuantityConsumed + ' units of ' + pc.Product2.Name + ' consumed for ' + wo.WorkOrderNumber;
                    ex.Amount = pc.Total_Price__c * (aw.PartsCovered/100);
                    ex.TransactionDate = date.today();
                    expenseList.add(ex);
                    
                    pc.DE_Total_Effective_Amount__c = pc.Total_Price__c - ex.Amount;
                    productConsumedList.add(pc);
                    
                    createExpenseReport=true;
                } else {
                    pc.DE_Total_Effective_Amount__c = pc.Total_Price__c;
                    productConsumedList.add(pc);
                }
            }
            //Create Enpense Report if required
            if(createExpenseReport){
                ExpenseReport er = new ExpenseReport();
                er.DE_Work_Order__c = wo.Id;
                er.Title = 'Expense Report for Work Order-'+wo.WorkOrderNumber;
                er.Description = 'Expense Auto-Generated for Asset being under warranty';
                woExpenseReportMap.put(wo.Id,er);
            }
            //Create Labour Charges
            if(claimsMTD[0].IsLabour__c && (aw.LaborCoveredEndDate>Date.today() || aw.LaborCoveredEndDate==null)){
                ProductConsumed labourPC = new ProductConsumed();
                labourPC.WorkOrderId = wo.Id;
                labourPC.QuantityConsumed = claimsMTD[0].IsHourly__c?calculateUnit(wo.Work_Start__c,wo.Work_End__c):1;
                labourPC.UnitPrice = wo.Pricebook2Id!=null?peMap.get(wo.Pricebook2Id).UnitPrice:peMap.values()[0].UnitPrice;
                labourPC.DE_Total_Effective_Amount__c =labourPC.UnitPrice * labourPC.QuantityConsumed * (1-(aw.LaborCovered/100));
                labourPC.PricebookEntryId = wo.Pricebook2Id!=null?peMap.get(wo.Pricebook2Id).Id:peMap.values()[0].Id;
                system.debug('labourPC'+labourPC);
                productConsumedList.add(labourPC);
            }
        }
        
        upsert productConsumedList;
        insert woExpenseReportMap.values();
        insert expenseList;
        
        for(Expense ex:expenseList){
            ExpenseReportEntry ere = new ExpenseReportEntry();
            ere.ExpenseReportId = woExpenseReportMap.get(ex.WorkOrderId).Id;
            ere.ExpenseId = ex.Id;
            expenseReportEntryList.add(ere);
        }
        
        insert expenseReportEntryList;
    }
    
    public static Double calculateUnit(Datetime starttime,Datetime endtime){
        if(starttime!=null && endtime!=null){
            Long dt1Long = starttime.getTime();
            Long dt2Long = endtime.getTime();
            return Math.ceil(Math.abs((dt2Long - dt1Long)/(1000*60*60)));
        } else {
            return 1;
        }
    }
}